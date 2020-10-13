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
@property(weak) id<ARDKBookModePageViewControllerDelegate> delegate;
@property(readonly) ARDKBitmap *bitmap;
@property NSInteger overlayToggle;
@property BOOL zoomedMode;
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

- (ARDKBitmap *)fullBitmapForIndex:(NSInteger)pageNumber
{
    NSInteger index = (pageNumber / 2) % 3;
    CGSize size = CGSizeMake(_bitmap.width, _bitmap.height / 3);
    CGRect rect = CGRectMake(0, size.height * index, size.width, size.height);
    return [ARDKBitmap bitmapFromSubarea:rect ofBitmap:_bitmap];
}

- (ARDKBitmap *)mainBitmap
{
    ARDKBitmap *fullBitmap = [self fullBitmapForIndex:self.pageNumber];
    NSInteger index = self.pageNumber % 2;
    CGSize size = CGSizeMake(fullBitmap.width / 2, fullBitmap.height);
    CGRect rect = CGRectMake(size.width * index, 0, size.width, size.height);
    return [ARDKBitmap bitmapFromSubarea:rect ofBitmap:fullBitmap];
}

- (ARDKBitmap *)overlayBitmap0
{
    return [self fullBitmapForIndex:self.pageNumber+2];
}

- (ARDKBitmap *)overlayBitmap1
{
    return [self fullBitmapForIndex:self.pageNumber+4];
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

- (void)renderZoomed:(BOOL)zoomed onComplete:(void (^)(void))completeBlock
{
    [self doQueued:^(void (^done)(void)) {
        ARDKPageView *pv = (ARDKPageView *)self.pageView;
        CGRect viewRect = {CGPointZero, pv.frame.size};
        CGFloat scale = UIScreen.mainScreen.scale;
        CGRect renderRect;
        ARDKBitmap *renderBm;
        if (zoomed)
        {
            CGRect parentRect = [pv convertRect:self.delegate.view.bounds fromView:self.delegate.view];
            renderRect = CGRectIntersection(parentRect, viewRect);
            self.overlayToggle = (self.overlayToggle + 1) % 2;
            renderBm = self.overlayToggle ? self.overlayBitmap0 : self.overlayBitmap1;
        }
        else
        {
            renderRect = viewRect;
            renderBm = self.mainBitmap;
        }

        [pv displayArea:renderRect atScale:scale usingBitmap:renderBm whenDone:^{
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
                   delegate:(nonnull id<ARDKBookModePageViewControllerDelegate>)delegate
{
    self = [super initWithFrame:CGRectZero];
    _delegate = delegate;
    _pageNumber = pageNumber;
    _bitmap = bitmap;

    _actions = [NSMutableArray arrayWithCapacity:2];
    return self;
}
@end
