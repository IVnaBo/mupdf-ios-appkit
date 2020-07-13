// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import "ARDKGeometry.h"
#import "ARDKPageController.h"
#import "ARDKBookModePageView.h"
#import "ARDKBookModePageViewController.h"
#import "ARDKBookModeViewController.h"

#define PRE_PAGES (2)
#define NUM_PAGES (8)

#define NO_DUMMY_PAGE (-1)
#define LONG_PRESS_MIN_DURATION (0.3)

typedef enum {
    LayoutType_TwoUp,
    LayoutType_LeftPage,
    LayoutType_RightPage
} LayoutType;

static void addSubviewFit(UIView *outer, UIView *inner)
{
    [outer addSubview:inner];
    inner.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray<NSLayoutConstraint *> *hFit = [NSLayoutConstraint constraintsWithVisualFormat:@"|[inner]|"
                                                                                  options:0
                                                                                  metrics:nil
                                                                                    views:@{@"inner" : inner}];
    NSArray<NSLayoutConstraint *> *vFit = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[inner]|"
                                                                                  options:0
                                                                                  metrics:nil
                                                                                    views:@{@"inner" : inner}];
    [outer addConstraints:hFit];
    [outer addConstraints:vFit];
}

static void controlConstraints(NSArray<NSLayoutConstraint *> *constraints, BOOL enabled)
{
    for (NSLayoutConstraint *c in constraints)
        c.active = enabled;
}

static NSArray<NSLayoutConstraint *> *makeTwoUpConstraints(UIView *outer, UIView *inner)
{
    // Create layout constraints that use as large a central area of the
    // view, given a defined aspect ratio
    NSLayoutConstraint *centeredX = [NSLayoutConstraint constraintWithItem:outer
                                                                 attribute:NSLayoutAttributeCenterX
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:inner
                                                                 attribute:NSLayoutAttributeCenterX
                                                                multiplier:1.0 constant:0.0];
    NSLayoutConstraint *centeredY = [NSLayoutConstraint constraintWithItem:outer
                                                                 attribute:NSLayoutAttributeCenterY
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:inner
                                                                 attribute:NSLayoutAttributeCenterY
                                                                multiplier:1.0 constant:0.0];
    NSLayoutConstraint *widthEqual = [NSLayoutConstraint constraintWithItem:outer
                                                                  attribute:NSLayoutAttributeWidth
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:inner
                                                                  attribute:NSLayoutAttributeWidth
                                                                 multiplier:1.0 constant:0.0];
    NSLayoutConstraint *heightEqual = [NSLayoutConstraint constraintWithItem:outer
                                                                   attribute:NSLayoutAttributeHeight
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:inner
                                                                   attribute:NSLayoutAttributeHeight
                                                                  multiplier:1.0 constant:0.0];
    NSLayoutConstraint *widthLess = [NSLayoutConstraint constraintWithItem:outer
                                                                 attribute:NSLayoutAttributeWidth
                                                                 relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                    toItem:inner
                                                                 attribute:NSLayoutAttributeWidth
                                                                multiplier:1.0 constant:0.0];
    NSLayoutConstraint *heightLess = [NSLayoutConstraint constraintWithItem:outer
                                                                  attribute:NSLayoutAttributeWidth
                                                                  relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                     toItem:inner
                                                                  attribute:NSLayoutAttributeWidth
                                                                 multiplier:1.0 constant:0.0];
    // Priority for the equal height and width constraints need to be of lower priority so
    // they can be broken. For some crazy reason, it doesn't work unless the width one is
    // slightly lower than the hight one. No idea why.
    widthEqual.priority = 240;
    heightEqual.priority = 250;
    return @[centeredX, centeredY, widthEqual, heightEqual, widthLess, heightLess];
}

