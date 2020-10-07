//
//  ARDKDocumentViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 16/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKDocErrorHandler.h"
#import "ARDKActivityViewController.h"
#import "ARDKSearchProgressViewController.h"
#import "ARDKDocumentViewControllerPrivate.h"
#import "ARDKDocTypeDetail.h"

#define PAGES_WIDTH_FACTOR (1.0/6.0)
#define PAGE_INDICATOR_MARGIN (8)
#define ANIM_DURATION (0.3)
#define TOP_BAR_SCALE (0.75)

#define VIEWCONTROLLER_BG_COLOR 0xc0c0c0

@interface ARDKDocumentViewController () <ARDKDocumentEventTarget>
@property (weak, nonatomic) IBOutlet UIView *topBarScaler;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *pageCountLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *pageIndicatorPosition;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomBarConstaintFullscreen;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomBarConstaintNormal;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topBarConstraintFullscreen;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topBarConstraintNormal;
@property NSInteger currentPage;
@property NSLayoutConstraint *docViewEqualWidthConstraint;
@property NSLayoutConstraint *docViewFixedWidthConstraint;
@property NSLayoutConstraint *pagesViewPosConstraint;
@property id<ARDKUI> ui;
@property ARDKActivityViewController *activityIndictor;
@property UIView *touchBlocker;
@property ARDKSearchProgressViewController *searchProgressIndicator;
@property BOOL inhibitPagesViewUpdate;
@property CGFloat topBarScale;
@property NSTimer *expireTimer;
@property (copy) void (^expiresPromptBlock)(UIViewController *presentingVc,
                                            BOOL              docHasBeenModified,
                                            void              (^closeDocBlock)(void));
@end

@implementation ARDKDocumentViewController
{
    BOOL _fullScreenMode;
    BOOL _pagesViewIsVisible;
    BOOL _topBarMenuIsHidden;
    BOOL _navigationBarWasHidden;
    BOOL _hideStatusBar;
    BOOL _recordViewedPageTrack;
}

@synthesize activityIndicator, docWithUI, session, docView;

- (BOOL)documentHasBeenModified
{
    return self.session.documentHasBeenModified;
}

- (void)callShareHandlerPath:(NSString *)path filename:(NSString *)filename fromButton:(UIView *)button fromVC:(UIViewController *)presentingVc completion:(void (^)(void))completion
{
    if (_shareHandler)
    {
        ARDKHandlerInfo *hInfo = [[ARDKHandlerInfo alloc] init];
        hInfo.path = path;
        hInfo.filename = filename;
        hInfo.button = button;
        hInfo.presentingVc = presentingVc;

        _shareHandler(hInfo, completion);
    }
}

- (void)callOpenInHandlerPath:(NSString *)path filename:(NSString *)filename fromButton:(UIView *)button fromVC:(UIViewController *)presentingVc completion:(void (^)(void))completion
{
    if (_openInHandler)
    {
        ARDKHandlerInfo *hInfo = [[ARDKHandlerInfo alloc] init];
        hInfo.path = path;
        hInfo.filename = filename;
        hInfo.button = button;
        hInfo.presentingVc = presentingVc;

        _openInHandler(hInfo, completion);
    }
}

- (void)callOpenPdfInHandlerPath:(NSString *)path fromButton:(UIView *)button fromVC:(UIViewController *)presentingVc completion:(void (^)(void))completion
{
    if (_openPdfInHandler)
    {
        ARDKHandlerInfo *hInfo = [[ARDKHandlerInfo alloc] init];
        hInfo.path = path;
        hInfo.filename = self.session.fileState.displayPath.lastPathComponent;
        hInfo.button = button;
        hInfo.presentingVc = presentingVc;

        _openPdfInHandler(hInfo, completion);
    }
}

- (void)presaveCheckFrom:(UIViewController *)vc onSuccess:(void (^)(void))successBlock
{
    successBlock();
}

- (void)callOpenUrlHandler:(NSURL *)url fromVC:(UIViewController *)presentingView
{
    if (_openUrlHandler)
        _openUrlHandler(presentingView, url);
}

- (void)callSaveAsHandler:(UIViewController *)presentingVc
{
    if (_saveAsHandler)
        _saveAsHandler(presentingVc, _docSession.fileState.displayPath.lastPathComponent, _docSession);
}

