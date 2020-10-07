//
//  ARDKPagesViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 17/11/2015.
//  Copyright © 2015 Artifex Software Inc. All rights reserved.
//

#import "ARDKGeometry.h"
#import "ARDKPageView.h"
#import "ARDKCollectionViewCell.h"
#import "ARDKViewRenderer.h"
#import "ARDKDocTypeDetail.h"
#import "ARDKPagesViewController.h"

// All localized string in this file should be obtained from the sodk framework
#undef NSLocalizedString
#define NSLocalizedString(key, comment) NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:self.class], comment)

// Make the pages a little smaller than the scroll view so give
// a little margin around them. We may want to revisit this and
// use a more systematic mechanism.
#define PAGE_GAP (8.0)

#define BACGROUND_LUM (0x33)

@interface ARDKPagesViewController () <ARDKViewRendererDelegate, ARDKDocumentEventTarget>
@property ARDKDocSession *session;
@property id<ARDKDoc> doc;
@property ARDKViewRenderer *renderer;
@property NSInteger menuPage;
@property CGRect menuTarget;
@property NSInteger collectionViewPageCount;
@property BOOL collectionViewInitialized;
@end

@implementation ARDKPagesViewController
{
    NSInteger _pageCount;
}

// SODKPageViewController has it's own private rendering bitmap because it
// appears on screen simultaneously with other views. It uses full screen
// sized ones, so we should arrange for it to use smaller ones at some stage.
@synthesize bitmap;

- (void)updateDarkMode
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if (self.session.docSettings.contentDarkModeEnabled)
    {
        if ( @available(iOS 13.0, *) )
        {
            self.renderer.darkMode = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
        }
    }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 */
}

- (instancetype)initWithSession:(ARDKDocSession *)session
{
    self = [super initWithCollectionViewLayout:[[UICollectionViewFlowLayout alloc] init]];
    if (self)
    {
        self.session = session;
        self.doc = session.doc;
        self.renderer = [[ARDKViewRenderer alloc] initWithDelegate:self lib:self.doc];
        [self updateDarkMode];
        if ([self respondsToSelector:@selector(setInstallsStandardGestureForInteractiveMovement:)])
            self.installsStandardGestureForInteractiveMovement = NO;
        self.collectionView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
        [self.doc addTarget:self];
    }
    return self;
}

+ (instancetype)viewControllerWithSession:(ARDKDocSession *)session
{
    return [[ARDKPagesViewController alloc] initWithSession:session];
}

- (void)updatePageCount:(NSInteger)pageCount andLoadingComplete:(BOOL)complete
{
    _pageCount = pageCount;
    if (self.collectionViewInitialized)
        [self updateCollectionViewPageCount];
}

- (void)pageSizeHasChanged
{
    if (_pageCount > 0)
    {
        UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;
        id<ARDKPage> page = [self.doc getPage:0 update:nil];
        CGFloat pageWidth = self.view.bounds.size.width;
        CGFloat pageScale = (pageWidth - 2 * PAGE_GAP) / pageWidth;
        layout.itemSize = [ARDKPageView adjustSize:ARCGSizeScale(self.view.bounds.size,pageScale) toPage:page];
        layout.minimumLineSpacing = PAGE_GAP;
        layout.sectionInset = UIEdgeInsetsMake(PAGE_GAP, 0, PAGE_GAP, 0);
        [self.renderer forceRender];
        [self.renderer triggerRender];
    }
}

- (void)selectionHasChanged
{
}

- (void)layoutHasCompleted
{
}

