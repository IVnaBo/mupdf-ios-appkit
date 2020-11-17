//
//  ARDKPageView.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 05/07/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKPageCell.h"

#import "ARDKLib.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARDKPageView : UIView<ARDKPageCellDelegate>

/// initialize the page view
- (instancetype)initWithDoc:(id<ARDKDoc>)doc;

/// Take the current size allocated to pages and adjust
/// the height to match the true aspect ratio
+ (CGSize)adjustSize:(CGSize)size toPage:(id<ARDKPage>)page;

/// Return the transform from page space to document space
+ (CGAffineTransform) transformForPage:(id<ARDKPage>)page withinFrame:(CGRect)frame;

/// The color to use when highlighting the view with a surrounding border
@property(nullable) UIColor *highlightColor;

/// Position the page to the top left of the view. We use the same
/// size view for all pages. This affects the positioning for pages
/// that differ. The default is to center the page within the view.
@property BOOL positionPageTopLeft;

/// The maximum aspect ratio past which we'll restrict the page to
/// showing a proportion of the document
@property CGFloat maxAspect;

/// The document from which the pages are taken
@property(readonly) id<ARDKDoc> doc;

/// The index of the displayed page
@property(readonly) NSInteger pageNumber;

/// The page object for the displayed page
@property(readonly) id<ARDKPage> page;

/// The zoom factor used internally to match doc to frame
@property CGFloat baseZoom;

/// Inform a page of a content change. When this is called, the next call to displayArea
/// will provoke a render even if the requested area and scale are unchanged
- (void)onContentChange;

/// Turn page updates on and off
@property BOOL updatesDisabled;

/// Block to call when updates occur
@property(copy) void (^ _Nullable onUpdate)(void);

/// Kick off a render of a particular area of the page at a specific scale
- (void)displayArea:(CGRect)area atScale:(CGFloat)scale usingBitmap:(ARDKBitmap *)bm whenDone:(void (^ _Nullable)(void))block;

/// Mark as not taking part in a render pass. This is necessary to keep
/// the alternation of bitmap use for rendering
- (void)missRenderPass;

/// Reset state ready for reuse
- (void)reset;

/// Overridable, called when something causes a resize that isn't a simple
/// application of scaling by the OS. Overlays may need to be informed of
/// a new scaling to apply internally and be told to redraw.
- (void)resizeOverlays;

@end

NS_ASSUME_NONNULL_END
