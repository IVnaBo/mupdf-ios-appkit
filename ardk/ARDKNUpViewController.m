//
//  ARDKNUpViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 30/03/2015.
//  Copyright (c) 2015 Artifex Software Inc. All rights reserved.
//

#import "ARDKGeometry.h"
#import "ARDKNUpLayout.h"
#import "ARDKCollectionViewCell.h"
#import "ARDKNUpViewController.h"

#define MIN_ZOOM (1.0)
#define MAX_ZOOM (5.0)

#define LONG_PRESS_ZOOM_FACTOR (2.0)
#define LONG_PRESS_MIN_DURATION (0.3)

#define SCROLL_DURATION (0.3)

@interface ARDKNUpViewController () <UICollectionViewDataSource,UIScrollViewDelegate,UICollectionViewDelegate>
@property(readonly) UITapGestureRecognizer *tapGesture;
@property(readonly) UITapGestureRecognizer *dtapGesture;
@property(readonly) UILongPressGestureRecognizer *longPressGesture;
@property UICollectionView *collectionView;
@property UIScrollView *scrollView;
@property NSInteger collectionViewPageCount;
@property BOOL animating;
@property BOOL longPressZoomActive;
@property CGRect preZoomContentRect;
@property BOOL renderDisabledDuringZoom;
@property BOOL respondingToScrollViewDidScroll;
@property CGFloat keyboardHeightAboveBottom;
@property CGRect showAreaBox;
@end

@implementation ARDKNUpViewController
{
    CGFloat _width;
    CGFloat _height;
    NSInteger _pageCount;
    BOOL _disableScrollOnKeyboardHidden;
    BOOL _keyboardHiddenWhileScrollDisabled;
    BOOL _keyboardShown;
    BOOL _drawingMode;
}

@synthesize delagate, reflowMode;

- (instancetype)init
{
    return [super initWithNibName:nil bundle:[NSBundle bundleForClass:self.class]];
}

- (BOOL)longPressEnabled
{
    return self.longPressGesture.enabled;
}

- (void)setLongPressEnabled:(BOOL)longPressEnabled
{
    self.longPressGesture.enabled = longPressEnabled;
}

- (NSInteger)pageCount
{
    return _pageCount;
}

- (void)setPageCount:(NSInteger)pageCount
{
    _pageCount = pageCount;
    [self updateCollectionViewPageCount];
}

- (void)updateItemSize
{
    ARDKNUpLayout *layout = (ARDKNUpLayout *)self.collectionView.collectionViewLayout;
    layout.cellSize = [self.delagate adjustSize:CGSizeMake(_width, _width) toPage:0];
    // Update the positions of existing cells straight away rather than waiting
    // for the invalidation of the layout to do it
    [self iteratePages:^(NSInteger i, UIView<ARDKPageCellDelegate> *pageView, CGRect screenRect) {
        [pageView useForPageNumber:i withSize:[layout pageFrame:i].size];
    }];
    [self updateCollectionViewSize:layout];
}

