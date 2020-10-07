//
//  ARDKLib.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 22/06/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKSecureFS.h"
#import "ARDKSettings.h"
#import "platform-headers.h"

/// Error type returned from some ARDK functions
///
/// 0 means no error
///
/// non-zero values mean an error occurred. The exact value is an indication
/// of what went wrong and should be included in bug reports or support
/// queries. Library users should not test this value except for 0,
/// non-zero and any explicitly documented values.
typedef int ARError;

/// Bitmap color representation type
typedef enum
{
    ARDKBitmapType_A8,
    ARDKBitmapType_RGB555,
    ARDKBitmapType_RGB565,
    ARDKBitmapType_RGBA8888
} ARDKBitmapType;

/// The document type of an open document
typedef enum
{
    ARDKDocType_XLS,
    ARDKDocType_XLSX,
    ARDKDocType_PPT,
    ARDKDocType_PPTX,
    ARDKDocType_DOC,
    ARDKDocType_DOCX,
    ARDKDocType_PDF,
    ARDKDocType_TXT,
    ARDKDocType_IMG,
    ARDKDocType_HWP,
    ARDKDocType_WMF,
    ARDKDocType_EMF,
    ARDKDocType_CSV,
    ARDKDocType_CBZ,
    ARDKDocType_EPUB,
    ARDKDocType_FB2,
    ARDKDocType_SVG,
    ARDKDocType_XPS,
    ARDKDocType_Other
} ARDKDocType;

/// Errors returned when loading a document
///
/// Other values may also be returned.
typedef enum ARDKDocErrorType
{
    ARDKDocErrorType_NoError = 0,
    ARDKDocErrorType_UnsupportedDocumentType = 1,
    ARDKDocErrorType_EmptyDocument = 2,
    ARDKDocErrorType_UnableToLoadDocument = 4,
    ARDKDocErrorType_UnsupportedEncryption = 5,
    ARDKDocErrorType_Aborted = 6,
    ARDKDocErrorType_OutOfMemory = 7,

    /// A password is required to open this document.
    ///
    /// The app should provide it using ARDKDoc:providePassword:
    ARDKDocErrorType_PasswordRequest = 0x1000,
    ARDKDocErrorType_XFAForm = 0x1001
} ARDKDocErrorType;

typedef enum
{
    ARDKSoftProfile_DisplayP3,
    ARDKSoftProfile_sRGB,
    ARDKSoftProfile_AdobeRGB1998,
    ARDKSoftProfile_ROMMRGB
} ARDKSoftProfile;

/// Structure holding the detail of the layout of a bitmap.
typedef struct ARDKBitmapInfo
{
    void          *memptr;
    int            width;
    int            height;
    int            lineSkip;
    ARDKBitmapType type;
} ARDKBitmapInfo;

/// Bitmap abstraction that the Artifex Document library renders to
@interface ARDKBitmap : NSObject
@property(readonly) void *buffer;
@property(readonly) NSInteger width;
@property(readonly) NSInteger height;
@property(readonly) ARDKBitmapType bmType;
@property(readonly) ARDKBitmap *parent;
@property ARDKSoftProfile softProfile;
@property BOOL darkMode;

/// Allocate a bitmap of a specific size
+ (ARDKBitmap *)bitmapAtSize:(CGSize)size ofType:(ARDKBitmapType)bmType;

/// Give access to a subarea of an already allocated bitmap
+ (ARDKBitmap *)bitmapFromSubarea:(CGRect)area ofBitmap:(ARDKBitmap *)bm;

/// Create a bitmap based on the values in an ARDKBitmapInfo structure
/// Ownership will be taken of the buffer pointed to by memptr and
/// memptr will be set to NULL
+ (ARDKBitmap *)bitmapFromARDKBitmapInfo:(ARDKBitmapInfo *)bm;

/// Adjust the use of the bitmap's buffer to a different size
- (void) adjustToSize:(CGSize)size;

/// Adjust the use of the bitmap's buffer to the largest size
/// for a given width
- (void) adjustToWidth:(NSInteger)width;

///Copy the contents of another bitmap into this one
///Bitmaps must be the same size
- (void)copyFrom:(ARDKBitmap *)otherBm;

