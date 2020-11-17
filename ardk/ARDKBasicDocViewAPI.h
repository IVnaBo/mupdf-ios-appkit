//  Copyright © 2017-2020 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>
#import "ARDKDocSession.h"
#import "ARDKPageGeometry.h"
#import "ARDKBasicDocViewDelegate.h"

/// The protocol via which to control basic views on a document.
/// where "basic" refers to the views not including significant
/// UI elements.
@protocol ARDKBasicDocViewAPI <NSObject>

/// The document being viewed
@property(nonnull,readonly) id<ARDKDoc> doc;

/// The views delegate
@property(nullable,weak) id<ARDKBasicDocViewDelegate> delegate;

/// The document viewing/editing session, on which the view
/// is based.
@property(nonnull,readonly) ARDKDocSession *session;

/// The pasteboard implementation used by this document view.
/// Bespoke pasteboard implementations may be used for the
/// sake of securing copy and paste.
@property(nullable) id<ARDKPasteboard> pasteboard;

/// Currently displayed page
@property(readonly) NSInteger currentPage;

// Tranform from page coordinates to screen coordinates
- (CGAffineTransform)pageToScreen:(NSInteger)pageNo;

/// Whether the software keyboard is being shown or will be shonw
@property(readonly) BOOL hasKeyboard;

/// Enable or disable text typing
@property BOOL textTypingEnabled;

/// Control of the viewed-page stack, used to return to a viewing position
/// after visiting a new location via a link, or for revisiting a link
///
/// Whether there is a previous viewing state
@property(readonly) BOOL viewingStatePreviousAllowed;
/// Wherther there is a next viewing state
@property(readonly) BOOL viewingStateNextAllowed;
/// Move to previous viewing state
- (void)viewingStatePrevious;
/// Move to next viewing state
- (void)viewingStateNext;
/// Add the current viewing state to the end of the list
- (void)pushViewingState:(NSInteger)page withOffset:(CGPoint)offset;

/// Update the view to make a specific area of a page visible, with
/// the option to perform the movement animated or immediately. and
/// the option to perform a further task on completion
- (void)showArea:(CGRect)box onPage:(NSInteger)pageNum animated:(BOOL)animated onCompletion:(void (^ _Nullable)(void))block;

/// Update the view to make a specific area of a page visible
- (void)showArea:(CGRect)box onPage:(NSInteger)page;

/// Show a set of page areas, possibly animated with a callback on completion
- (void)showAreas:(NSArray<ARDKPageArea *> * _Nonnull)areas animated:(BOOL)animated onCompletion:(void (^ _Nullable)(void))block;

/// Show a set of page areas with animation
- (void)showAreas:(NSArray<ARDKPageArea *> * _Nonnull)areas;

/// Pan the document view to a page
- (void)showPage:(NSInteger)pageNum;

/// Pan the document view to a page, with callback on completion
- (void)showPage:(NSInteger)pageNum animated:(BOOL)animated onCompletion:(void (^ _Nullable)(void))block;

/// Pan a specified position within a page to the top left of the screen
- (void)showPage:(NSInteger)pageIndex withOffset:(CGPoint)pt;

/// Pan a specified position within a page to the top left of the screen
/// with control of whether to animate the pan or not
- (void)showPage:(NSInteger)pageIndex withOffset:(CGPoint)pt animated:(BOOL)animated;

/// Pan the document view to show the bottom of a page
- (void)showEndOfPage:(NSInteger)pageNum;

/// Map a point within the scrolling view to a cell if any
- (void)forCellAtPoint:(CGPoint)pt do:(void (^ _Nonnull)(NSInteger index, UIView * _Nonnull cell, CGPoint pt))block;

/// Map a point within the scrolling view to the nearest cell
- (void)forCellNearestPoint:(CGPoint)pt do:(void (^ _Nonnull)(NSInteger, UIView * _Nonnull))block;

// Tell the UITextInput implementation that the selection
/// has changed
- (void)resetTextInput;

@end
