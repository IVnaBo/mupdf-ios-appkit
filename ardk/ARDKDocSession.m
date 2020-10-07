//
//  ARDKDocSession.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 11/04/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "ARDKGeometry.h"
#import "ARDKDocSession.h"
#import "ARDKDocumentViewControllerPrivate.h"
#import "ARDKDigitalSigningDelegate.h"
#import "ARDKLib.h"

#define THUMBSIZE (300)
#define THUMBNAIL_MAX_ASPECT (8)

NSString * const ARDK_InkAnnotationThicknessKey = @"ARDK_InkAnnotationThicknessKey";
NSString * const ARDK_InkAnnotationColorKey = @"ARDK_InkAnnotationColorKey";
NSString * const ARDK_RibbonScrollWarningHoldOff = @"ARDK_RibbonScrollWarningHoldOff";

@interface ARDKDocSession () <ARDKDocumentEventTarget>
@property id<ARDKRender> thumbRender;
@property ARDKDocumentViewController *docVc;
@end

@implementation ARDKDocSession
{
    NSInteger _numPages;
    BOOL _complete;
    ARDKDocErrorType _error;
    void (^_progressBlock)(NSInteger numPages, BOOL complete);
    void (^_errorBlock)(ARDKDocErrorType error);
    ARDKTheme *_uiTheme;
}

- (instancetype)initWithFileState:(id<ARDKFileState>)fileState ardkLib:(id<ARDKLib>)soLib docSettings:(ARDKDocumentSettings *)settings
{
    self = [super init];
    if (self)
    {
        _fileState = fileState;
        _ardkLib = soLib;
        _doc = [soLib docForPath:_fileState.absoluteInternalPath ofType:_fileState.docType];
        _docSettings = settings;
        [_doc addTarget:self];

        __weak typeof (self) weakSelf = self;
        _doc.errorBlock = ^(ARDKDocErrorType error)
        {
            ARDKDocSession *sess = weakSelf;
            if (sess)
            {
                if (sess.errorBlock)
                {
                    if ( sess.docVc && error == ARDKDocErrorType_PasswordRequest )
                        [sess.docVc.errorHandler handlerError:error];
                    else
                        sess.errorBlock(error);
                    
                    // Each error should be reported only once, so
                    // don't record it if we've managed to pass it on
                    sess->_error = ARDKDocErrorType_NoError;
                }
                else
                {
                    // No client listening, so keep the last error
                    // ready to be sent to a future client. Possibly we
                    // should keep and array
                    sess->_error = error;
                }
            }
        };

        [_doc loadDocument];
    }
    return self;
}

- (void)updatePageCount:(NSInteger)numPages andLoadingComplete:(BOOL)complete
{
    if (numPages > 0 && _numPages == 0)
        [_fileState sessionDidLoadFirstPage:self];
    // Record the number of pages and whether complete so that we can
    // resend that information if a new client provides a progressBlock
    _numPages = numPages;
    _complete = complete;
    if (_progressBlock)
        _progressBlock(numPages, complete);
}

- (void)pageSizeHasChanged
{
}

- (void)selectionHasChanged
{
}

- (void)layoutHasCompleted
{
}

+ (ARDKDocSession *)sessionForFileState:(id<ARDKFileState>)fileState ardkLib:(id<ARDKLib>)ardkLib docSettings:(ARDKDocumentSettings *)docSettings
{
    return [[ARDKDocSession alloc] initWithFileState:fileState ardkLib:ardkLib docSettings:docSettings];
}

- (void)dealloc
{
    [self.doc abortLoad];
    [self.fileState sessionDidClose];
}

- (BOOL)documentHasBeenModified
{
    return self.doc.hasBeenModified || self.fileState.requiresCopyBack;
}