/// Return details of the bitmap as a ARDKBitmapInfo structure.
- (ARDKBitmapInfo)asBitmap;

/// Perform dark-mode conversion if the bitmap is in dark mode
- (void)doDarkModeConversion;

@end

@interface ARDKBitmap (ARDKBitmap_ARDKAdditions)

/// Produce a UIImage from the bitmap. The UIImage holds a reference.
///
/// WARNING: The returned UIImage is not in a format supported by
/// UIImagePNGRepresentation; see [UIImage ARDKsanitizedImage].
- (UIImage *)asImage;

/// Produce a UIImage from the bitmap plus another bitmap which holds alpha
/// channel data. The UIImage holds a reference.
- (UIImage *)asImageCombinedWithAlpha:(const ARDKBitmap *)alpha;

@end

@interface UIImage (UIImage_ARDKAdditions)

/// Convert a SmartOffice UIImage into a more generally acceptable form
///
/// UIImagePNGRepresentation fails on the UIImages we use in the majority of
/// the library, probably because of the color space.
/// This method recreates the image in a form acceptable to
/// UIImagePNGRepresentation.
- (UIImage *)ARDKsanitizedImage;

@end


@protocol ARDKRender <NSObject>
/// Abort a previously started render. Calling this for a render that
/// has yet to complete should avoid any delay when the system comes
/// to deallocate it. Otherwise dealloc may wait for the render to
/// complete, momentarily stalling the UI thread.
- (void)abort;
@end


/// Object representing hyperlinks.
///
/// May be either an internal or external link
@protocol ARDKHyperlink <NSObject>
/// Handle the link. This acts like a switch statement for the two types
/// of link. Two blocks are passed and the one appropriate to the type of
/// link is called.
- (void)handleCaseInternal:(void (^)(NSInteger page, CGRect box))iblock orCaseExternal:(void (^)(NSURL *url))eblock;
@end

/// Object representing a Table of Contents entry
@protocol ARDKTocEntry <ARDKHyperlink>
@property (copy) NSString *label;
@property NSUInteger depth;
@property BOOL open;
@property (retain) NSMutableArray<id<ARDKTocEntry>> *children;
@end


@protocol ARDKPage <NSObject>

/// The page size in pixels (not necessarily integer)
@property(readonly) CGSize size;

/// Kick off a render into a bitmap at a specific zoom. orig is the document origin
/// in bitmap coordinates. The block is called on the UI thread when the render has
/// completed.
///
/// This should be contrasted with renderAtZoom:withDocOrigin:intoBitmap, which
/// completes synchronously. In almost all cases, the asynchronous version with
/// the progress: parameter/block should be used, because:
/// 1) If running on the UI thread, it is bad to block it (and renders can
/// take a significant amount of time)
/// 2) There is no way to cancel a synchronous render
- (id<ARDKRender>)renderAtZoom:(CGFloat)zoom
             withDocOrigin:(CGPoint)orig
                intoBitmap:(ARDKBitmap *)bm
                  progress:(void (^)(ARError error))block;

/// Like renderAtZoom:withDocOrigin:intoBitmap:progress: but using a small
/// intermediate buffer to which to render and then copy to the target
/// bit map. This is good for updating a bitmap that is live without causing
/// flickering on the screen.
- (id<ARDKRender>)updateAtZoom:(CGFloat)zoom
                 withDocOrigin:(CGPoint)orig
                    intoBitmap:(ARDKBitmap *)bm
                      progress:(void (^)(ARError error))block;

/// Kick off a render of a layer into a bitmap at a specific zoom. orig is
/// the document origin in bitmap coordinates. The block is called on the UI
/// thread when the render has completed.
///
- (id<ARDKRender>)renderLayer:(int)layer
                       atZoom:(CGFloat)zoom
                withDocOrigin:(CGPoint)orig
                   intoBitmap:(ARDKBitmap *)bm
                     progress:(void (^)(ARError error))block;

