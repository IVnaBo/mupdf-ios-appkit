//
//  ARDKBasicDocumentViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 14/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKGeometry.h"
#import "ARDKLib.h"
#import "ARDKViewingState.h"
#import "ARDKViewRenderer.h"
#import "ARDKPageView.h"
#import "ARDKPageController.h"
#import "ARDKNUpViewController.h"
#import "ARDKBasicDocViewAPI.h"
#import "ARDKBasicDocumentViewController.h"
#import "ARDKBasicDocumentViewProtected.h"

#define SMALL_LENGTH (10.0)

#define BACKGROUND_LUM (0xbc)

@interface ARDKBasicDocumentViewController () <ARDKDocumentEventTarget,ARDKPageControllerDelegate>
@property UIViewController<ARDKPageController> *pageController;
@property BOOL hasBeenLaidOut;
@property BOOL loadingComplete;
@property BOOL firstRenderComplete;
@property ARDKViewingStateStack *viewingStateStack;
@property BOOL viewingStatePageHasLoaded;
@property NSInteger openOnPage;
@property BOOL viewingStatePageIsVisible;
@end

@implementation ARDKBasicDocumentViewController

@synthesize currentPage, pasteboard, delegate = _delegate, doc = _doc, textTypingEnabled;

- (void) onReflowZoom
{
}

- (void)adjustToReducedScreenArea
{
}

- (BOOL)disableScrollOnKeyboardHidden
{
    return self.pageController.disableScrollOnKeyboardHidden;
}

- (void)setDisableScrollOnKeyboardHidden:(BOOL)disableScrollOnKeyboardHidden
{
    self.pageController.disableScrollOnKeyboardHidden = disableScrollOnKeyboardHidden;
}

- (BOOL)drawingMode
{
    return self.pageController.drawingMode;
}

- (void)setDrawingMode:(BOOL)drawingMode
{
    self.pageController.drawingMode = drawingMode;
}

- (BOOL)reflowMode
{
    return self.pageController.reflowMode;
}

- (void)setReflowMode:(BOOL)reflowMode
{
    self.pageController.reflowMode = reflowMode;
}

- (CGFloat)zoomScale
{
    return self.pageController.zoomScale;
}

- (void)setZoomScale:(CGFloat)scale animated:(BOOL)animated
{
    [self.pageController setZoomScale:scale animated:animated];
}

- (BOOL)longPressEnabled
{
    return self.pageController.longPressEnabled;
}

- (void)setLongPressEnabled:(BOOL)longPressEnabled
{
    self.pageController.longPressEnabled = longPressEnabled;
}

// Use the rendering bitmaps cached in the session
- (ARDKBitmap *)bitmap
{
    return self.session.bitmap;
}

- (void)setBitmap:(ARDKBitmap *)bitmap
{
    self.session.bitmap = bitmap;
}

- (instancetype)initForSession:(ARDKDocSession *)session
{
    self = [super initWithNibName:nil bundle:[NSBundle bundleForClass:self.class]];
    if (self)
    {
        _session = session;
        _doc = session.doc;

        if (![session.fileState.viewingStateInfo isKindOfClass:ARDKViewingStateStack.class])
            session.fileState.viewingStateInfo = [ARDKViewingStateStack viewingStateStack];

        self.viewingStateStack = (ARDKViewingStateStack *)session.fileState.viewingStateInfo;
        self.openOnPage = self.viewingStateStack.viewingState.page;
        self.viewingStatePageHasLoaded = NO;
        
        self.view.backgroundColor = [UIColor colorWithWhite:BACKGROUND_LUM/255.0 alpha:1.0];
        self.pageController = [[ARDKNUpViewController alloc] init];
        self.pageController.delagate = self;
        [self addChildViewController:self.pageController];
        [self.view addSubview:self.pageController.view];
        [self.view sendSubviewToBack:self.pageController.view];
        [self.pageController didMoveToParentViewController:self];
    }
    return self;
}

