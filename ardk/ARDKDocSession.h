//
//  ARDKDocSession.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 11/04/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//
//  This class represents an open document session that can be
//  passed around to be displayed and edited within several
//  views, without intermediate closing and reopening. It keeps
//  the SODKDoc object with the corresponding ARDKFileState and
//  handles the passing of progress info from the SODKDoc to
//  other classes.

#import <Foundation/Foundation.h>
#import "ARDKLib.h"
#import "ARDKTheme.h"
#import "ARDKFileState.h"
#import "ARDKDocumentSettings.h"
#import "ARDKDigitalSigningDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@class ARDKDocumentViewController;

extern NSString * const ARDK_InkAnnotationThicknessKey;
extern NSString * const ARDK_InkAnnotationColorKey;
extern NSString * const ARDK_RibbonScrollWarningHoldOff;

@interface ARDKDocSession : NSObject
@property(nonnull, readonly) id<ARDKDoc> doc;
@property(nonnull, readonly) id<ARDKFileState> fileState;
@property(nullable, strong) void (^progressBlock)(NSInteger numPages, BOOL complete);
@property(nullable, strong) void (^errorBlock)(ARDKDocErrorType error);
@property(nullable, strong) void (^presaveBlock)(void);

@property(nullable) id<ARDKDigitalSigningDelegate> signingDelegate;

/// Allow various functionality to be enabled/disabled for this document.
/// It should be set before loading a document.
@property(nonnull, readonly) ARDKDocumentSettings *docSettings;

/// Property denoting if there are unsaved changes, either because changes
/// in memory haven't been written back to disc, or the disc copy hasn't
/// been written back to the original.
@property(readonly) BOOL documentHasBeenModified;

/// Save the document
/// This handles writing in memory changes back to disc and writing the
/// disc copy back to the original
- (void)saveDocumentAndOnCompletion:(void (^)(ARDKSaveResult, ARError))block;

/// Prepare for sharing a document
/// If necessary, the document is saved back to the internal path and
/// then the block is invoked with that path, plus the document name
- (void)prepareToShare:(void (^)(NSString *, NSString *, ARDKSaveResult, ARError))block;

/// Write data to temporary file and return the path
///
/// The temporary file will be created within the secureFs area if secureFs
/// is available.
- (NSString * _Nullable)writeDataToTemporaryFile:(NSData *)data;

/// Create a document session for the given file state
///
/// @param fileState       The file state of document
/// @param ardkLib         SmartOffice Library
/// @param docSettings     Settings for the document
///
/// @return  The created document session
+ (ARDKDocSession *)sessionForFileState:(id<ARDKFileState>)fileState ardkLib:(id<ARDKLib>)ardkLib docSettings:(ARDKDocumentSettings *)docSettings;

/// Initialize the document session with the given file state
///
/// @param fileState       The file state of document
/// @param ardkLib         SmartOffice Library
/// @param docSettings     Settings for the document
///
/// @return  The initialized document session
- (instancetype)initWithFileState:(id<ARDKFileState>)fileState ardkLib:(id<ARDKLib>)ardkLib docSettings:(ARDKDocumentSettings *)docSettings;

/// Wrapper around ARDKDoc.saveTo:completion: that declares the operation as
/// a background task so that it is far less likely to be killed if the
/// app enters background before it is complete, particularly important in
/// the case of a save operation invoked because of the app entering background
- (void)saveTo:(NSString *)path completion:(nullable void (^)(ARDKSaveResult res, ARError))block;

// Apps can apply a UI theme to the document views
// See ARDKTheme for usage
@property(nullable, nonatomic, copy) NSString *themeFile;

/// The prevailing UITheme
@property(readonly) ARDKTheme *uiTheme;

// We store the bitmap used for rendering here so that it can be
// reused.
@property(nullable, nonatomic, retain) ARDKBitmap *bitmap;

/// Underlying soLib used for this document
@property(nonnull, readonly) id<ARDKLib> ardkLib;

/// Create a thumbnail image of the first page of the document
///
/// This will fail if called before the first page is available.
- (void)createThumbnail:(nonnull void (^)( UIImage * _Nullable thumbnail))block;

/// Rather than open a file directly, an internal copy is made
/// This method saves edits back to that internal copy. When the_
/// user explicitly saves, the destination of the save is overwritten
/// with the contents of the internal copy.
- (void)saveInternalAndOnCompletion:(nonnull void (^)(ARDKSaveResult, ARError))block;

/// Set the errorBlock with a document view controller
/// The document view controller should be owner of the error handler
- (void)setErrorBlock:(nonnull void (^)(ARDKDocErrorType))errorBlock withDocumentViewController:(ARDKDocumentViewController *)docVc;

@end

NS_ASSUME_NONNULL_END