static NSArray<NSLayoutConstraint *> *makeLeftPageConstraints(UIView *outer, UIView *inner)
{
    NSLayoutConstraint *topEdge = [NSLayoutConstraint constraintWithItem:outer
                                                               attribute:NSLayoutAttributeTop
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:inner
                                                               attribute:NSLayoutAttributeTop
                                                              multiplier:1.0
                                                                constant:0.0];
    NSLayoutConstraint *leftEdge = [NSLayoutConstraint constraintWithItem:outer
                                                                attribute:NSLayoutAttributeLeft
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:inner
                                                                attribute:NSLayoutAttributeLeft
                                                               multiplier:1.0
                                                                 constant:0.0];
    NSLayoutConstraint *bottomEdge = [NSLayoutConstraint constraintWithItem:outer
                                                                  attribute:NSLayoutAttributeBottom
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:inner
                                                                  attribute:NSLayoutAttributeBottom
                                                                 multiplier:1.0
                                                                   constant:0.0];
    NSLayoutConstraint *widthHalf = [NSLayoutConstraint constraintWithItem:outer
                                                                 attribute:NSLayoutAttributeWidth
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:inner
                                                                 attribute:NSLayoutAttributeWidth multiplier:0.5 constant:0.0];
    return @[topEdge, leftEdge, bottomEdge, widthHalf];
}

static NSArray<NSLayoutConstraint *> *makeRightPageConstraints(UIView *outer, UIView *inner)
{
    NSLayoutConstraint *topEdge = [NSLayoutConstraint constraintWithItem:outer
                                                               attribute:NSLayoutAttributeTop
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:inner
                                                               attribute:NSLayoutAttributeTop
                                                              multiplier:1.0
                                                                constant:0.0];
    NSLayoutConstraint *leftEdge = [NSLayoutConstraint constraintWithItem:outer
                                                                attribute:NSLayoutAttributeRight
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:inner
                                                                attribute:NSLayoutAttributeRight
                                                               multiplier:1.0
                                                                 constant:0.0];
    NSLayoutConstraint *bottomEdge = [NSLayoutConstraint constraintWithItem:outer
                                                                  attribute:NSLayoutAttributeBottom
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:inner
                                                                  attribute:NSLayoutAttributeBottom
                                                                 multiplier:1.0
                                                                   constant:0.0];
    NSLayoutConstraint *widthHalf = [NSLayoutConstraint constraintWithItem:outer
                                                                 attribute:NSLayoutAttributeWidth
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:inner
                                                                 attribute:NSLayoutAttributeWidth multiplier:0.5 constant:0.0];
    return @[topEdge, leftEdge, bottomEdge, widthHalf];
}

@interface ARDKBookModeViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, ARDKBookModePageViewControllerDelegate>
@property(readonly) UITapGestureRecognizer *tapGesture;
@property(readonly) UITapGestureRecognizer *dtapGesture;
@property(readonly) UIPinchGestureRecognizer *pinchGesture;
@property(readonly) UILongPressGestureRecognizer *longPressGesture;
@property(weak) id<ARDKPageControllerDelegate> pageControllerDelegate;
@property UIScrollView *scrollView;
@property UIView *contentView;
@property UIPageViewController *pageViewController;
@property NSLayoutConstraint *aspect;
@property NSLayoutConstraint *contentWidthConstraint;
@property NSLayoutConstraint *contentHeightConstraint;
@property NSArray<NSLayoutConstraint *> *twoUpConstraints;
@property NSArray<NSLayoutConstraint *> *leftPageConstraints;
@property NSArray<NSLayoutConstraint *> *rightPageConstraints;
@property NSArray<NSLayoutConstraint *> *currentConstraints;
@property LayoutType layoutType;
@property NSMutableArray<ARDKBitmap *> *bitmaps;
@property NSMutableDictionary<NSNumber *, ARDKBookModePageViewController *> *pageVCs;
@property CGSize pageSize;
@property BOOL firstRenderHasCompleted;
@property void (^afterFirstRenderBlock)(void);
@end


@implementation ARDKBookModeViewController
{
    NSInteger _pageCount;
    NSInteger _currentPage;
    NSInteger _dummyPage;
    BOOL _showing;
    BOOL _darkMode;
}

@synthesize cellSize, disableScrollOnKeyboardHidden, drawingMode, keyboardShown, longPressEnabled, reflowMode, zoomScale;