/// Override: adjust a rectangle to fit a specified page
- (CGSize)adjustSize:(CGSize)size toPage:(NSInteger)page
{
    return [ARDKPageView adjustSize:size toPage:[self.doc getPage:page update:nil]];
}

- (void)updatePageCount:(NSInteger)pageCount andLoadingComplete:(BOOL)complete
{
    [self setPageCount:pageCount];

    if (complete && !self.loadingComplete)
    {
        self.loadingComplete = YES;

        if(self.firstRenderComplete)
            [self.delegate loadingAndFirstRenderComplete];
    }

    self.loadingComplete = complete;
}

- (void)setPageCount:(NSInteger)pageCount
{
    [self.pageController setPageCount:pageCount];
    if (self.hasBeenLaidOut && !self.viewingStatePageHasLoaded && self.openOnPage < pageCount)
    {
        ARDKViewingState *vs = self.viewingStateStack.viewingState;
        if (vs.page != 0 || CGPointEqualToPoint(vs.offset, CGPointZero))
        {
            [self setZoomScale:vs.scale animated:NO];
            [self showPage:vs.page withOffset:vs.offset animated:NO];
        }
        self.viewingStatePageHasLoaded = YES;
    }
}

- (void)pageSizeHasChanged
{
}

- (void)selectionHasChanged
{
}

- (void)layoutHasCompleted
{
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGRect frame = {CGPointZero, self.view.frame.size};
    self.pageController.view.frame = frame;
}

- (void)updateDarkMode
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (self.session.docSettings.contentDarkModeEnabled)
    {
        if ( @available(iOS 13.0, *) )
        {
            self.pageController.darkMode = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
        }
    }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 */
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    self.hasBeenLaidOut = YES;
    if (!self.viewingStatePageHasLoaded && self.openOnPage < self.pageController.pageCount)
    {
        ARDKViewingState *vs = self.viewingStateStack.viewingState;
        if (vs.page != 0 || CGPointEqualToPoint(vs.offset, CGPointZero))
            [self showPage:vs.page withOffset:vs.offset animated:NO];
        self.viewingStatePageHasLoaded = YES;
    }
    [self updateDarkMode];

    __weak typeof(self) weakSelf = self;
    [self.pageController afterFirstRender:^{
        weakSelf.firstRenderComplete = YES;
        if (weakSelf.loadingComplete)
            [weakSelf.delegate loadingAndFirstRenderComplete];
    }];
    [self viewHasAltered:YES];
    [self.doc addTarget:self];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self syncViewingState];
    self.session.fileState.viewingStateInfo = self.viewingStateStack;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if ( @available(iOS 13.0, *) )
    {
        BOOL hasUserInterfaceStyleChanged = [previousTraitCollection hasDifferentColorAppearanceComparedToTraitCollection:self.traitCollection];

        if (hasUserInterfaceStyleChanged)
        {
            [self updateDarkMode];
        }
    }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 */
}

- (void)setupPageCell:(id<ARDKPageCell>)pageCell forPage:(NSInteger)page
{
    // Should never be called
    assert(NO);
}

- (CGAffineTransform)pageToCell:(NSInteger)pageNo
{
    CGRect cellFrame = {CGPointZero, self.pageController.cellSize};
    id<ARDKPage> page = [self.doc getPage:pageNo update:nil];
    // Because of the asynchrony within the office document render library, it's very difficult
    // to ensure this method is never called for a page that no longer exists. In that case, to
    // avoid calculations that produce NaN, we return the identity transform. The situations are
    // transatory and any incorrect actions based on the transform are subsequently corrected.
    return page ? [ARDKPageView transformForPage:page withinFrame:cellFrame] : CGAffineTransformIdentity;
}

- (CGAffineTransform)pageToScreen:(NSInteger)pageNo
{
    return CGAffineTransformConcat([self pageToCell:pageNo], [self.pageController cellToScreen:pageNo]);
}

