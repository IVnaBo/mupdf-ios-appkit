// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import "ARDKCollectionViewCell.h"

@implementation ARDKCollectionViewCell
{
    UIView<ARDKPageCellDelegate> *_pageView;
    CGRect _pageViewFrame;
    NSInteger _pageNumber;
}

- (NSInteger)pageNumber
{
    return _pageNumber;
}

- (UIView<ARDKPageCellDelegate> *)pageView
{
    return _pageView;
}

- (void)setPageView:(UIView<ARDKPageCellDelegate> *)pageView
{
    if (_pageView)
        [_pageView removeFromSuperview];

    _pageView = pageView;
    [self.contentView addSubview:pageView];
}

- (CGRect)pageViewFrame
{
    return _pageViewFrame;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.pageView prepareForReuse];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    CGRect frame = {CGPointZero, layoutAttributes.frame.size};
    // Record the page number and frame in case _pageView is yet to be
    // initialised. (The creation code can interogate these properties.
    _pageNumber = layoutAttributes.indexPath.item;
    _pageViewFrame = frame;
    // If _pageView already exists, pass the values explicitly.
    [_pageView useForPageNumber:_pageNumber withSize:_pageViewFrame.size];
}

- (void)setSelected:(BOOL)selected
{
    [self.pageView setSelected:selected];
}

@end