- (instancetype)initWithDelegate:(id<ARDKPageControllerDelegate>)delegate
{
    if (self)
    {
        _pageControllerDelegate = delegate;
        _pageViewController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStylePageCurl
                                                              navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                            options:@{UIPageViewControllerOptionSpineLocationKey:@(UIPageViewControllerSpineLocationMid)}];
        _pageViewController.doubleSided = YES;
        _pageViewController.dataSource = self;
        _pageViewController.delegate = self;
        _dummyPage = NO_DUMMY_PAGE;
        _pageVCs = [NSMutableDictionary dictionaryWithCapacity:NUM_PAGES];
        zoomScale = 1.0;
    }
    return self;
}

- (BOOL)darkMode
{
    return _darkMode;
}

- (void)setDarkMode:(BOOL)darkMode
{
    if (_darkMode != darkMode)
    {
        _darkMode = darkMode;
        self.pageControllerDelegate.session.bitmap.darkMode = darkMode;
        for (ARDKBookModePageViewController *pvc in self.pageVCs.allValues)
        {
            ARDKBookModePageView *pv = (ARDKBookModePageView *)pvc.view;
            [pv.pageView onContentChange];
        }

        [self requestRenderWithForce:YES];
    }
}

- (void)ensureBitmaps
{
    if (!_bitmaps)
    {
        CGFloat screenScale = UIScreen.mainScreen.scale;
        CGSize screenSize = UIScreen.mainScreen.bounds.size;
        CGSize size = CGSizeMake(screenSize.width * screenScale / 2, screenSize.height * screenScale);
        if (!self.pageControllerDelegate.session.bitmap)
        {
            self.pageControllerDelegate.session.bitmap = [self.pageControllerDelegate.session.doc bitmapAtSize:CGSizeMake(size.width, size.height * NUM_PAGES)];
        }

        [self.pageControllerDelegate.session.bitmap adjustToWidth:size.width];

        _bitmaps = [NSMutableArray arrayWithCapacity:NUM_PAGES];
        CGRect rect = {CGPointZero, size};
        for (NSInteger i = 0; i < NUM_PAGES; i++)
        {
            [_bitmaps addObject:[ARDKBitmap bitmapFromSubarea:rect ofBitmap:self.pageControllerDelegate.session.bitmap]];
            rect.origin.y += size.height;
        }
    }
}

- (void)ensurePages
{
    NSInteger start = _currentPage - PRE_PAGES;
    NSInteger end = start + NUM_PAGES;
    [self ensureBitmaps];
    NSSet<NSNumber *> *old = [self.pageVCs keysOfEntriesPassingTest:^BOOL(NSNumber * _Nonnull key, ARDKBookModePageViewController * _Nonnull obj, BOOL * _Nonnull stop) {
        NSInteger pageNo = key.integerValue;
        return pageNo < start || pageNo >= end;
    }];

    for (NSNumber *n in old)
    {
        [self.bitmaps addObject:self.pageVCs[n].bitmap];
        [self.pageVCs removeObjectForKey:n];
    }

    for (NSInteger p = start; p < end; p++)
    {
        if (p >= 0 && p < _pageCount && !self.pageVCs[@(p)])
        {
            ARDKBitmap *bitmap = self.bitmaps.lastObject;
            [self.bitmaps removeLastObject];
            ARDKBookModePageViewController *pvc = [[ARDKBookModePageViewController alloc] initForPage:p withBitmap:bitmap andDelegate:self];
            self.pageVCs[@(p)] = pvc;
            ARDKBookModePageView *pv = (ARDKBookModePageView *)pvc.view;
            [pv setPageSize:self.pageSize];
            [_pageControllerDelegate setupPageCell:pv forPage:pv.pageNumber];
            __weak typeof(self) weakSelf = self;
            [pv render:^{
                if (!self.firstRenderHasCompleted)
                {
                    weakSelf.firstRenderHasCompleted = YES;
                    if (self.afterFirstRenderBlock)
                        self.afterFirstRenderBlock();
                }
            }];
            if (_dummyPage == p)
                _dummyPage = NO_DUMMY_PAGE;
        }
    }

    if (_dummyPage != NO_DUMMY_PAGE && _dummyPage < _pageCount && self.pageVCs[@(_dummyPage)])
    {
        ARDKBookModePageView *pv = (ARDKBookModePageView *)self.pageVCs[@(_dummyPage)].view;
        [pv setPageSize:self.pageSize];
        [_pageControllerDelegate setupPageCell:pv forPage:pv.pageNumber];
        [pv render:nil];
    }

    if (_currentPage < _pageCount && !_showing)
    {
        _showing = YES;
        if (_currentPage+1 >= _pageCount)
        {
            // We have to supply pages in pairs, so create an uninitialised one
            ARDKBitmap *bitmap = self.bitmaps.lastObject;
            [self.bitmaps removeLastObject];
            self.pageVCs[@(_currentPage+1)] = [[ARDKBookModePageViewController alloc] initForPage:_currentPage+1 withBitmap:bitmap andDelegate:self];
            _dummyPage = _currentPage+1;
        }

        [_pageViewController setViewControllers:@[self.pageVCs[@(_currentPage)], self.pageVCs[@(_currentPage+1)]]
                                      direction:UIPageViewControllerNavigationDirectionForward
                                       animated:NO
                                     completion:nil];
    }
}