- (void)updateCollectionViewPageCount
{
    ARDKNUpLayout *layout = (ARDKNUpLayout *)self.collectionView.collectionViewLayout;

    if (self.pageCount > 0 && self.collectionViewPageCount == 0 && _width > 0)
        layout.cellSize = [self.delagate adjustSize:CGSizeMake(_width, _width) toPage:0];

    NSMutableArray *array = [NSMutableArray array];

    if (self.pageCount > self.collectionViewPageCount)
    {
        for (NSInteger i = self.collectionViewPageCount; i < self.pageCount; i++)
            [array addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        self.collectionViewPageCount = self.pageCount;
        [self.collectionView insertItemsAtIndexPaths:array];
        layout.pageCount = self.pageCount;
        [self updateCollectionViewSize:layout];
    }
    else if (self.pageCount < self.collectionViewPageCount)
    {
        for (NSInteger i = self.pageCount; i < self.collectionViewPageCount; i++)
            [array addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        self.collectionViewPageCount = self.pageCount;
        layout.pageCount = self.pageCount;
        [self.collectionView deleteItemsAtIndexPaths:array];
        [self updateCollectionViewSize:layout];
    }

    // The minimum zoom depends on the number of pages
    self.scrollView.minimumZoomScale = layout.minZoom;
}

- (CGFloat)zoomScale
{
    return self.scrollView.zoomScale;
}

- (void)setZoomScale:(CGFloat)zoomScale animated:(BOOL)animated
{
    [self.scrollView setZoomScale:zoomScale animated:animated];
}

- (CGPoint)contentOffset
{
    return self.scrollView.contentOffset;
}

- (CGSize)contentSize
{
    return self.scrollView.contentSize;
}

- (CGSize)cellSize
{
    return ((ARDKNUpLayout *)self.collectionView.collectionViewLayout).cellSize;
}

- (CGRect)frameForPage:(NSInteger)page
{
    return [(ARDKNUpLayout *)self.collectionView.collectionViewLayout pageFrame:page];
}

- (CGAffineTransform)cellToScreen:(NSInteger)cellNo
{
    CGRect cellFrame = [self frameForPage:cellNo];
    return CGAffineTransformTranslate(CGAffineTransformScale(CGAffineTransformMakeTranslation(-self.contentOffset.x, -self.contentOffset.y),
                                                             self.zoomScale, self.zoomScale),
                                      cellFrame.origin.x, cellFrame.origin.y);
}

- (void)iteratePages:(void (^)(NSInteger, UIView<ARDKPageCellDelegate> *, CGRect))block
{
    for (UICollectionViewCell<ARDKPageCell> *cell in self.collectionView.visibleCells)
    {
        // Calculate the area of our view that this page covers
        CGRect rect = CGRectOffset(ARCGRectScale(cell.frame, self.zoomScale),
                                   -self.contentOffset.x,
                                   -self.contentOffset.y);

        block([self.collectionView indexPathForCell:cell].item, cell.pageView, rect);
    }
}

- (void)loadView
{
    // Collection views can animate between different layouts,
    // so are ideal for nup animations, but they cannot be set
    // up to zoom their entire contents. To get around that, we
    // put a collection view in a scroll view, with the collection
    // view sized to encompass the entire contents. The scroll view
    // can then pan and zoom the collection view.
    [super loadView];
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.delegate = self;
    self.scrollView.minimumZoomScale = MIN_ZOOM;
    self.scrollView.maximumZoomScale = MAX_ZOOM;

    [self.view addSubview:self.scrollView];
    ARDKNUpLayout *layout = [[ARDKNUpLayout alloc] init];
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.scrollEnabled = NO;
    [self.collectionView registerClass:ARDKCollectionViewCell.class forCellWithReuseIdentifier:@"Page"];
    [self.scrollView addSubview:self.collectionView];
    _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [_tapGesture setNumberOfTapsRequired:1];
    [self.collectionView addGestureRecognizer:_tapGesture];
    _dtapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    [_dtapGesture setNumberOfTapsRequired:2];
    [_tapGesture requireGestureRecognizerToFail:_dtapGesture];
    _longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    _longPressGesture.minimumPressDuration = LONG_PRESS_MIN_DURATION;
    [_tapGesture requireGestureRecognizerToFail:_longPressGesture];
    [self.collectionView addGestureRecognizer:_longPressGesture];
    [self.collectionView addGestureRecognizer:_dtapGesture];
    self.showAreaBox = CGRectNull;
}

- (BOOL)drawingMode
{
    return _drawingMode;
}

- (void)setDrawingMode:(BOOL)drawingMode
{
    _drawingMode = drawingMode;
    self.scrollView.panGestureRecognizer.minimumNumberOfTouches = drawingMode ? 2 : 1;
    self.scrollView.delaysContentTouches = drawingMode;

    _tapGesture.enabled = !drawingMode;
    _dtapGesture.enabled = !drawingMode;
}

- (void)forCellAtPoint:(CGPoint)pt do:(void (^)(NSInteger index, UIView *, CGPoint))block
{
    CGPoint cvPt = [self.view convertPoint:pt toView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:cvPt];
    ARDKCollectionViewCell *cell = (ARDKCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
    if (cell)
    {
        CGPoint cellPoint = [cell.pageView convertPoint:pt fromView:self.view];
        block(indexPath.item, cell.pageView, cellPoint);
    }
}

- (void)forCellNearestPoint:(CGPoint)pt do:(void (^)(NSInteger, UIView *))block
{
    __block CGFloat dist = FLT_MAX;
    __block ARDKCollectionViewCell *nearestCell = nil;
    __block NSInteger index;
    [[self.collectionView indexPathsForVisibleItems] enumerateObjectsUsingBlock:^(NSIndexPath *obj, NSUInteger idx, BOOL *stop) {
        ARDKCollectionViewCell *cell = (ARDKCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:obj];
        CGRect frame = CGRectOffset(ARCGRectScale(cell.frame, self.zoomScale), -self.contentOffset.x, -self.contentOffset.y);
        CGFloat dx, dy;
        if (pt.x < frame.origin.x)
            dx = frame.origin.x - pt.x;
        else if (pt.x > frame.origin.x + frame.size.width)
            dx = pt.x - frame.origin.x - frame.size.width;
        else
            dx = 0.0;

        if (pt.y < frame.origin.y)
            dy = frame.origin.y - pt.y;
        else if (pt.y > frame.origin.y + frame.size.height)
            dy = pt.y - frame.origin.y - frame.size.height;
        else
            dy = 0.0;

        CGFloat d = fmax(dx, dy);
        if (d < dist)
        {
            dist = d;
            nearestCell = cell;
            index = obj.item;

            if (d == 0.0)
                *stop = YES;
        }
    }];

    if (nearestCell)
        block(index, nearestCell.pageView);
}

- (void)handleTap:(UIGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded)
    {
        [self forCellAtPoint:[gesture locationInView:self.view] do:^(NSInteger index, UIView *cell, CGPoint pt) {
            [self.delagate didTapCell:cell at:pt];
        }];
    }
}

- (void)handleDoubleTap:(UIGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded)
    {
        [self forCellAtPoint:[gesture locationInView:self.view] do:^(NSInteger index, UIView *cell, CGPoint pt) {
            [self.delagate didDoubleTapCell:cell at:pt];
        }];
    }
}

- (void)handleLongPress:(UIGestureRecognizer *)gesture
{
    switch(gesture.state)
    {
        case UIGestureRecognizerStateBegan:
            self.longPressZoomActive = YES;
            [self.delagate didStartLongPress];
            // Fallthrough

        case UIGestureRecognizerStateChanged:
        {
            [self forCellAtPoint:[gesture locationInView:self.view] do:^(NSInteger index, UIView *cell, CGPoint pt) {
                [self.delagate didLongPressMoveInCell:cell at:pt];
            }];
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            // When the user releases long press, we zoom back to the previous state
            self.longPressZoomActive = NO;
            [self.delagate viewHasAltered:NO];
            [self.delagate didEndLongPress];
            break;
        default:
            break;
    }
}

- (void)showArea:(CGRect)area animated:(BOOL)animated onCompletion:(void (^)(void))block
{
    self.showAreaBox = area;
    // Expand the area to at least half screen to push the selection away from the screen edges
    area = ARCGRectScale(area, self.scrollView.zoomScale);
    CGFloat width = self.scrollView.bounds.size.width - self.scrollView.contentInset.left - self.scrollView.contentInset.right;
    CGFloat height = self.scrollView.bounds.size.height - self.scrollView.contentInset.top - self.scrollView.contentInset.bottom;
    CGSize size = CGSizeMake(MAX(area.size.width,width/2),MAX(area.size.height, height/2));
    area = ARCGRectAdjustSizeAboutCenter(area, size);
    //Restrict the size to the screen so that we always view the top left of the area
    area.size = CGSizeMake(MIN(area.size.width, width), MIN(area.size.height, height));
    if (animated)
    {
        [UIView animateWithDuration:SCROLL_DURATION animations:^{
            [self.scrollView scrollRectToVisible:area animated:NO];
        } completion:^(BOOL finished) {
            if (block)
                block();
        }];
    }
    else
    {
        [self.scrollView scrollRectToVisible:area animated:NO];
        if (block)
            block();
    }
}

- (void)showAreas:(NSArray<ARDKPageArea *> *)areas animated:(BOOL)animated onCompletion:(void (^)(void))block
{
    assert(areas.count > 0);
    CGRect docRect = CGRectNull;

    for (ARDKPageArea *parea in areas)
    {
        CGRect frame = [self frameForPage:parea.pageNumber];
        docRect = CGRectUnion(docRect, CGRectOffset(parea.area, frame.origin.x, frame.origin.y));
    }

    [self showArea:docRect animated:animated onCompletion:block];
}

- (void)forgetShowArea
{
    self.showAreaBox = CGRectNull;
}

- (BOOL)reshowArea
{
    if (CGRectIsNull(self.showAreaBox))
    {
        return NO;
    }
    else
    {
        [self showArea:self.showAreaBox animated:YES onCompletion:nil];
        return YES;
    }
}

- (void)showPage:(NSInteger)pageIndex animated:(BOOL)animated onCompletion:(void (^)(void))block
{
    // Expand the area to at least the screen to make the selection appear centrally
    CGRect area = ARCGRectScale([self frameForPage:pageIndex], self.scrollView.zoomScale);
    CGFloat width = self.scrollView.bounds.size.width - self.scrollView.contentInset.left - self.scrollView.contentInset.right;
    CGFloat height = self.scrollView.bounds.size.height - self.scrollView.contentInset.top - self.scrollView.contentInset.bottom;
    CGSize size = CGSizeMake(MAX(area.size.width,width),MAX(area.size.height, height));
    area = ARCGRectAdjustSizeAboutCenter(area, size);
    //Restrict the size to the screen so that we always view the top left of the area
    area.size = CGSizeMake(MIN(area.size.width, width), MIN(area.size.height, height));
    if (animated)
    {
        [UIView animateWithDuration:SCROLL_DURATION animations:^{
            [self.scrollView scrollRectToVisible:area animated:NO];
        } completion:^(BOOL finished) {
            if (block)
                block();
        }];
    }
    else
    {
        [self.scrollView scrollRectToVisible:area animated:NO];
        if (block)
            block();
    }
}

- (void)scrollToPosition:(CGPoint)pt animated:(BOOL)animated
{
    CGRect area;
    area.origin = ARCGPointScale(pt, self.zoomScale);
    area.size = self.scrollView.bounds.size;
    [self.scrollView scrollRectToVisible:area animated:animated];
}

- (void)showPage:(NSInteger)pageIndex withOffset:(CGPoint)pt animated:(BOOL)animated
{
    CGRect frame = [self frameForPage:pageIndex];
    [self scrollToPosition:CGPointMake(pt.x + frame.origin.x, pt.y + frame.origin.y) animated:animated];
}

- (void)informLayoutOfViewedArea
{
    // We are using the collection view in an unusual way, sized
    // to encompass the entire contents. Because of that it will
    // ask layout for pages to fill the entire area. To work around
    // that we repeatedly inform layout of the actual area viewed
    // so that it can return only appropriate pages.
    CGRect rect = self.scrollView.bounds;
    if (CGRectIsEmpty(rect))
        return; // Short circuit if the scrollView size is yet to be initialized

    rect.origin = self.scrollView.contentOffset;
    ARDKNUpLayout *layout = (ARDKNUpLayout *)self.collectionView.collectionViewLayout;
    layout.viewedArea = ARCGRectScale(rect, 1/self.scrollView.zoomScale);

    NSInteger suggestedNup = self.reflowMode ? 1 : layout.suggestedNup;
    if (suggestedNup != layout.nup && !self.animating)
    {
        ARDKNUpLayout *newLayout = [[ARDKNUpLayout alloc] init];
        newLayout.nup = suggestedNup;
        newLayout.pageCount = layout.pageCount;
        newLayout.viewWidth = layout.viewWidth;
        newLayout.cellSize = layout.cellSize;
        newLayout.viewedArea = layout.viewedArea;

        [newLayout prepareLayout];

        // Tell the new layout to show the same pages currently showed
        // by the old one, until it's view area gets set
        [newLayout viewPages:layout.viewedPages];

        // Set the collection view frame to the new size before
        // making the transition
        [self updateCollectionViewSize:newLayout];

        self.animating = YES;
        __weak typeof(self) weakSelf = self;
        [self.collectionView setCollectionViewLayout:newLayout animated:YES completion:^(BOOL finished) {
            weakSelf.animating = NO;

            if (!weakSelf.scrollView.zooming)
                [weakSelf snapZoom];
        }];
    }
}

- (void)updateCollectionViewSize:(UICollectionViewLayout *)layout
{
    CGRect rect = CGRectZero;
    [layout prepareLayout];
    rect.size = [layout collectionViewContentSize];
    rect = ARCGRectScale(rect, self.scrollView.zoomScale);
    self.collectionView.frame = rect;
    CGPoint off = self.scrollView.contentOffset;
    // Invalidate the layout before changing the content size. This stops the pages
    // flashing. No idea why they were flashing or why this fixes it.
    [layout invalidateLayout];
    self.scrollView.contentSize = rect.size;
    self.scrollView.contentOffset = off;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delagate viewHasAltered:YES];
    });
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    if (_width != self.view.bounds.size.width || _height != self.view.bounds.size.height)
    {
        CGPoint newContentOffset = CGPointZero;
        if (_width > 0.0)
        {
            // Update the offset to the same proportion as the change in width, ensuring
            // that the same part of the document is displayed.
            CGFloat expansion = self.view.bounds.size.width / _width;
            newContentOffset = ARCGPointScale(self.scrollView.contentOffset, expansion);
            if (!CGRectIsNull(self.showAreaBox))
                self.showAreaBox = ARCGRectScale(self.showAreaBox, expansion);
        }

        _width = self.view.bounds.size.width;
        _height = self.view.bounds.size.height;
        self.scrollView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
        ARDKNUpLayout *layout = (ARDKNUpLayout *)self.collectionView.collectionViewLayout;
        layout.viewWidth = _width;
        layout.cellSize =  self.pageCount > 0 ? [self.delagate adjustSize:CGSizeMake(_width, _width) toPage:0]
                                              : CGSizeMake(_width, (int)(_width * 1.5));
        [self updateCollectionViewSize:layout];
        self.scrollView.minimumZoomScale = ((ARDKNUpLayout *)self.collectionView.collectionViewLayout).minZoom;
        [self informLayoutOfViewedArea];
        self.scrollView.contentOffset = newContentOffset;
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.dragging)
        [self.delagate didDragDocument];

    if (!self.respondingToScrollViewDidScroll)
    {
        self.respondingToScrollViewDidScroll = YES;
        if (!self.longPressZoomActive)
        {
            [self informLayoutOfViewedArea];
        }

        if (!self.renderDisabledDuringZoom)
        {
            [self.delagate viewHasAltered:NO];
        }

        self.respondingToScrollViewDidScroll = NO;
    }
}