- (void)updateCollectionViewPageCount
{
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;

    if (_pageCount > 0 && self.collectionViewPageCount == 0)
    {
        id<ARDKPage> page = [self.doc getPage:0 update:nil];
        CGFloat pageWidth = self.view.bounds.size.width;
        CGFloat pageScale = (pageWidth - 2 * PAGE_GAP) / pageWidth;
        layout.itemSize = [ARDKPageView adjustSize:ARCGSizeScale(self.view.bounds.size,pageScale) toPage:page];
    }

    NSMutableArray *array = [NSMutableArray array];
    if (_pageCount > self.collectionViewPageCount)
    {
        for (NSInteger i = self.collectionViewPageCount; i < _pageCount; i++)
            [array addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        self.collectionViewPageCount = _pageCount;
        [self.collectionView insertItemsAtIndexPaths:array];
    }
    else if (_pageCount < self.collectionViewPageCount)
    {
        for (NSInteger i = _pageCount; i < self.collectionViewPageCount; i++)
            [array addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        self.collectionViewPageCount = _pageCount;
        [self.collectionView deleteItemsAtIndexPaths:array];
    }

    if (array.count > 0)
    {
        [self.renderer forceRender];
        [self.renderer triggerRender];
    }
}

- (void)selectPage:(NSInteger)page
{
    // If the page is within range, ask the collection view to select the page
    if (page < self.collectionViewPageCount)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:page inSection:0];
        [self.collectionView selectItemAtIndexPath:indexPath animated:YES scrollPosition:UICollectionViewScrollPositionNone];
        UICollectionViewLayoutAttributes *atts = [self.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
        [self.collectionView scrollRectToVisible:atts.frame animated:YES];
    }
}

static NSString * const reuseIdentifier = @"Cell";

- (void)viewDidLoad {
    [super viewDidLoad];

    // Register cell classes
    [self.collectionView registerClass:[ARDKCollectionViewCell class] forCellWithReuseIdentifier:reuseIdentifier];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.collectionView addGestureRecognizer:longPress];
    self.collectionView.backgroundColor = [UIColor colorWithWhite:BACGROUND_LUM/255.0 alpha:1.0];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)delete:(id)sender
{
    [self.delegate deletePage:self.menuPage];
    [self selectPage:self.menuPage >= _pageCount - 1 ? self.menuPage - 1 : self.menuPage];
}

- (void)duplicate:(id)sender
{
    [self.delegate duplicatePage:self.menuPage];
}

- (void)showMenu
{
    [self becomeFirstResponder];
    // Duplicate is not one of the standard menu items, so add it
    UIMenuItem *duplicate = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Duplicate",
                                                                                @"Menu item for adding to the document a copy of an existing page")action:@selector(duplicate:)];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    menuController.menuItems = @[duplicate];
    [menuController setTargetRect:self.menuTarget inView:self.collectionView];
    [menuController setMenuVisible:YES animated:YES];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture
{
    switch (gesture.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:[gesture locationInView:self.collectionView]];
            if (indexPath)
            {
                self.menuPage = indexPath.item;
                [self selectPage:self.menuPage];
                [self.delegate selectPage:self.menuPage];
                self.menuTarget = [self.collectionView layoutAttributesForItemAtIndexPath:indexPath].frame;
                [self.collectionView beginInteractiveMovementForItemAtIndexPath:indexPath];
                [self.collectionView updateInteractiveMovementTargetPosition:[gesture locationInView:self.collectionView]];
            }
            else
            {
                self.menuTarget = CGRectNull;
            }
            break;
        }
        case UIGestureRecognizerStateChanged:
            [self.collectionView updateInteractiveMovementTargetPosition:[gesture locationInView:gesture.view]];
            break;
        case UIGestureRecognizerStateEnded:
            [self.collectionView endInteractiveMovement];
            if (self.doc.docSupportsPageManipulation && !CGRectIsNull(self.menuTarget))
                [self showMenu];
            break;
        default:
            [self.collectionView cancelInteractiveMovement];
            break;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.collectionViewInitialized = YES;
    // We may have had pages load before the view appeared, which would
    // not have updated the collection view, so check that now
    [self updateCollectionViewPageCount];
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

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self pageSizeHasChanged];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    /* This is a workaround for this message appearing on the console:

     The behavior of the UICollectionViewFlowLayout is not defined because:
     the item width must be less than the width of the UICollectionView minus the section insets left and right values, minus the content insets left and right values.

     fix is based on a suggestion from:

     http://stackoverflow.com/questions/14469251/uicollectionviewflowlayout-size-warning-when-rotating-device-to-landscape

     (though the answers there suggest the deprecated willAnimateRotationToInterfaceOrientation)

     The implication seems to be that this is a bug somewhere in UIKit. The console
     message doesn't seem to relate to any issue that becomes visible to the
     user, but never the less it is nice to avoid scary warnings on the console.

     */

    [self.collectionView.collectionViewLayout invalidateLayout];
}