- (NSInteger)pageCount
{
    return _pageCount;
}

- (void)setPageCount:(NSInteger)pageCount
{
    if (pageCount > 0 && !_aspect)
    {
        CGSize size = [self.pageControllerDelegate adjustSize:CGSizeMake(1.0, 1.0) toPage:0];
        _aspect = [NSLayoutConstraint constraintWithItem:_pageViewController.view
                                               attribute:NSLayoutAttributeWidth
                                               relatedBy:NSLayoutRelationEqual
                                                  toItem:_pageViewController.view
                                               attribute:NSLayoutAttributeHeight
                                              multiplier:2*size.width/size.height constant:0.0];
        [self.view addConstraint:_aspect];
    }
    _pageCount = pageCount;
    [self ensurePages];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _pageViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self addChildViewController:_pageViewController];
    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    addSubviewFit(self.view, _scrollView);
    _contentView = [[UIView alloc] initWithFrame:self.view.bounds];
    addSubviewFit(_scrollView, _contentView);
    [_contentView addSubview:_pageViewController.view];
    [_pageViewController didMoveToParentViewController:self];

    _contentWidthConstraint = [NSLayoutConstraint constraintWithItem:self.view
                                                           attribute:NSLayoutAttributeWidth
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:_contentView
                                                           attribute:NSLayoutAttributeWidth
                                                          multiplier:1.0
                                                            constant:0.0];
    _contentHeightConstraint = [NSLayoutConstraint constraintWithItem:self.view
                                                            attribute:NSLayoutAttributeHeight
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:_contentView
                                                            attribute:NSLayoutAttributeHeight
                                                           multiplier:1.0
                                                             constant:0.0];
    [self.view addConstraints:@[_contentWidthConstraint, _contentHeightConstraint]];

    // Add three sets of constraints to the view for the sake of different layouts,
    // but activate only one at a time.
    self.twoUpConstraints = makeTwoUpConstraints(_contentView, _pageViewController.view);
    self.leftPageConstraints = makeLeftPageConstraints(_contentView, _pageViewController.view);
    self.rightPageConstraints = makeRightPageConstraints(_contentView, _pageViewController.view);
    [_contentView addConstraints:self.leftPageConstraints];
    controlConstraints(self.leftPageConstraints, false);
    [_contentView addConstraints:self.rightPageConstraints];
    controlConstraints(self.rightPageConstraints, false);
    [_contentView addConstraints:self.twoUpConstraints];
    self.currentConstraints = self.twoUpConstraints;
    self.layoutType = LayoutType_TwoUp;
    _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [_tapGesture setNumberOfTapsRequired:1];
    _dtapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    [_dtapGesture setNumberOfTapsRequired:2];
    [_tapGesture requireGestureRecognizerToFail:_dtapGesture];
    _longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    _longPressGesture.minimumPressDuration = LONG_PRESS_MIN_DURATION;
    [_tapGesture requireGestureRecognizerToFail:_longPressGesture];
    _pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    [self.view addGestureRecognizer:_tapGesture];
    [self.view addGestureRecognizer:_longPressGesture];
    [self.view addGestureRecognizer:_dtapGesture];
    [self.view addGestureRecognizer:_pinchGesture];
}

- (void)handleTap:(UIGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded)
    {
        [self forCellAtPoint:[gesture locationInView:self.view] do:^(NSInteger index, UIView *cell, CGPoint pt) {
            [self.pageControllerDelegate didTapCell:cell at:pt];
        }];
    }
}