- (void)saveDocumentAndOnCompletion:(void (^)(ARDKSaveResult, ARError))block
{
    if (self.doc.hasBeenModified)
    {
        __weak typeof (self) weakSelf = self;
        // Save back over the internal copy
        [self saveTo:self.fileState.absoluteInternalPath completion:^(ARDKSaveResult res, ARError err) {
            switch (res)
            {
                case ARDKSave_Succeeded:
                    // And then copy the internal version over the original
                    if (weakSelf.fileState.requiresCopyBack)
                    {
                        [weakSelf.fileState sessionRequestedCopyBackOnCompletion:^(BOOL succeeded) {
                            if (succeeded)
                                block(ARDKSave_Succeeded, 0);
                            else
                                block(ARDKSave_Error, 0);
                        }];
                    }
                    else
                    {
                        block(ARDKSave_Succeeded, 0);
                    }
                    break;

                case ARDKSave_Cancelled:
                case ARDKSave_Error:
                    block(res, err);
                    break;
            }
        }];
    }
    else
    {
        // No need to save the doc over the internal copy file, but
        // we still need to call sessionRequestedCopyBackOnCompletion in case the internal copy
        // has changes
        if (self.fileState.requiresCopyBack)
        {
            [self.fileState sessionRequestedCopyBackOnCompletion:^(BOOL succeeded) {
                if (succeeded)
                    block(ARDKSave_Succeeded, 0);
                else
                    block(ARDKSave_Error, 0);
            }];
        }
        else
        {
            // Call block asynchronously for consistency
            dispatch_async(dispatch_get_main_queue(), ^{
                block(ARDKSave_Succeeded, 0);
            });
        }
    }
}

- (void)prepareToShare:(void (^)(NSString *, NSString *, ARDKSaveResult, ARError))block
{
    __weak typeof (self) weakSelf = self;
    if (self.doc.hasBeenModified)
    {
        // Save back over the internal copy
        [self saveTo:self.fileState.absoluteInternalPath completion:^(ARDKSaveResult res, ARError err) {
            block(weakSelf.fileState.absoluteInternalPath, [weakSelf.fileState.displayPath lastPathComponent], res, err);
        }];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            block(weakSelf.fileState.absoluteInternalPath, [weakSelf.fileState.displayPath lastPathComponent], ARDKSave_Succeeded, 0);
        });
    }
}

- (NSString *)writeDataToTemporaryFile:(NSData *)data
{
    id<ARDKSecureFS>  secureFs         = self.ardkLib.settings.secureFs;
    NSFileManager    *fileMan          = [NSFileManager defaultManager];
    NSString         *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSString         *tmpdirBase       = self.ardkLib.settings.temporaryPath;
    NSString         *tmpdir           = tmpdirBase;
    int               i                = 0;
    BOOL              result;

    if (!tmpdir)
    {
        @throw [NSException exceptionWithName:@"temporary directory must be set to use image import"
                                       reason:@"Please set ARDKSettings.temporaryPath"
                                     userInfo:nil];
    }

    tmpdir = [tmpdirBase stringByAppendingPathComponent:bundleIdentifier];
    if ( secureFs && [secureFs ARDKSecureFS_isSecure:tmpdir] )
    {
        if ( ![secureFs ARDKSecureFS_fileExists:tmpdir] )
            tmpdir = tmpdirBase;
    }
    else
    {
        if ( ![fileMan fileExistsAtPath:tmpdir isDirectory:nil] )
            tmpdir = tmpdirBase;
    }

    while (YES)
    {
        NSString *path = [tmpdir stringByAppendingPathComponent:[NSString stringWithFormat:@"tmpimage%d.jpg", i]];

        if (secureFs && [secureFs ARDKSecureFS_isSecure:path])
        {
            if (![secureFs ARDKSecureFS_fileExists:path])
            {
                BOOL success;
                id<ARDKSecureFS_Handle> handle = nil;

                success = [secureFs ARDKSecureFS_createFileAtPath:path];
                if (success)
                {
                    handle = [secureFs ARDKSecureFS_fileHandleForWritingAtPath:path];

                    if (handle)
                    {
                        [handle ARDKSecureFS_writeData:data];
                        [handle ARDKSecureFS_closeFile];
                    }
                }

                return handle ? path : nil;
            }
        }
        else
        {
            /* No secureFS, or temporary folder is not in secureFS */
            if (![fileMan fileExistsAtPath:path])
            {
                result = [data writeToFile:path atomically:YES];

                return result ? path : nil;
            }
        }
        i++;
    }
}

- (void (^)(NSInteger numPages, BOOL complete))progressBlock
{
    return _progressBlock;
}