- (void)callSaveToHandler:(UIViewController *)presentingVc fromButton:(UIView *)fromButton
{
    if (_saveToHandler)
        _saveToHandler(presentingVc, fromButton, _docSession.fileState.displayPath.lastPathComponent, _docSession);
}

- (void)callPrintHandler:(UIViewController *)presentingVc fromButton:(UIView *)fromButton
{
    if (_printHandler)
        _printHandler(presentingVc, fromButton, _docSession.fileState.displayPath.lastPathComponent, _docSession);
}

- (void)callSavePdfHandler:(UIViewController *)presentingVc
{
    if(_savePdfHandler)
        _savePdfHandler(presentingVc, _docSession.fileState.displayPath.lastPathComponent, _docSession);
}

- (void)setPasteboard:(id<ARDKPasteboard>)pasteboard
{
    self.doc.pasteboard = pasteboard;
    self.docViewController.pasteboard = pasteboard;
}

- (void)timeExpired:(NSTimer *)timer
{
    void(^closeDocBlock)(void) = ^(void) {
        [self closeDocument:^(BOOL success) {
        }];
    };
    
    self.expireTimer = nil;
    if ( self.expiresPromptBlock != nil )
    {
        self.expiresPromptBlock(self, self.doc.hasBeenModified, ^(void) {
            closeDocBlock();
        });
    }
    else
    {
        closeDocBlock();
    }
}

