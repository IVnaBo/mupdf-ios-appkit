// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import <Foundation/Foundation.h>

// Protocols used in page-positioning classes. ARDKPageCellDelegate
// is implemented by each page view, and ARDKPageCell is implemented
// by the containing views that control the page view's position
// and movement. The protocols permit communication between the
// two. ARDKCollectionViewCell is an implementation of ARDKPageCell
// for use with UICollectionViews.
//
// Cells control their delagate's motion by having them as subviews
// and moving themselves. That is why none of the methods below
// relate to movement.

@protocol ARDKPageCellDelegate <NSObject>

// When pages move off screen, rather than destroy them, they are
// cached and later reused. In between uses prepareForReuse is
// called.
- (void)prepareForReuse;

// For each use (the first and for any reuse), useForPageNumber:withSize:
// is called.
- (void)useForPageNumber:(NSInteger)pageNumber withSize:(CGSize)size;

// setSelected is called to control highlighting of the selected page
- (void)setSelected:(BOOL)selected;

// Called to ensure a page completely redraws on next render
- (void)onContentChange;

@end

@protocol ARDKPageCell <NSObject>

// The page number for which the cell is currently in use
@property(readonly) NSInteger pageNumber;

// The page view currently controlled by the cell
@property UIView<ARDKPageCellDelegate> * _Nullable pageView;

// The current frame for the cell (possibly we could use the cells
// actual frame, needs investigating).
@property(readonly)CGRect pageViewFrame;
@end