/// Kick off a render of a layer into a bitmap and alpha at a specific zoom. orig is
/// the document origin in bitmap coordinates. The block is called on the UI
/// thread when the render has completed.
///
- (id<ARDKRender>)renderLayer:(int)layer
            usingUpdateBuffer:(BOOL)update
                       atZoom:(CGFloat)zoom
                withDocOrigin:(CGPoint)orig
                   intoBitmap:(ARDKBitmap *)bm
                     andAlpha:(ARDKBitmap *)am
                     progress:(void (^)(ARError error))block;

/// Render into a bitmap
///
/// Parameters are the same as renderAtZoom:withDocOrigin:intoBitmap:progress:
///
/// This function will block the UI thread, so unless you absolutely need a
/// synchronous render you should use
/// renderAtZoom:withDocOrigin:intoBitmap:progress: instead.
- (ARError)renderAtZoom:(CGFloat)zoom
          withDocOrigin:(CGPoint)orig
             intoBitmap:(ARDKBitmap *)bm;

/// Render a specific layer into a bitmap
///
/// Parameters are the same as renderAtZoom:withDocOrigin:intoBitmap:progress:
///
/// This function will block the UI thread, so unless you absolutely need a
/// synchronous render you should use
/// renderLayer:atZoom:withDocOrigin:intoBitmap:progress: instead.
- (ARError)renderLayer:(int)layer
                atZoom:(CGFloat)zoom
         withDocOrigin:(CGPoint)orig
            intoBitmap:(ARDKBitmap *)bm;

/// Render a specific layer into a bitmap and counterpart alpha channel
///
/// Parameters are the same as renderLayer:atZoom:withDocOrigin:intoBitmap:progress:
///
/// This function will block the UI thread, so unless you absolutely need a
/// synchronous render you should use
/// renderLayer:atZoom:withDocOrigin:intoBitmap:andAlpha:progress: instead.
- (ARError)renderLayer:(int)layer
                atZoom:(CGFloat)zoom
         withDocOrigin:(CGPoint)orig
            intoBitmap:(ARDKBitmap *)bm
              andAlpha:(ARDKBitmap *)am;

@end

// The possible results of a save operation
typedef enum ARDKSaveResult
{
    ARDKSave_Succeeded,
    ARDKSave_Error,
    ARDKSave_Cancelled
} ARDKSaveResult;

/// Protocol to provide access to clipboard
///
/// Depending on the security model of the application, the implementations of
/// these properties may interact with the system clipboard, or to implement
/// a secure clipboard that is internal to the application.
///
/// Properties should behave the same as UIPasteboard
///
/// @see SODKDocument.pasteboard
@protocol ARDKPasteboard

/// Whether the pasteboard has textual content
@property(nonatomic, readonly) BOOL ARDKPasteboard_hasStrings;

/// Set/get the current contents of the clipboard
@property(nonatomic,copy,setter=ARDKPasteboard_setString:) NSString *ARDKPasteboard_string;

/// The number of times the pasteboard’s contents have changed.
@property(readonly, nonatomic) NSInteger ARDKPasteboard_changeCount;

@end

/// Protocol for monitoring document events
@protocol ARDKDocumentEventTarget <NSObject>

/// Called as pages are loaded from the document. complete will be YES if when
/// there are no more pages to load. There may be further calls, e.g., if pages
/// are added or deleted from the document.
- (void)updatePageCount:(NSInteger)pageCount andLoadingComplete:(BOOL)complete;

/// Called when pages have altered in size.
- (void)pageSizeHasChanged;

/// Called when a selection is made within the document, moved or
/// removed.
- (void)selectionHasChanged;

/// Called each time a document layout operation completes.
- (void)layoutHasCompleted;

@end

@protocol ARDKLib;
@protocol ARDKDoc <NSObject>

@property(readonly) id<ARDKLib> lib;

/// Abstracted access to the app's pasteboard
@property(retain) id<ARDKPasteboard> pasteboard;

/// Allocate a bitmap of a specific size
- (ARDKBitmap *)bitmapAtSize:(CGSize)size;

/// Determine if the document has been modified
///
/// Because of the use of threads within the core, there may be a delay in
/// this becoming set. For that reason, we at times set this from the app
@property BOOL hasBeenModified;