- (void)setExpiresDate:(NSDate *)expiresDate
       withPromptBlock:(void (^)(UIViewController *presentingVc,
                                 BOOL              docHasBeenModified,
                                 void              (^closeDocBlock)(void)))promptBlock
{
    if ( expiresDate != nil )
    {
        NSTimeInterval interval;

        interval = [expiresDate timeIntervalSinceNow];
        if ( interval <= 0 )
            interval = 1;
        
        if ( self.expireTimer != nil )
            [self.expireTimer invalidate];

        self.expireTimer =
            [NSTimer scheduledTimerWithTimeInterval:interval
                                             target:self
                                           selector:@selector(timeExpired:)
                                           userInfo:nil
                                            repeats:NO];
        self.expiresPromptBlock = promptBlock;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    /* The system status bar may already be hidden if the device is iPhone and
     * it is in landscape mode. So, update the status bar appearance.
     * This will prevent the status bar from suddenly appearing and disappearing
     */
    _hideStatusBar = [UIApplication sharedApplication].isStatusBarHidden;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _navigationBarWasHidden = self.navigationController.navigationBarHidden;
    [self.navigationController setNavigationBarHidden:YES animated:animated];

    [self updateUI];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (!_navigationBarWasHidden)
        [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self.view setNeedsUpdateConstraints];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    /* If the running device is iPhone and it is in landscape mode then
     * hide the system status bar. */
    _hideStatusBar = self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)pagesViewIsVisible
{
    return _pagesViewIsVisible;
}

- (void)setRibbonHeight:(CGFloat)height
{
    [self.editTabsViewController setRibbonHeight:height];
}

- (void)setPagesViewIsVisible:(BOOL)pagesViewIsVisible
{
    if (pagesViewIsVisible != _pagesViewIsVisible)
    {
        _pagesViewIsVisible = pagesViewIsVisible;

        // The pages view tracks the main views scroll position, showing the
        // page most centrally located in the main view as selected in the
        // pages view. This is driven mainly from the main view's
        // scrollViewDidView method which may not have been triggered yet,
        // so we update the pages view's selection now.
        [self.pagesViewController selectPage:self.currentPage];
        [self.view layoutIfNeeded];
        self.pagesViewPosConstraint.constant = pagesViewIsVisible
        ? 0
        : self.view.bounds.size.width * PAGES_WIDTH_FACTOR;

        // If we're showing the pages view, disable the docView's "equalWidth" constraint and
        // use it's "fixedWidth" constraint's constant set to the apprporiate width value.
        //
        // If we're not showing the pages view, enable the docView's "equalWidth" constraint
        // and disable it's "fixedWidth" constraint
        self.docViewFixedWidthConstraint.constant = self.view.bounds.size.width * (1.0 - PAGES_WIDTH_FACTOR);
        self.docViewFixedWidthConstraint.active = pagesViewIsVisible ? YES : NO;
        self.docViewEqualWidthConstraint.active = pagesViewIsVisible ? NO : YES;
               
        [UIView animateWithDuration:ANIM_DURATION animations:^{
            [self.view layoutIfNeeded];
        }];
    }
}

- (BOOL)recordViewedPageTrack
{
    return _recordViewedPageTrack;
}

- (void)setRecordViewedPageTrack:(BOOL)recordViewedPageTrack
{
    _recordViewedPageTrack = recordViewedPageTrack;
}

- (CGFloat)amountOfTopBarAlwaysVisible
{
    return 0;
}

- (BOOL)topBarMenuIsHidden
{
    return _topBarMenuIsHidden;
}

- (void)setTopBarMenuIsHidden:(BOOL)topBarMenuIsHidden
{
    if (topBarMenuIsHidden != _topBarMenuIsHidden)
    {
        _topBarMenuIsHidden = topBarMenuIsHidden;
        CGFloat partToLeaveVisible = [self amountOfTopBarAlwaysVisible] * self.topBarScale;
        CGFloat topBarOffset
            = _topBarMenuIsHidden
                ? -(self.topBarScaler.bounds.size.height - partToLeaveVisible)
                : 0;
        if (_fullScreenMode)
        {
            // When in full-screen mode, the effects of topBarConstraintNormal is overridden by
            // topBarConstraintFullscreen, so there is no actual layout change to animate. We still
            // call layoutIfNeeded just in case it helps iOS to be informed that something has been
            // altered; this is likely unnecessary.
            self.topBarConstraintNormal.constant = topBarOffset;
            [self.view layoutIfNeeded];
        }
        else
        {
            [UIView animateWithDuration:ANIM_DURATION animations:^{
                self.topBarConstraintNormal.constant = topBarOffset;
                [self.view layoutIfNeeded];
            }];
        }

    }
}

- (BOOL)fullScreenMode
{
    return _fullScreenMode;
}

- (void)setFullScreenMode:(BOOL)fullScreenMode
{
    if (fullScreenMode != _fullScreenMode)
    {
        _fullScreenMode = fullScreenMode;
        [UIView animateWithDuration:ANIM_DURATION animations:^{
            [self setNeedsStatusBarAppearanceUpdate];
            self.topBarConstraintFullscreen.active = self.fullScreenMode;
            self.bottomBarConstaintFullscreen.active = self.fullScreenMode;
            self.bottomBarConstaintNormal.active = !self.fullScreenMode;
            [self.view layoutIfNeeded];
        }];
    }
}

- (BOOL)prefersStatusBarHidden
{
    return (_fullScreenMode || _hideStatusBar);
}

- (void)loadingAndFirstRenderComplete
{
    self.pageIndicatorPosition.constant = PAGE_INDICATOR_MARGIN;
    [UIView animateWithDuration:ANIM_DURATION animations:^{
        [self.bottomBar layoutIfNeeded];

    }];
}

- (void)updateUI
{
    // Update the display of the file path in the bottom bar
    self.titleLabel.text = self.session.fileState.displayPath;

    switch (self.doc.docType)
    {
        case ARDKDocType_HWP:
        case ARDKDocType_TXT:
        case ARDKDocType_IMG:
        case ARDKDocType_WMF:
        case ARDKDocType_EMF:
            break;
            
        default:
        {
            NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];

            // check if we want to use a dedicated colour, or if we want doc-specific
            // colouring for the viewcontroller background
            NSInteger docSpecific = [self.session.uiTheme getInt:@"so.ui.doccontroller.color.fromdoctype"
                                                           fallback:1];
            UIColor *col = docSpecific != 0
                            ? [ARDKDocTypeDetail docTypeColor:self.doc.docType]
                            : [UIColor colorNamed:@"so.ui.doccontroller.color.background" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];

            self.view.backgroundColor = col;

            // make sure the status bar style is updated to match
            [self setNeedsStatusBarAppearanceUpdate];
        }
        break;
    }
    
    // Tell the edit-tabs view to update
    [self.ui updateUI];
}

- (BOOL)swallowSelectionTap
{
    if (self.fullScreenMode)
    {
        self.fullScreenMode = NO;
        return YES;
    }

    return NO;
}

- (BOOL)swallowSelectionDoubleTap
{
    if (self.fullScreenMode)
    {
        self.fullScreenMode = NO;
        return YES;
    }

    return NO;
}

