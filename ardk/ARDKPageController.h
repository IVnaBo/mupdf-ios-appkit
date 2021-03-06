// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import "ARDKPageGeometry.h"
#import "ARDKPageCell.h"
#import "ARDKDocSession.h"

@protocol ARDKPageControllerDelegate <NSObject>

/// The document session
@property(readonly) ARDKDocSession *session;

/// The view that constrains the rendering area
@property(readonly) UIView *view;

/// Called to adjust the size of a cell to match the
/// aspect ratio of the page.
- (CGSize)adjustSize:(CGSize)size toPage:(NSInteger)page;

/// Called to allow the delegate to create the page view and
/// add it to the cell as a subview.
- (void)setupPageCell:(id<ARDKPageCell>)pageCell forPage:(NSInteger)page;


/// Called to allow the delegate to synchronise with page
/// movements.
- (void)viewHasMoved;

/// Override to detect taps on pages.
- (void)didTapCell:(UIView *)cell at:(CGPoint)point;

/// Override to detect double taps on pages.
- (void)didDoubleTapCell:(UIView *)cell at:(CGPoint)point;

/// Override to pick up the start of a long press.
- (void)didStartLongPress;

/// Override to pick up movement during long press.
- (void)didLongPressMoveInCell:(UIView *)cell at:(CGPoint)point;

/// Override to pick up the ending of long press.
- (void)didEndLongPress;

/// Override to detect user-invoked scrolling.
- (void)didDragDocument;

/// Overridable, called when the screen area is restricted by the keyboard.
- (void)adjustToReducedScreenArea;

/// Called in relow mode when the zoom scale changes
- (void)onReflowZoom;

@end

@protocol ARDKPageController <NSObject>

/// Current document page count. The owner of the page controller
/// is responsible for keeping this up to date. Can be updated
/// iteratively as new
@property NSInteger pageCount;

// The current cell size, not accounting for zoom.
@property(readonly) CGSize cellSize;

/// Enable changes of behaviour necessary for reflow mode
/// When reflowing the layout will stay in a single column and
/// changes of zoom scale will be reported back to the superclass
@property BOOL reflowMode;

/// Control dark mode
@property BOOL darkMode;

/// Enable drawing mode
///
/// Enabling 'drawing mode' stops this view controller from taking events
/// that are needed for drawing.
/// ie. it disables normal pan / tap / double tap
@property(nonatomic) BOOL drawingMode;

// The current zoom scale. 1.0 makes page width match view width.
@property(readonly) CGFloat zoomScale;

/// Set the zoom scale, optionally with animation
- (void)setZoomScale:(CGFloat)scale animated:(BOOL)animated;

// Whether long press zoom is enabled.
@property BOOL longPressEnabled;

// Whether the software keyboard is currently show.
@property(readonly) BOOL keyboardShown;

/// Set this property to avoid the document scrolling in reaction
/// to the keyboard being removed from the screen. Controls that
/// need to align with items within the document may set this
/// while on screen.
@property BOOL disableScrollOnKeyboardHidden;

/// Tranform from cell coordinates to screen coordinates.
- (CGAffineTransform) cellToScreen:(NSInteger)pageNo;

/// Iterate through the currently represented pages calling a block
- (void)iteratePages:(void (^)(NSInteger i, UIView<ARDKPageCellDelegate> *pageView, CGRect screenRect))block;

/// Adjust for a change in page size
- (void)updateItemSize;

/// Make specified areas of pages visible on screen
- (void)showAreas:(NSArray<ARDKPageArea *> *)areas animated:(BOOL)animated onCompletion:(void (^)(void))block;

/// Show a page on screen with a specified position within a page at the top left of the screen
- (void)showPage:(NSInteger)pageNum withOffset:(CGPoint)pt animated:(BOOL)animated;

/// Make a page appear centrally in the view, calling a block on completion
- (void)showPage:(NSInteger)pageNum animated:(BOOL)animated onCompletion:(void (^)(void))block;

/// Forget the last area passed to either of the showArea methods
- (void)forgetShowArea;

/// Unless explicitly forgotten, pan again to the last show area
- (BOOL)reshowArea;

/// Map a point within the scrolling view to a cell if any
- (void)forCellAtPoint:(CGPoint)pt do:(void (^)(NSInteger, UIView *, CGPoint))block;

/// Map a point within the scrolling view to the nearest cell
- (void)forCellNearestPoint:(CGPoint)pt do:(void (^)(NSInteger, UIView *))block;

/// Request page rendering, with the option for forced rerender
- (void)requestRenderWithForce:(BOOL)force;

/// Request notification after first render
- (void)afterFirstRender:(void (^)(void))block;

@end