/// Number of pages currently in the document
///
/// If the document is still loading, this is the number of pages loaded so
/// far.
@property(readonly) NSInteger pageCount;

/// Whether loading has completed
@property(readonly) BOOL loadingComplete;

/// The type of document
@property(readonly) ARDKDocType docType;

/// The document supports page reordering, deletion and duplication
@property(readonly) BOOL docSupportsPageManipulation;

/// Whether the document is being saved
@property(readonly) BOOL isBeingSaved;

/// The document type based on file extension
+ (ARDKDocType)docTypeFromFileExtension:(NSString *)filePath;

/// progressBlock is called repeatedly on the UI thread as new pages become
/// available. Once the document is fully loaded 'complete' will be passed as
/// 'YES'.
/// progressBlock is also called when the document is edited, either adding or
/// removing pages, with numPages decreasing in the page-removing case.
/// This property should not be changed after 'loadDocument' is called.
@property (copy)void (^progressBlock)(NSInteger numPages, BOOL complete);

/// errorBlock is called on the UI thread once for each error that occurs
/// as the document loads.
/// It may be called multiple times.
/// Not all errors are fatal.
/// This property should not be changed after 'loadDocument' is called.
@property (copy)void (^errorBlock)(ARDKDocErrorType error);

/// successBlock is called on the UI thread once the document has fully loaded
/// and no error has occurred.
/// This indicates that the document has completely loaded. The first page of
/// the document will usually be available for render significantly before this
/// call is made, interactive apps should use progressBlock.
/// This property should not be changed after 'loadDocument' is called.
@property (copy)void (^successBlock)(void);

/// Add a target for receiving document events
///
/// Newly added targets will receive at least one call to updatePageCount.
/// Targets are not retained.
- (void)addTarget:(id<ARDKDocumentEventTarget>)target;

/// Start loading the document
///
/// This should be called exactly once after any progress/error/success blocks
/// have been set. The page-size block can be set at any time.
- (ARError)loadDocument;

/// Start a save operation
- (void)saveTo:(NSString *)path completion:(void (^)(ARDKSaveResult res, ARError err))block;

///
/// Provide a password necessary to open the document
///
/// This should only be called in response to request for a password from
/// the core library (ie. a ARDKDocErrorType_PasswordRequest error).
- (void)providePassword:(NSString *)password;

/// Delete a page from the document
///
/// pageNumber lies in the range 0 to one less than the number of pages
- (void)deletePage:(NSInteger)pageNumber;


/// Add a blank page to a document
///
/// pageNumber lies in the range 0 to one less than the number of pages
- (void)addBlankPage:(NSInteger)pageNumber;

/// Duplicate a page within the document
///
/// pageNumber lies in the range 0 to one less than the number of pages
- (void)duplicatePage:(NSInteger)pageNumber;

/// Move a page to a new location within a document
///
/// pageNumber and newNumber lies in the range 0 to one less than the number of pages
- (void)movePage:(NSInteger)pageNumber to:(NSInteger)newNumber;

/// Return a specific page of an open document
- (id<ARDKPage>)getPage:(NSInteger)pageNumber update:(void (^)(CGRect area))block;

/// Abort loading if still active. This should be called when an SODKDoc
/// is no longer needed, otherwise it may take a long time to deallocate
/// and be using resources.
- (void)abortLoad;

@end


/// Initial object for interacting with SmartOffice Library
///
/// Note that (unless explicitly noted otherwise) all calls to SODKLib (and all
/// other SmartOffice APIs should only be made from the main (ie. UI) thread.
///
/// All callbacks (eg. blocks) that are passed to SmartOffice will also be
/// run on the main thread.
@protocol ARDKLib <NSObject>

/// For internal use only
+ (id<ARDKSecureFS>)secureFS;

+ (NSDictionary<NSString *, NSString *> *)version;

@property (readonly) ARDKSettings *settings;

- (instancetype)initWithSettings:(ARDKSettings *)settings;

/// Open a document given the path of the file and its file type.
///
/// The caller should set any progress/error/success blocks on the SODKDoc
/// then call it's loadDocument.
-(id<ARDKDoc>)docForPath:(NSString *)path ofType:(ARDKDocType)docType;

@end