- (BOOL)inhibitKeyboard
{
    return NO;
}

- (void)viewDidScrollToPage:(NSInteger)page
{
    if (!self.inhibitPagesViewUpdate)
        [self.pagesViewController selectPage:page];

    self.currentPage = page;
    [self updatePageCountLabel];
}

- (void)pageArangementWillBeAltered
{
}

- (void)selectPage:(NSInteger)page
{
    [self pageArangementWillBeAltered];
    self.currentPage = page;
    [self updatePageCountLabel];

    // The Pages View alwasy has (0, 0) page offset.
    CGRect box = CGRectZero;
    if ( _recordViewedPageTrack )
    {
        [self.docView pushViewingState:page withOffset:box.origin];
    }
    self.inhibitPagesViewUpdate = YES;
    [self.docView showPage:page withOffset:box.origin animated:YES];

    [self.pagesViewController selectPage:page];
}

- (void)scrollViewDidEndScrollingAnimation
{
    self.inhibitPagesViewUpdate = NO;
}

- (void)deletePage:(NSInteger)page
{
    NSInteger pageCount = self.doc.pageCount;
    [self pageArangementWillBeAltered];
    [self.doc deletePage:page];
    [self selectPage:page >= pageCount - 1 ? page - 1 : page];
    [self updateUI];
}

- (void)duplicatePage:(NSInteger)page
{
    [self pageArangementWillBeAltered];
    [self.doc duplicatePage:page];
    [self updateUI];
}

- (void)movePage:(NSInteger)page to:(NSInteger)newPos
{
    [self pageArangementWillBeAltered];
    [self.doc movePage:page to:newPos];
    [self updateUI];
}

- (void)showActivityIndicator
{
    self.activityIndictor = [ARDKActivityViewController activityIndicatorWithin:self.view];
}

- (void)hideActivityIndicator
{
    [self.activityIndictor remove];
    self.activityIndictor = nil;
}

/// Called via a delay, so we don't show the indicator if it's going to vanish
/// very quickly.
- (void)showProgressIndicatorInternal
{
    [self.view addSubview:self.searchProgressIndicator.view];
}

- (void)showProgressIndicatorWithTarget:(id)target cancelAction:(SEL)action
{
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);

    // Create a transparent view that blocks touches. Needed because the appearance of the
    // progress indicator is delayed.
    self.touchBlocker = [[UIView alloc] initWithFrame:frame];
    self.touchBlocker.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.0];
    [self.view addSubview:self.touchBlocker];

    self.searchProgressIndicator = [ARDKSearchProgressViewController progressIndicator];
    self.searchProgressIndicator.view.frame = frame;
    [self.searchProgressIndicator.cancelButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];

    [self performSelector:@selector(showProgressIndicatorInternal)
               withObject:nil
               afterDelay:0.1];

}

- (void)hideProgressIndicator
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(showProgressIndicatorInternal)
                                               object:nil];

    [self.touchBlocker removeFromSuperview];
    self.touchBlocker = nil;
    [self.searchProgressIndicator.view removeFromSuperview];
    self.searchProgressIndicator = nil;
}

- (void)setProgressIndicatorProgress:(float)progress
{
    self.searchProgressIndicator.progressView.progress = progress;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    UIStatusBarStyle barStyle    = UIStatusBarStyleDefault;
    BOOL             styleDidSet = NO;
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if ( @available(iOS 13.0, *) )
    {
        NSInteger defaultIsLight = [self.session.uiTheme getInt:@"so.ui.doccontroller.statusbar.default.lightcontent" fallback:1];
        BOOL styleLightContent;
        
        if ( defaultIsLight )
        {
            styleLightContent = self.traitCollection.userInterfaceStyle != UIUserInterfaceStyleDark;
        }
        else
        {
            styleLightContent = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        }
        
        if ( styleLightContent )
        {
            barStyle = UIStatusBarStyleLightContent;
            self.view.tintColor = [UIColor whiteColor];
        }
        else
        {
            barStyle = UIStatusBarStyleDarkContent;
            self.view.tintColor = [UIColor whiteColor];
        }
        styleDidSet = YES;
    }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 */

    if ( !styleDidSet )
    {
        UIColor *bg = self.view.backgroundColor;

        if (bg != nil)
        {
            if ([self.session.uiTheme contrastColor:bg] == 1)
            {
                barStyle = UIStatusBarStyleLightContent;
                self.view.tintColor = [UIColor whiteColor];
            }
            else
            {
                self.view.tintColor = [UIColor blackColor];
            }
        }
    }

    return barStyle;
}