#pragma mark <UIScrollViewDelegate>

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.renderer triggerRender];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    // The selectPage method (early in this file) calls selectItemAtIndexPath which you'd hope
    // would reset the selection state of the previously selected cell to NO
    // and set the new one to YES. It does, but only for currently visible cells.
    //
    // It is not conditional on whether the cell is cached or not; it truly is
    // dependent on visibility, so ensuring selection is set correctly in
    // collectionView:cellForItemAtIndexPath: doesn't help.
    //
    // Nor can we explitly set the selection state of the cell in selectPage because
    // cellForItemAtIndexPath: returns nil for non-visible cells (again independently of
    // whether the cell is cached or not)
    //
    // To work around this problem, we update the selected state of all visible cells whenever
    // scrolling ends
    for (NSIndexPath *indexPath in self.collectionView.indexPathsForVisibleItems)
        [self.collectionView cellForItemAtIndexPath:indexPath].selected = [self.collectionView.indexPathsForSelectedItems containsObject:indexPath];
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.collectionViewPageCount;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ARDKCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    ARDKPageView *pageView = (ARDKPageView *)cell.pageView;
    if (pageView == nil)
    {
        pageView = [[ARDKPageView alloc] initWithDoc:self.doc];
        cell.pageView = pageView;
    }
    // Configure the cell
    [pageView useForPageNumber:cell.pageNumber withSize:cell.pageViewFrame.size];
    pageView.highlightColor = [ARDKDocTypeDetail docTypeColor:self.doc.docType];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.renderer forceRender];
        [self.renderer triggerRender];
    });

    return cell;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    return self.doc.docSupportsPageManipulation;
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    [self.delegate movePage:sourceIndexPath.item to:destinationIndexPath.item];

    // The above call updates the document with the reordered pages, but we also
    // have them reordered in this view. Reload the data so that each learns its
    // new page number.
    NSMutableArray<NSIndexPath *> *paths = [NSMutableArray array];
    NSInteger from = MIN(sourceIndexPath.item, destinationIndexPath.item);
    NSInteger to = MAX(sourceIndexPath.item, destinationIndexPath.item);
    for (NSInteger i = from; i <= to; i++)
        [paths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
    [self.collectionView reloadItemsAtIndexPaths:paths];

    [self.renderer forceRender];
    [self.renderer triggerRender];

    // Don't show a menu after reordering
    self.menuTarget = CGRectNull;
    [self.delegate selectPage:destinationIndexPath.item];
}

#pragma mark <ARDKViewRendererDelegate>

- (CGPoint)contentOffset
{
    return self.collectionView.contentOffset;
}

- (void)iteratePages:(void (^)(NSInteger, UIView<ARDKPageCellDelegate> *, CGRect))block
{
    for (ARDKCollectionViewCell *cell in self.collectionView.visibleCells)
    {
        // Calculate the area of our view that this page covers
        CGRect rect = CGRectOffset(cell.frame, -self.contentOffset.x, -self.contentOffset.y);

        block((int)[self.collectionView indexPathForCell:cell].item, cell.pageView, rect);
    }
}

#pragma mark <UICollectionViewDelegate>

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self.delegate selectPage:indexPath.item];
}

@end
