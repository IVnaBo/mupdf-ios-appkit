//
//  ARDKNUpLayout.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 23/03/2015.
//  Copyright (c) 2015 Artifex Software Inc. All rights reserved.
//

#import "ARDKNUpLayout.h"

#define INTERPAGE_GAP (10)
#define NUP_MAX (5)

@implementation ARDKNUpLayout
{
    NSInteger _pageCount;
    NSInteger _nrows;
    CGFloat _viewWidth;
    CGRect _viewedArea;
    CGFloat _aspectRatio;
    CGRect _populatedArea;
    CGFloat _gap;
}

-(instancetype)init
{
    self = [super init];
    self.nup = 1;
    self->_aspectRatio = 1.0;
    return self;
}

- (CGFloat)viewWidth
{
    return _viewWidth;
}

- (void)setViewWidth:(CGFloat)viewWidth
{
    _viewWidth = viewWidth;
    [self invalidateLayout];
}

- (CGRect)viewedArea
{
    return _viewedArea;
}

- (void)setViewedArea:(CGRect)viewedArea
{
    _viewedArea = viewedArea;
    _aspectRatio = viewedArea.size.width / viewedArea.size.height;
    CGRect biggerThanNeeded = CGRectInset(viewedArea, -viewedArea.size.width * 0.4, -viewedArea.size.height * 0.4);
    if (!CGRectContainsRect(_populatedArea, _viewedArea) || !CGRectContainsRect(biggerThanNeeded, _populatedArea))
    {
        _populatedArea = CGRectInset(_viewedArea, -viewedArea.size.width * 0.2, -viewedArea.size.height * 0.2);
        [self invalidateLayout];
    }
}

- (CGRect)pageFrame:(NSInteger)page
{
    NSInteger x = page % self.nup;
    NSInteger y = page / self.nup;

    return CGRectMake(x * (_cellSize.width + _gap), y * (_cellSize.height + _gap), _cellSize.width, _cellSize.height);
}

- (NSInteger)maxNUp
{
    return MIN(NUP_MAX, MAX(_pageCount, 1));
}

- (CGFloat)zoomForN:(NSInteger)nup
{
    // Calculate the zoom that fits n columns in the view
    CGFloat zoom = (_cellSize.width - INTERPAGE_GAP * (nup - 1)) / (nup * _cellSize.width);
    // Calculate the zoom that fits a cell's height to the view
    CGFloat hzoom = _cellSize.width / _cellSize.height / _aspectRatio;

    // If the page height doesn't fit and hzoom doesn't take us
    // up to the next nup level then use that. If it does take
    // us to the next level then the user may as well use that
    // level, so we don't special case this one
    if (hzoom < zoom)
    {
        if (nup >= [self maxNUp])
        {
            zoom = hzoom;
        }
        else
        {
            CGFloat nzoom = (_cellSize.width - INTERPAGE_GAP * nup) / ((nup + 1) * _cellSize.width);
            if (nzoom < hzoom)
                zoom = hzoom;
        }
    }

    return zoom;
}

- (CGFloat)minZoom
{
    return [self zoomForN:[self maxNUp]];
}

- (CGFloat)fitZoom
{
    return [self zoomForN:self.nup];
}

- (NSInteger)suggestedNup
{
    // We want the nup value that results in a scaling most close to the current one. A
    // direct equation for this is complicated because of special casing when page height
    // is close to screen height, so we just iterate throught the possible values of nup
    // and pick the closest.
    CGFloat currentScale = _cellSize.width / _viewedArea.size.width;
    NSInteger nearestNup = 0;
    NSInteger maxNUp = [self maxNUp];
    CGFloat closestFactor = FLT_MAX;
    for (int i = 1; i <= maxNUp; i++)
    {
        CGFloat factor = [self zoomForN:i] / currentScale;
        // We are interested in how close the factor is but not whether it is smaller or greater,
        // so we consider a factor and its inverse to be equivalent. If, od the two values,
        // we use the larger (the one that is greater than 1.0) as representative, then the
        // minimum is the closest.
        if (factor < 1.0) factor = 1.0 / factor;
        if (factor < closestFactor)
        {
            closestFactor = factor;
            nearestNup = i;
        }
    }

    assert(nearestNup != 0);
    return nearestNup ? nearestNup : 1;
}

- (void)prepareLayout
{
    _gap = INTERPAGE_GAP;
    _nrows = (_pageCount + self.nup - 1)/self.nup;

    // Calculate _gap to give gaps of size INTERPAGE_GAP when the rows
    // are scaled down to fit the screen width
    _gap = self.nup * self.viewWidth * INTERPAGE_GAP / (self.viewWidth - INTERPAGE_GAP * (self.nup - 1));
}

- (CGSize)collectionViewContentSize
{
    return CGSizeMake(_nup * (_cellSize.width + _gap) - _gap, _nrows * (_cellSize.height + _gap) - _gap);
}

- (void)within:(CGRect)rect forEachViewedPage:(void (^)(NSInteger page, CGRect frame))block
{
    rect = CGRectIntersection(rect, _populatedArea);

    if (!CGRectIsNull(rect))
    {
        NSInteger page = rect.origin.y >= 0 ? (int)(rect.origin.y / (_cellSize.height + _gap)) * self.nup
        : 0;

        while (page < _pageCount)
        {
            CGRect frame = [self pageFrame:page];

            if (frame.origin.y > rect.origin.y + rect.size.height)
                break;

            block(page, frame);
            
            page++;
        }
    }
}

- (NSArray *)viewedPages
{
    NSMutableArray *array = [NSMutableArray array];

    [self within:CGRectInfinite forEachViewedPage:^(NSInteger page, CGRect frame) {
        [array addObject:[NSNumber numberWithInteger:page]];
    }];

    return array;
}

- (void)viewPages:(NSArray *)pages
{
    CGRect rect = CGRectNull;

    for (NSNumber *n in pages)
        rect = CGRectUnion(rect, [self pageFrame:n.intValue]);

    if (!CGRectIsNull(rect))
        _populatedArea = rect;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSMutableArray *array = [NSMutableArray array];

    [self within:rect forEachViewedPage:^(NSInteger page, CGRect frame) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:page inSection:0];
        UICollectionViewLayoutAttributes *attrs = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
        attrs.frame = frame;
        [array addObject:attrs];
    }];

    return array;
}


- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *attrs = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    CGRect frame = [self pageFrame:indexPath.item];
    BOOL __block found = NO;
    [self within:CGRectInfinite forEachViewedPage:^(NSInteger page, CGRect frame) {
        if (page == attrs.indexPath.item)
            found = YES;
    }];

    // If the requested item is not in the populated area then
    // return a frame outside the collection view's area, so that
    // it wont be incarnated
    if (!found)
        frame.origin.x = - 2 * frame.size.width;

    attrs.frame = frame;
    return attrs;
}

@end
