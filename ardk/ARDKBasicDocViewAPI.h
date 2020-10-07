//
//  ARDKBasicDocViewAPI.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 04/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKDocSession.h"
#import "ARDKPageGeometry.h"
#import "ARDKBasicDocViewDelegate.h"

@protocol ARDKBasicDocViewAPI <NSObject>
@property(readonly) id<ARDKDoc> doc;
@property(weak) id<ARDKBasicDocViewDelegate> delegate;
@property(readonly) ARDKDocSession *session;
@property id<ARDKPasteboard> pasteboard;

/// Currently displayed page
@property(readonly) NSInteger currentPage;

@property(readonly) CGSize viewSize;

// Tranform from page coordinates to screen coordinates
- (CGAffineTransform)pageToScreen:(NSInteger)pageNo;

/// Whether the software keyboard is being shown or will be shonw
@property(readonly) BOOL hasKeyboard;

/// Enable or disable text typing
@property BOOL textTypingEnabled;

/// Control of the viewed-page stack, used to return to a viewing position
/// after visiting a new location via a link, or for revisiting a link
@property(readonly) BOOL viewingStatePreviousAllowed;
@property(readonly) BOOL viewingStateNextAllowed;
- (void)viewingStatePrevious;
- (void)viewingStateNext;
- (void)pushViewingState:(NSInteger)page withOffset:(CGPoint)offset;

- (void)showArea:(CGRect)box onPage:(NSInteger)pageNum animated:(BOOL)animated onCompletion:(void (^)(void))block;

/// Pan the document view to display an area of a page
- (void)showArea:(CGRect)box onPage:(NSInteger)page;

/// Show a set of page areas, possibly animated with a callback on completion
- (void)showAreas:(NSArray<ARDKPageArea *> *)areas animated:(BOOL)animated onCompletion:(void (^)(void))block;

/// Show a set of page areas with animation
- (void)showAreas:(NSArray<ARDKPageArea *> *)areas;

/// Pan the document view to a page
- (void)showPage:(NSInteger)pageNum;

/// Pan the document view to a page, with callback on completion
- (void)showPage:(NSInteger)pageNum animated:(BOOL)animated onCompletion:(void (^)(void))block;

/// Pan a specified position within a page to the top left of the screen
- (void)showPage:(NSInteger)pageIndex withOffset:(CGPoint)pt;

/// Pan a specified position within a page to the top left of the screen
/// with control of whether to animate the pan or not
- (void)showPage:(NSInteger)pageIndex withOffset:(CGPoint)pt animated:(BOOL)animated;

/// Pan the document view to show the bottom of a page
- (void)showEndOfPage:(NSInteger)pageNum;

/// Map a point within the scrolling view to a cell if any
- (void)forCellAtPoint:(CGPoint)pt do:(void (^)(NSInteger index, UIView *cell, CGPoint pt))block;

/// Map a point within the scrolling view to the nearest cell
- (void)forCellNearestPoint:(CGPoint)pt do:(void (^)(NSInteger, UIView *))block;

// Tell the UITextInput implementation that the selection
/// has changed
- (void)resetTextInput;

@end