- (void)setProgressBlock:(void (^)(NSInteger, BOOL))progressBlock
{
    _progressBlock = progressBlock;
    // The newly registered progress block may have missed some
    // events so make sure it is up to date
    if (_numPages > 0 || _complete)
    {
        __weak typeof (self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            ARDKDocSession *sess = weakSelf;
            if (sess && sess->_progressBlock)
                sess->_progressBlock(sess->_numPages, sess->_complete);
        });
    }
}

- (void (^)(ARDKDocErrorType error))errorBlock
{
    return _errorBlock;
}

- (void)setErrorBlock:(void (^)(ARDKDocErrorType))errorBlock withDocumentViewController:(ARDKDocumentViewController *)docVc
{
    self.docVc      = docVc;
    self.errorBlock = errorBlock;
}

- (void)setErrorBlock:(void (^)(ARDKDocErrorType))errorBlock
{
    _errorBlock = errorBlock;
    // The newly registered error block may have missed some
    // events so make sure it is up to date
    if (_error)
    {
        __weak typeof (self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            ARDKDocSession *sess = weakSelf;
            if (sess && sess->_errorBlock)
            {
                sess->_errorBlock(sess->_error);
                sess->_error = ARDKDocErrorType_NoError;
            }
        });
    }
}

- (void)createThumbnail:(void (^)(UIImage *))block
{
    __weak typeof (self) weakSelf = self;
    UIApplication *app = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier thumbTask = [app beginBackgroundTaskWithExpirationHandler:^{
        [app endBackgroundTask:thumbTask];
    }];

    id<ARDKPage> page = [self.doc getPage:0 update:nil];
    CGSize psize = page.size;
    // For very tall and thin or short and fat documents, limit the thumbnail
    // to part of more reasonable aspect ratio
    CGSize size = CGSizeMake(MIN(psize.width, psize.height*THUMBNAIL_MAX_ASPECT),
                             MIN(psize.height, psize.width*THUMBNAIL_MAX_ASPECT));
    CGFloat zoom = MIN(THUMBSIZE/size.width, THUMBSIZE/size.height);
    size = ARCGSizeScale(size, zoom);
    ARDKBitmap *bm = [self.doc bitmapAtSize:size];
    self.thumbRender = [page renderAtZoom:zoom withDocOrigin:CGPointZero intoBitmap:bm
                                 progress:^(ARError error) {
                                     block(bm.asImage);
                                     weakSelf.thumbRender = nil;
                                     [app endBackgroundTask:thumbTask];
                                 }];
    if (!self.thumbRender)
        [app endBackgroundTask:thumbTask];
}

- (void)saveTo:(NSString *)path completion:(void (^)(ARDKSaveResult, ARError))block
{
    if (_presaveBlock)
        _presaveBlock();

    UIApplication *app = [UIApplication sharedApplication];

    __block UIBackgroundTaskIdentifier saveTask = [app beginBackgroundTaskWithExpirationHandler:^{
        // In the expiration handler, we end the task to avoid the
        // app being killed, but there's nothing useful we can do
        // to mitigate the save operation having not completed. We
        // did our best!
        [app endBackgroundTask:saveTask];
    }];

    __weak typeof (self) weakSelf = self;
    [self.doc saveTo:path completion:^(ARDKSaveResult res, ARError err) {
        // Update the file state accordingly
        [weakSelf.fileState sessionDidSaveDoc:weakSelf];
        block(res, err);
        // Telling the system that you've finished and having it shut the
        // app down "is the last thing you want to do". Do so only after
        // calling the block!!
        [app endBackgroundTask:saveTask];
    }];
}

- (void)saveInternalAndOnCompletion:(void (^)(ARDKSaveResult, ARError))block
{
    if (self.doc.hasBeenModified)
    {
        // Save back over the internal copy
        [self saveTo:self.fileState.absoluteInternalPath completion:^(ARDKSaveResult res, ARError err) {
            block(res, err);
        }];
    }
    else
    {
        block(ARDKSave_Succeeded, 0);
    }
}

- (ARDKTheme *)uiTheme
{
    if (_uiTheme == nil)
    {
        _uiTheme = [[ARDKTheme alloc] init];
        [_uiTheme fromPlist:self.themeFile];
    }

    return _uiTheme;
}

@end