- (CGRect)screenAreaForPage:(NSInteger)pageNo
{
    CGRect pageRect = {CGPointZero, [self.doc getPage:pageNo update:nil].size};
    return CGRectApplyAffineTransform(pageRect, [self pageToScreen:pageNo]);
}

- (CGAffineTransform)screenToPage:(NSInteger)pageNo
{
    return CGAffineTransformInvert([self pageToScreen:pageNo]);
}

- (ARDKViewingState *)screenPtToViewingState:(CGPoint) pt
{
    __block ARDKViewingState *viewState = nil;

    [self forCellNearestPoint:pt do:^(NSInteger index, UIView *cell) {
        viewState = [ARDKViewingState stateWithPage:index offset:CGPointApplyAffineTransform(pt, [self screenToPage:index]) scale:self.zoomScale];
    }];

    return viewState;
}

- (void)showArea:(CGRect)box onPage:(NSInteger)pageNum
{
    [self showArea:box onPage:pageNum animated:YES onCompletion:nil];
}

- (void)showArea:(CGRect)box onPage:(NSInteger)pageNum animated:(BOOL)animated onCompletion:(void (^)(void))block
{
    [self showAreas:@[[ARDKPageArea area:box onPage:pageNum]] animated:animated onCompletion:block];
}

- (void)showAreas:(NSArray<ARDKPageArea *> *)areas animated:(BOOL)animated onCompletion:(void (^)(void))block
{
    NSMutableArray<ARDKPageArea *> *careas = [NSMutableArray arrayWithCapacity:areas.count];

    for (ARDKPageArea *area in areas)
    {
        [careas addObject:[ARDKPageArea area:CGRectApplyAffineTransform(area.area, [self pageToCell:area.pageNumber]) onPage:area.pageNumber]];
    }

    [self.pageController showAreas:careas animated:animated onCompletion:block];
}

- (void)showAreas:(NSArray<ARDKPageArea *> *)areas
{
    [self showAreas:areas animated:YES onCompletion:nil];
}

- (void)showEndOfPage:(NSInteger)pageNum
{
    CGSize pageSize = [self.doc getPage:pageNum update:nil].size;
    CGRect target = CGRectMake(0, pageSize.height - SMALL_LENGTH, SMALL_LENGTH, SMALL_LENGTH);
    [self showArea:target onPage:pageNum];
}

- (void)showPage:(NSInteger)pageNum
{
    [self showPage:pageNum animated:YES];
}

- (void)showPage:(NSInteger)pageNum animated:(BOOL)animated
{
    [self showPage:pageNum animated:animated onCompletion:nil];
}

- (void)showPage:(NSInteger)pageNum withOffset:(CGPoint)pt animated:(BOOL)animated
{
    [self.pageController showPage:pageNum withOffset:CGPointApplyAffineTransform(pt, [self pageToCell:pageNum]) animated:animated];
}

- (void)showPage:(NSInteger)pageNum withOffset:(CGPoint)pt
{
    [self showPage:pageNum withOffset:pt animated:YES];
}

- (void)viewHasMoved
{
    CGPoint pt = CGPointMake(self.view.frame.size.width/2.0, self.view.frame.size.height/2.0);
    [self forCellNearestPoint:pt do:^(NSInteger index, UIView *cell) {
        if (index != self.currentPage)
        {
            self->currentPage = index;
            [self.delegate viewDidScrollToPage:index];
        }
    }];

    // Ensure we keep the link-nav next button correctly enabled as the user scrolls by
    // updating viewingStatePageIsVisible.
    if (self.viewingStatePageHasLoaded)
    {
        NSInteger viewingStatePage = self.viewingStateStack.viewingState.page;
        BOOL viewingStatePageIsVisible = CGRectIntersectsRect(self.view.bounds, [self screenAreaForPage:viewingStatePage]);
        if (viewingStatePageIsVisible != self.viewingStatePageIsVisible)
        {
            self.viewingStatePageIsVisible = viewingStatePageIsVisible;
            [self.delegate updateUI];
        }

        // While the viewint state page is visible keep the zoom scale up to date
        if (viewingStatePageIsVisible)
            self.viewingStateStack.viewingState.scale = self.zoomScale;
    }
}

