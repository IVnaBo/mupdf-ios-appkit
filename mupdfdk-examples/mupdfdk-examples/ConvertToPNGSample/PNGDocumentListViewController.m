//
//  PNGDocumentListViewController.m
//  smart-office-examples
//
//  Created by Joseph Heenan on 12/08/2016.
//  Copyright © 2016 Artifex. All rights reserved.
//

#import <mupdfdk/mupdfdk.h>
#import "SecureFS.h"

#import "PNGDocumentListViewController.h"

#define IMAGESIZE (1500)

#define ARCGSizeScale(size, scale) CGSizeMake((size).width * (scale), (size).height * (scale))

@interface PNGDocumentListViewController ()
@property NSMutableArray<MuPDFDKRender *> *pageRender;
@property (strong, nonatomic) MuPDFDKLib *mupdfdkLib;
@end

@implementation PNGDocumentListViewController
{
    MuPDFDKDoc *_doc;
}

- (NSURL *)nsDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)loadingComplete
{
    NSInteger pageCount = _doc.pageCount;

    _pageRender = [[NSMutableArray alloc] init];

    UIAlertController *controller = [UIAlertController alertControllerWithTitle:nil
                                                                        message:[NSString stringWithFormat:@"Document Loaded. Saving %zd pages to Documents directory", pageCount]
                                                                 preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *alertAction = [UIAlertAction actionWithTitle:@"Okay"
                                                          style:UIAlertActionStyleDefault
                                                        handler:nil];

    [controller addAction:alertAction];

    [self presentViewController:controller animated:YES completion:nil];

    for (NSInteger p = 0; p < pageCount; p++)
    {
        MuPDFDKPage *page = [_doc getPage:p update:nil];

        __weak typeof (self) weakSelf = self;

        CGFloat zoom = MIN(IMAGESIZE/page.size.width, IMAGESIZE/page.size.height);
        CGSize size = ARCGSizeScale(page.size, zoom);
        ARDKBitmap *bm = [_doc bitmapAtSize:size];
        self.pageRender[p] = [page renderAtZoom:zoom withDocOrigin:CGPointZero intoBitmap:bm
                                     progress:^(SOError error) {
                                         // This block will be called back when the render is ready, on the main thread
                                         if (error)
                                         {
                                             NSLog(@"MuPDFDKRender for page %zd failed: %x", p, error);

                                         }
                                         else
                                         {
                                             // WARNING: call to ARDKsanitizedImage is essential and UIImagePNGRepresentation will mysteriously fail without it
                                             UIImage *simage = [bm.asImage ARDKsanitizedImage];
                                             NSData *data = UIImagePNGRepresentation(simage);
                                             assert(data);
                                             NSString *fname = [NSString stringWithFormat:@"page-%04zd.png", p];
                                             NSURL *url = [[weakSelf nsDocumentsDirectory] URLByAppendingPathComponent:fname];
                                             [data writeToURL:url atomically:NO];
                                             NSLog(@"Wrote %@ to NSDocumentsDirectory", fname);
                                         }
                                     }];
        if (!self.pageRender[p])
        {
            NSLog(@"Creating MuPDFDKRender for page %zd failed", p);
        }
    }
}

- (void)loadingError:(ARDKDocErrorType)error
{
    NSLog(@"Failed to load document: %x", error);

}

- (void)documentSelected:(NSString *)docPath
{
    __weak typeof(self) weakSelf = self;
    /* In a normal application, MuPDFDKLib would be retained and reused multiple
     * times, only being released if a low memory notification is received
     * whilst no documents are loaded.
     * Note that only one MuPDFDKLib instance can exist at any one time.
     */
    if (!self.mupdfdkLib)
    {
        ARDKSettings *settings = [[ARDKSettings alloc] init];
        settings.secureFs = [[SecureFS alloc] init];
        self.mupdfdkLib = [[MuPDFDKLib alloc] initWithSettings:settings];
    }

    _doc = [_mupdfdkLib docForPath:[[self nsDocumentsDirectory].path stringByAppendingPathComponent:docPath] ofType:[MuPDFDKDoc docTypeFromFileExtension:docPath]];
    _doc.successBlock = ^() {
        [weakSelf loadingComplete];
    };
    _doc.errorBlock = ^(ARDKDocErrorType error) {
        [weakSelf loadingError:error];
    };
    [_doc loadDocument];
}

@end
