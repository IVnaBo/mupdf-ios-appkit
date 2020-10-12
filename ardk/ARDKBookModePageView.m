// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import "ARDKPageController.h"
#import "ARDKGeometry.h"
#import "ARDKPageView.h"
#import "ARDKBookModePageView.h"

typedef void (^ActionBlock)(void (^done)(void));

@interface ARDKBookModeActionHolder : NSObject
@property(readonly) ActionBlock block;
+ (instancetype)holderOfAction:(ActionBlock)block;
@end

@implementation ARDKBookModeActionHolder

- (instancetype)initWithAction:(ActionBlock)block
{
    self = [super init];
    if (self)
        _block = block;
    return self;
}

+ (instancetype)holderOfAction:(ActionBlock)block
{
    return [[ARDKBookModeActionHolder alloc] initWithAction:block];
}

@end

@interface ARDKBookModePageView ()
@property NSMutableArray<ARDKBookModeActionHolder *> *actions;
@property ARDKBitmap *bitmap;
@property ARDKBitmap *hqBitmap;
@end

@implementation ARDKBookModePageView
{
    UIView<ARDKPageCellDelegate> *_pageView;
    CGSize _pageSize;
}

@synthesize pageNumber=_pageNumber;

- (UIView<ARDKPageCellDelegate> *)pageView
{
    return _pageView;
}

- (void)doQueuedActions
{
    ActionBlock nextBlock = self.actions.lastObject.block;
    nextBlock(^(void){
        [self.actions removeLastObject];
        if (self.actions.count > 0)
            [self doQueuedActions];
    });
}

- (void)doQueued:(ActionBlock)block;
{
    // We don't want to queue up more than one action. Get rid of previous actions,
    // other than the one currently running.
    if (self.actions.count > 1)
        self.actions = @[self.actions.lastObject].mutableCopy;
    [self.actions insertObject:[ARDKBookModeActionHolder holderOfAction:block] atIndex:0];
    if (self.actions.count == 1)
        [self doQueuedActions];
}


- (void)render:(void (^)(void))completeBlock
{
    [self doQueued:^(void (^done)(void)) {
        ARDKPageView *pv = (ARDKPageView *)self.pageView;
        CGRect viewRect = {CGPointZero, pv.frame.size};
        CGFloat scale = UIScreen.mainScreen.scale;
        CGRect bmRect = ARCGRectScale(viewRect, scale);
        ARDKBitmap *bm = [ARDKBitmap bitmapFromSubarea:bmRect ofBitmap:self.bitmap];
        [pv displayArea:viewRect atScale:scale usingBitmap:bm whenDone:^{
            if (completeBlock)
                completeBlock();

            done();
        }];
    }];
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

    _actions = [NSMutableArray arrayWithCapacity:2];
    return self;
}
@end
