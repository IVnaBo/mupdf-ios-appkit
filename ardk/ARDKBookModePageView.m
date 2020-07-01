// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import "ARDKPageController.h"
#import "ARDKGeometry.h"
#import "ARDKPageView.h"
#import "ARDKBookModePageView.h"

@interface ARDKBookModeBlockHolder : NSObject
@property(readonly) void (^block)(void);
+ (instancetype)holderOfBlock:(void (^)(void))block;
@end

@implementation ARDKBookModeBlockHolder

- (instancetype)initWithBlock:(void (^)(void))block
{
    self = [super init];
    if (self)
        _block = block;
    return self;
}

+ (instancetype)holderOfBlock:(void (^)(void))block
{
    return [[ARDKBookModeBlockHolder alloc] initWithBlock:block];
}

@end

@interface ARDKBookModePageView ()
@property NSMutableArray<ARDKBookModeBlockHolder *> *blocks;
@end

@implementation ARDKBookModePageView
{
    ARDKBitmap *_bitmap;
    UIView<ARDKPageCellDelegate> *_pageView;
    CGSize _pageSize;
}

@synthesize pageNumber=_pageNumber;

- (UIView<ARDKPageCellDelegate> *)pageView
{
    return _pageView;
}

- (void)doRender
{
    ARDKPageView *pv = (ARDKPageView *)_pageView;
    CGRect viewRect = {CGPointZero, pv.frame.size};
    CGFloat scale = UIScreen.mainScreen.scale;
    CGRect bmRect = ARCGRectScale(viewRect, scale);
    ARDKBitmap *bm = [ARDKBitmap bitmapFromSubarea:bmRect ofBitmap:_bitmap];
    [pv displayArea:viewRect atScale:scale usingBitmap:bm whenDone:^{
        void (^block)(void) = self.blocks.lastObject.block;
        if (block)
            block();
        [self.blocks removeLastObject];
        if (self.blocks.count > 0)
            [self doRender];
    }];
}

- (void)render:(void (^)(void))completeBlock
{
    [self.blocks insertObject:[ARDKBookModeBlockHolder holderOfBlock:^{
        if (completeBlock)
            completeBlock();
    }] atIndex:0];

    if (self.blocks.count == 1)
        [self doRender];
}

- (void)setPageSize:(CGSize)size
{
    _pageSize = size;

}

- (void)setPageView:(UIView<ARDKPageCellDelegate> *)pageView
{
    if (_pageView)
        [_pageView removeFromSuperview];

    _pageView = pageView;
    [self addSubview:pageView];
}

- (CGRect)pageViewFrame
{
    CGRect rect = {CGPointZero, _pageSize};
    return rect;
}

- (instancetype)initForPage:(NSInteger)pageNumber
                 withBitmap:(ARDKBitmap *)bitmap
{
    self = [super initWithFrame:CGRectZero];
    _pageNumber = pageNumber;
    _bitmap = bitmap;
    _blocks = [NSMutableArray arrayWithCapacity:2];
    return self;
}
@end