- (void)snapZoom
{
    CGFloat currentZoom = self.scrollView.zoomScale;
    if (!self.longPressZoomActive && currentZoom <= 1.0)
    {
        CGFloat fitZoom = ((ARDKNUpLayout *)self.collectionView.collectionViewLayout).fitZoom;
        // Snap to fitZoom or 1.0 whichever is closer to the current zoom. We compare the two
        // ratios currentZoom/1.0 and currentZoom/fitZoom and find the nearest mulitplicively
        // to 1.0. a/b and b/a are equally close to 1.0. Use the minimum of those two representations
        // for each ratio and find the maximum value amongst the ratios. We already know that
        // currentZoom/1.0 is smaller than 1.0/currentZoom
        CGFloat newZoom = (currentZoom > MIN(fitZoom/currentZoom, currentZoom/fitZoom)) ? 1.0 : fitZoom;

        [self.scrollView setZoomScale:newZoom];
    }
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    // When the width of the content is smaller than the view, adjust the insets
    // to centralize it. Leave the top and bottom unchanged because the bottom
    // is adjusted to accomodate the keyboard.
    CGFloat margin = MAX((self.scrollView.bounds.size.width - self.scrollView.contentSize.width) / 2.0, 0);
    UIEdgeInsets insets = self.scrollView.contentInset;
    insets.left = insets.right = margin;
    self.scrollView.contentInset = insets;
    [self.delagate viewHasAltered:NO];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale
{
    if (self.reflowMode)
    {
        if (!self.longPressZoomActive)
            [self.delagate onReflowZoom];
    }
    else
    {
        [self snapZoom];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.collectionView;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.collectionViewPageCount;
}

- (UIView *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ARDKCollectionViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"Page" forIndexPath:indexPath];
    [self.delagate setupPageCell:cell forPage:indexPath.item];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delagate viewHasAltered:YES];
    });

    return cell;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Prevent selection of the items
    return NO;
}