- (void)handleDoubleTap:(UIGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded)
    {
        [self forCellAtPoint:[gesture locationInView:self.view] do:^(NSInteger index, UIView *cell, CGPoint pt) {
            [self.pageControllerDelegate didDoubleTapCell:cell at:pt];
        }];
    }
}

- (void)handleLongPress:(UIGestureRecognizer *)gesture
{
    switch(gesture.state)
    {
        case UIGestureRecognizerStateBegan:
            [self.pageControllerDelegate didStartLongPress];
            break;

        case UIGestureRecognizerStateChanged:
        {
            [self forCellAtPoint:[gesture locationInView:self.view] do:^(NSInteger index, UIView *cell, CGPoint pt) {
                [self.pageControllerDelegate didLongPressMoveInCell:cell at:pt];
            }];
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            [self.pageControllerDelegate didEndLongPress];
            break;

        default:
            break;
    }

}

- (void)handlePinch:(UIPinchGestureRecognizer *)gesture
{
    if (self.layoutType == LayoutType_TwoUp && gesture.scale > 1)
    {
        CGPoint pt = [gesture locationInView:self.view];
        if (pt.x < self.view.bounds.size.width / 2)
        {
            // Remove the contraint that matches the content-view height to
            // the scroll view, so that the book view controls the content height,
            // hence permitting the appropriate amount of scolling.
            self.contentHeightConstraint.active = NO;
            controlConstraints(self.currentConstraints, NO);
            controlConstraints(self.leftPageConstraints, YES);
            self.currentConstraints = self.leftPageConstraints;
            self.layoutType = LayoutType_LeftPage;
            [UIView animateWithDuration:0.3 animations:^{
                [self.view layoutIfNeeded];
            }];
        }
        else
        {
            self.contentHeightConstraint.active = NO;
            controlConstraints(self.currentConstraints, NO);
            controlConstraints(self.rightPageConstraints, YES);
            self.currentConstraints = self.rightPageConstraints;
            self.layoutType = LayoutType_RightPage;
            [UIView animateWithDuration:0.3 animations:^{
                [self.view layoutIfNeeded];
            }];
        }
    }
    else if(self.layoutType != LayoutType_TwoUp && gesture.scale < 1)
    {
        controlConstraints(self.currentConstraints, NO);
        controlConstraints(self.twoUpConstraints, YES);
        self.contentHeightConstraint.active = YES;
        self.currentConstraints = self.twoUpConstraints;
        self.layoutType = LayoutType_TwoUp;
        [UIView animateWithDuration:0.3 animations:^{
            [self.view layoutIfNeeded];
        }];
    }
}

- (void)onPageSizeUpdate:(CGSize)pageSize
{
    cellSize = pageSize;
    if (!CGSizeEqualToSize(pageSize, self.pageSize))
    {
        self.pageSize = pageSize;
        for (id key in self.pageVCs)
        {
            ARDKBookModePageView *pageCell = ((ARDKBookModePageView *)self.pageVCs[key].view);
            [pageCell.pageView useForPageNumber:pageCell.pageNumber withSize:pageSize];
        }

        [self requestRenderWithForce:YES];
    }
}

- (CGAffineTransform)cellToScreen:(NSInteger)pageNo
{
    ARDKBookModePageViewController *pvc= nil;
    for (ARDKBookModePageViewController *x in self.pageViewController.viewControllers)
    {
        if (x.pageNumber == pageNo)
        {
            pvc = x;
            break;
        }
    }

    if (pvc)
    {
        CGRect screenRect = [self.view convertRect:pvc.view.bounds fromView:pvc.view];
        return CGAffineTransformMakeTranslation(screenRect.origin.x, screenRect.origin.y);
    }
    else
    {
        return CGAffineTransformIdentity;
    }
}

- (void)forCellAtPoint:(CGPoint)pt do:(void (^)(NSInteger, UIView *, CGPoint))block
{
    for (ARDKBookModePageViewController *pvc in self.pageViewController.viewControllers)
    {
        ARDKBookModePageView *pv = (ARDKBookModePageView *)pvc.view;
        CGPoint cpt = [self.view convertPoint:pt toView:pv.pageView];
        if (CGRectContainsPoint(pv.pageView.bounds, cpt))
        {
            block(pv.pageNumber, pv.pageView, cpt);
            break;
        }
    }
}

- (void)forCellNearestPoint:(CGPoint)pt do:(void (^)(NSInteger, UIView *))block
{
    __block CGFloat dist = FLT_MAX;
    __block ARDKBookModePageView *nearestPv;
    for (ARDKBookModePageViewController *pvc in self.pageViewController.viewControllers)
    {
        ARDKBookModePageView *pv = (ARDKBookModePageView *) pvc.view;
        CGPoint cpt = [self.view convertPoint:pt toView:pv.pageView];
        CGFloat pdist = ARCGRectDistanceToPoint(self.view.bounds, cpt);
        if (pdist < dist)
        {
            dist = pdist;
            nearestPv = pv;
        }

        if (dist == 0.0)
            break;
    }

    if (nearestPv)
        block(nearestPv.pageNumber, nearestPv.pageView);
}

- (void)forgetShowArea
{

}

- (void)iteratePages:(void (^)(NSInteger, UIView<ARDKPageCellDelegate> *, CGRect))block
{
    for (ARDKBookModePageViewController *pVc in _pageViewController.viewControllers)
    {
        UIView<ARDKPageCellDelegate> *pv = ((ARDKBookModePageView *)pVc.view).pageView;
        CGRect rect = [self.view convertRect:pv.frame fromView:pv];
        block(pVc.pageNumber, pv, rect);
    }
}

- (BOOL)reshowArea
{
    return NO;
}

- (void)setZoomScale:(CGFloat)scale animated:(BOOL)animated
{
}

- (void)showAreas:(NSArray<ARDKPageArea *> *)areas animated:(BOOL)animated onCompletion:(void (^)(void))block
{
}

- (void)showPage:(NSInteger)pageNum animated:(BOOL)animated onCompletion:(void (^)(void))block
{
}

- (void)showPage:(NSInteger)pageNum withOffset:(CGPoint)pt animated:(BOOL)animated
{
}

- (void)updateItemSize
{
}

- (void)afterFirstRender:(void (^)(void))block
{
    _afterFirstRenderBlock = block;
    if (block &&_firstRenderHasCompleted)
        block();
}


- (void)requestRenderWithForce:(BOOL)force
{
    if (force)
    {
        for (id key in self.pageVCs)
        {
            [((ARDKBookModePageView *)self.pageVCs[key].view) render:nil];
        }
    }
}


- (nullable UIViewController *)pageViewController:(nonnull UIPageViewController *)pageViewController viewControllerAfterViewController:(nonnull UIViewController *)viewController
{
    if (drawingMode || self.layoutType != LayoutType_TwoUp)
        return nil;

    NSInteger pageNumber = ((ARDKBookModePageViewController *)viewController).pageNumber;
    ARDKBookModePageViewController *pvc = self.pageVCs[@(pageNumber+1)];
    if (pvc == nil && ((pageNumber+1)&1))
    {
        // We have to give out pages in pairs, so if we've run out on
        // and odd count, produce a dummy
        ARDKBitmap *bitmap = self.bitmaps.lastObject;
        [self.bitmaps removeLastObject];
        pvc = [[ARDKBookModePageViewController alloc] initForPage:pageNumber+1 withBitmap:bitmap andDelegate:self];
        self.pageVCs[@(pageNumber+1)] = pvc;
        _dummyPage = pageNumber+1;
    }

    return pvc;
}

- (nullable UIViewController *)pageViewController:(nonnull UIPageViewController *)pageViewController viewControllerBeforeViewController:(nonnull UIViewController *)viewController
{
    if (drawingMode || self.layoutType != LayoutType_TwoUp)
        return nil;

    NSInteger pageNumber = ((ARDKBookModePageViewController *)viewController).pageNumber;
    return self.pageVCs[@(pageNumber-1)];
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed
{
    _currentPage = ((ARDKBookModePageViewController *)pageViewController.viewControllers[0]).pageNumber;
    [self ensurePages];
    [self.pageControllerDelegate viewHasMoved];
}

@end