- (void)updatePageCountLabel
{
    self.pageCountLabel.text = [NSString localizedStringWithFormat:NSLocalizedString(@"PAGE %zd OF %d",
                                                                                     @"Position through document indicator"),
                                (ssize_t)self.currentPage+1, (int)self.doc.pageCount];
}

- (UIViewController<ARDKBasicDocViewAPI> *)createBasicDocumentViewForSession:(ARDKDocSession *)session
{
    return nil;
}

- (BOOL)viewShouldIncludePagesView
{
    return YES;
}

- (void)updatePageCount:(NSInteger)numPages andLoadingComplete:(BOOL)complete
{
    if (numPages > self.openOnPage)
    {
        [self updatePageCountLabel];
        [self updateUI];
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

- (void)loadDocAndViews
{
    self.currentPage = 0;
    self.pageCountLabel.text = NSLocalizedString(@"Loading...",
                                                 @"Placeholder text for document page indicator while document loads the first page");
    __weak typeof(self) weakSelf = self;
    [self.docSession.fileState sessionDidShowDoc:self.docSession];
    // Add the main document view
    self.docViewController = [self createBasicDocumentViewForSession:self.docSession];

    // Hook the progress and error events from the document session
    // We wont miss important events because the action of assigning
    // to these blocks will cause resignalling where necessary
    [self.doc addTarget:self];
    self.errorHandler = [ARDKDocErrorHandler errorHandlerForViewController:self showingDoc:self.doc];
    self.docSession.errorBlock = ^(ARDKDocErrorType error)
    {
        [weakSelf.errorHandler handlerError:error];
    };
    [self addChildViewController:self.docViewController];
    // For the Phone UI, we create a menu view in SODKEditTabsViewController,
    // which we transfer to be a subview of this controller's main view.
    // Insert the doc view at index 0 to avoid it overlapping the menu
    [self.view insertSubview:self.docViewController.view atIndex:0];
    [self.docViewController didMoveToParentViewController:self];
    self.docViewController.view.translatesAutoresizingMaskIntoConstraints = NO;

    // Set up the constraints for scaling the top bar
    self.topBarScale = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) ? TOP_BAR_SCALE : 1.0;
    NSLayoutConstraint *topBarWidthConstraint = [NSLayoutConstraint constraintWithItem:self.topBarScaler attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.topBar attribute:NSLayoutAttributeWidth multiplier:self.topBarScale constant:0];
    NSLayoutConstraint *topBarHeightConstraint = [NSLayoutConstraint constraintWithItem:self.topBarScaler attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.topBar attribute:NSLayoutAttributeHeight multiplier:self.topBarScale constant:0];
    [self.topBarScaler addConstraint:topBarWidthConstraint];
    [self.topBarScaler addConstraint:topBarHeightConstraint];
    self.topBar.transform = CGAffineTransformMakeScale(self.topBarScale, self.topBarScale);

    if ([self viewShouldIncludePagesView])
    {
        // Add the pages view
        self.pagesViewController = [ARDKPagesViewController viewControllerWithSession:self.session];
        self.pagesViewController.delegate = self;
        [self addChildViewController:self.pagesViewController];
        [self.view addSubview:self.pagesViewController.view];
        [self.pagesViewController didMoveToParentViewController:self];
        self.pagesViewController.view.translatesAutoresizingMaskIntoConstraints = NO;

        // Arrange for the document view to always be just below the search bar so that
        // the document view drops a little when we animate the search bar. Also below
        // the search bar, and to the right of the document view, place the pages view.
        CGFloat pagesViewWidth = self.view.bounds.size.width*PAGES_WIDTH_FACTOR;

        // Abut the pages view to the right of the document view
        NSArray *horz = [NSLayoutConstraint constraintsWithVisualFormat:@"|[docview][pagesview]" options:0 metrics:nil views:@{@"docview":self.docViewController.view,@"pagesview":self.pagesViewController.view}];

        // Make the pages view's width a fixed proportion of the containing view
        NSLayoutConstraint *pagesWidthConstraint = [NSLayoutConstraint constraintWithItem:self.pagesViewController.view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:PAGES_WIDTH_FACTOR constant:0.0];

        // Make an alterable constraint fixing the righthand edge of the pages view
        self.pagesViewPosConstraint = [NSLayoutConstraint constraintWithItem:self.pagesViewController.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:pagesViewWidth];

        // Stick both the document view and pages view below the search bar
        NSArray *vert1 = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[topbar][docview][bottombar]" options:0 metrics:nil views:@{@"topbar":self.topBarScaler, @"docview":self.docViewController.view, @"bottombar":self.bottomBar}];

        NSArray *vert2 = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[topbar][pagesview][bottombar]" options:0 metrics:nil views:@{@"topbar":self.topBarScaler, @"pagesview":self.pagesViewController.view, @"bottombar":self.bottomBar}];

        [self.view addConstraints:horz];
        [self.view addConstraint:pagesWidthConstraint];
        [self.view addConstraint:self.pagesViewPosConstraint];
        [self.view addConstraints:vert1];
        [self.view addConstraints:vert2];
        
        // add a layout width constraint to self.docViewController to keep it's width the same as self.view
        self.docViewEqualWidthConstraint = [NSLayoutConstraint constraintWithItem:self.docViewController.view
                                                                        attribute:NSLayoutAttributeWidth
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self.view
                                                                        attribute:NSLayoutAttributeWidth
                                                                       multiplier:1.0
                                                                         constant:0];
        self.docViewEqualWidthConstraint.priority = 1000;
        self.docViewEqualWidthConstraint.active = YES;
        [self.view addConstraint:self.docViewEqualWidthConstraint];
        
        // add a lower proirity layout width constraint to self.docViewController to make it fixed. We'll
        // manipulate the constant value in this constraint when we show/hide the pages view
        self.docViewFixedWidthConstraint = [NSLayoutConstraint constraintWithItem:self.docViewController.view
                                                                        attribute:NSLayoutAttributeWidth
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:nil
                                                                        attribute:NSLayoutAttributeNotAnAttribute
                                                                       multiplier:1.0
                                                                         constant:0.0];
        self.docViewFixedWidthConstraint.priority = 950;
        self.docViewFixedWidthConstraint.active = NO;
        [self.view addConstraint:self.docViewFixedWidthConstraint];
    }
    else
    {
        // Fit the doc view to the container
        NSArray *horz = [NSLayoutConstraint constraintsWithVisualFormat:@"|[docview]|" options:0 metrics:nil views:@{@"docview":self.docViewController.view}];

        // Stick the document view between the top and bottom bars
        NSArray *vert = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[topbar][docview][bottombar]" options:0 metrics:nil views:@{@"topbar":self.topBarScaler, @"docview":self.docViewController.view, @"bottombar":self.bottomBar}];

        [self.view addConstraints:horz];
        [self.view addConstraints:vert];
    }
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    if (self.pagesViewPosConstraint.constant > 0.0)
        self.pagesViewPosConstraint.constant = self.view.bounds.size.width*PAGES_WIDTH_FACTOR;
    
    if (self.docViewFixedWidthConstraint.active)
        self.docViewFixedWidthConstraint.constant = self.view.bounds.size.width * (1.0 - PAGES_WIDTH_FACTOR);

    self.topBarConstraintFullscreen.active = self.fullScreenMode;
    self.bottomBarConstaintFullscreen.active = self.fullScreenMode;
    self.bottomBarConstaintNormal.active = !self.fullScreenMode;
}

- (void)dealloc
{
    if ( self.expireTimer )
    {
        [self.expireTimer invalidate];
        self.expireTimer = nil;
    }

    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(showProgressIndicatorInternal)
                                               object:nil];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"embedEditTabs"])
    {
        ARDKEditTabsViewController *vc = (ARDKEditTabsViewController *)segue.destinationViewController;

        self.ui = vc;
        vc.docWithUI = self;
        vc.activityIndicator = self;
        vc.docWithUIViewContoller = self;
        self.editTabsViewController = vc;
    }
}

- (void)closeDocument:(void (^)(BOOL))onCompletion {
    [self.editTabsViewController closeDocument:onCompletion];
}

- (ARDKDocType)docType
{
    return self.doc.docType;
}

@end