- (void)keyboardWillBeShown:(NSNotification *)notification
{
    _keyboardShown = YES;

    CGRect kbdFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // Adjust the bottom insets to match the height of the keyboard within our view
    CGRect viewRelFrame = [self.view convertRect:kbdFrame fromView:self.view.window];
    CGFloat heightAboveBottom = self.view.frame.size.height - viewRelFrame.origin.y;
    if (heightAboveBottom != self.keyboardHeightAboveBottom)
    {
        UIEdgeInsets insets = self.scrollView.contentInset;
        insets.bottom = heightAboveBottom;
        self.scrollView.contentInset = insets;
        // Don't change left and right insets for the scroll indicator
        // otherwise it'll hang in the middle of the screen
        insets.left = insets.right = 0;
        self.scrollView.scrollIndicatorInsets = insets;
    }
    if (!self.longPressZoomActive && heightAboveBottom > self.keyboardHeightAboveBottom)
        [self.delagate adjustToReducedScreenArea];
    self.keyboardHeightAboveBottom = heightAboveBottom;
    _keyboardHiddenWhileScrollDisabled = NO;
}

- (BOOL)keyboardShown
{
    return _keyboardShown;
}

- (void)reactToKeyboardHidden
{
    UIEdgeInsets insets = self.scrollView.contentInset;
    insets.bottom = 0;
    self.scrollView.contentInset = insets;
    // Don't change left and right insets for the scroll indicator
    // otherwise it'll hang in the middle of the screen
    insets.left = insets.right = 0;
    self.scrollView.scrollIndicatorInsets = insets;
    self.keyboardHeightAboveBottom = 0;
}

- (void)keyboardWasHidden:(NSNotification *)notification
{
    _keyboardShown = NO;
    [self.delagate adjustToReducedScreenArea];
    if (!_disableScrollOnKeyboardHidden)
        [self reactToKeyboardHidden];
    else
        _keyboardHiddenWhileScrollDisabled = YES;
}

- (BOOL)disableScrollOnKeyboardHidden
{
    return _disableScrollOnKeyboardHidden;
}

- (void)setDisableScrollOnKeyboardHidden:(BOOL)disableScrollOnKeyboardHidden
{
    if (_disableScrollOnKeyboardHidden != disableScrollOnKeyboardHidden)
    {
        _disableScrollOnKeyboardHidden = disableScrollOnKeyboardHidden;
        if (_keyboardHiddenWhileScrollDisabled && !_disableScrollOnKeyboardHidden)
        {
            _keyboardHiddenWhileScrollDisabled = NO;
            [self reactToKeyboardHidden];
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _keyboardShown = NO;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasHidden:) name:UIKeyboardDidHideNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidHideNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSLog(@"Memory warning");
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