/// Override: react to movement and page count updates
- (void)viewHasAltered:(BOOL)forceRender
{
    [self.pageController requestRenderWithForce:forceRender];
    [self viewHasMoved];
}

- (void)didDoubleTapCell:(UIView *)cell at:(CGPoint)point
{
}


- (void)didDragDocument
{
}


- (void)didEndLongPress
{
}


- (void)didLongPressMoveInCell:(UIView *)cell at:(CGPoint)point
{
}


- (void)didStartLongPress
{
}


- (void)didTapCell:(UIView *)cell at:(CGPoint)point
{
}


- (BOOL)hasKeyboard
{
    return self.pageController.keyboardShown;
}

- (void)syncViewingState
{
    // Push a new viewing state if the user has scrolled the current viewing-state page off screen
    if (self.viewingStatePageHasLoaded)
    {
        NSInteger viewingStatePage = self.viewingStateStack.viewingState.page;
        if (!CGRectIntersectsRect(self.view.bounds, [self screenAreaForPage:viewingStatePage]))
        {
            [self.viewingStateStack push:[self screenPtToViewingState:CGPointZero]];
            [self.delegate updateUI];
        }
    }
}

- (BOOL)viewingStatePreviousAllowed
{
    return _viewingStateStack.previousAllowed;
}

- (BOOL)viewingStateNextAllowed
{
    // If the user has scrolled the current viewing-state page off
    // screen since the last viewing-state operation then
    // that is in-effect a push of a new position which
    // overrides any existing next state. The push is performed lazily,
    // but we need to ensure the UI reflects that next is disallowed.
    // If they scroll back to the view-state page then next will become
    // enabled again, which is slightly odd, but reasonable, I think.
    return _viewingStatePageIsVisible && _viewingStateStack.nextAllowed;
}

- (void)viewingStatePrevious
{
    [self syncViewingState];
    [_viewingStateStack previous];
    ARDKViewingState *vs = _viewingStateStack.viewingState;
    [self setZoomScale:vs.scale animated:NO];
    [self showPage:vs.page withOffset:vs.offset animated:NO];
    [_delegate updateUI];
}

- (void)viewingStateNext
{
    [self syncViewingState];
    [_viewingStateStack next];
    ARDKViewingState *vs = _viewingStateStack.viewingState;
    [self setZoomScale:vs.scale animated:NO];
    [self showPage:vs.page withOffset:vs.offset animated:NO];
    [_delegate updateUI];
}

- (void)pushViewingState:(NSInteger)page withOffset:(CGPoint)offset
{
    [self syncViewingState];
    [_viewingStateStack push:page offset:offset scale:self.zoomScale];
    [_delegate updateUI];
}

- (void)resetTextInput
{
}

- (void)forCellAtPoint:(CGPoint)pt do:(void (^)(NSInteger, UIView *, CGPoint))block
{
    [self.pageController forCellAtPoint:pt do:block];
}


- (void)forCellNearestPoint:(CGPoint)pt do:(void (^)(NSInteger, UIView *))block
{
    [self.pageController forCellNearestPoint:pt do:block];
}


- (void)showPage:(NSInteger)pageNum animated:(BOOL)animated onCompletion:(void (^)(void))block
{
    [self.pageController showPage:pageNum animated:animated onCompletion:block];
}

- (void)forgetShowArea
{
    [self.pageController forgetShowArea];
}

- (BOOL)reshowArea
{
    return [self.pageController reshowArea];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self.delegate scrollViewDidEndScrollingAnimation];
}

- (void)iteratePages:(void (^)(NSInteger, UIView<ARDKPageCellDelegate> *, CGRect))block
{
    [self.pageController iteratePages:block];
}

- (void)updateItemSize
{
    [self.pageController updateItemSize];
}

@end
