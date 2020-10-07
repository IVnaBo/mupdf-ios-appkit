//
//  ARDKEditTabsViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 11/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKEditTabsViewController.h"
#import "ARDKSelectButton.h"
#import "ARDKDocTypeDetail.h"
#import "ARDKDocumentViewControllerPrivate.h"

// All localized string in this file should be obtained from the sodk framework
#undef NSLocalizedString
#define NSLocalizedString(key, comment) NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:self.class], comment)

#define FADE_DURATION (0.3)
#define FILE_TAB_TAG (1)
#define TAB_GREY (0xE5E5E5)
#define TAB_INSET (16)
#define PHONE_TAB_INSET (12)
#define PHONE_TAB_FONT_SIZE (12)
#define TAB_FONT_SIZE (15)
#define TAB_FONT_COLOR (0x000000)
#define TAB_HEIGHT (38)
#define TAB_SEPARATION (2)
#define MENU_RADIUS (5)
#define MENU_TAB_FONT_COLOR_SELECTED (0x000000)
#define MENU_TAB_COLOR (0x546473)
#define MENU_TAB_FONT_COLOR (0xffffff)
#define MENU_TAB_ICON_COLOR (0x000000)
#define MENU_TAB_SELECTED_COLOR (0xEBEBEB)
#define MENU_PHONETAB_COLOR (0xffffff)
#define MENU_PHONETAB_COLOR_BACKGROUND (0xEBEBEB)
#define MENU_PHONETAB_FONT_COLOR (0x000000)
#define MENU_PHONETAB_FONT_COLOR_SELECTED (0x000000)
#define MENU_PHONETAB_RADIUS (0)
#define MENU_BORDER_WIDTH   (2)
#define MENU_BORDER_COLOR   (0xffffff)
#define MENU_CORNER_RADIUS  (10)

#define DEFAULT_COLOR_LIGHT (0xffffff)
#define DEFAULT_COLOR_DARK  (0x303030)

typedef int SOError;
typedef void (^OnClosedHandler)(BOOL);

@interface OnClosedWrapper : NSObject
@property (nonatomic, copy) OnClosedHandler handler;
@end
@implementation OnClosedWrapper
@end

@implementation ARDKTabDesc
+ (ARDKTabDesc *)tabDescText:(NSString *)text doing:(SEL)action
{
    ARDKTabDesc *td = [[ARDKTabDesc alloc]init];
    td.text = text;
    td.action = action;
    return td;
}
@end

@interface ARDKEditTabsViewController ()
@property (weak, nonatomic) IBOutlet UIView *phoneTabView;
@property NSInteger selectedButtonTag;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *ribbonHeightConstraint;
@property (weak, nonatomic) IBOutlet UIButton *phoneTab;
@property (weak, nonatomic) IBOutlet UIView *tabletUITabs;
@property (weak, nonatomic) IBOutlet UIButton *fullScreenButton;
@property NSArray<NSLayoutConstraint *> *menuConstraints;
@property UIView *coverView;
@property NSString *themeName;
@property BOOL tabsHaveBeenCreated;
@end

#define EDITBAR_BUTTON_COLOR_LIGHT (0xffffff)
#define EDITBAR_BUTTON_COLOR (0x303030)

@implementation ARDKEditTabsViewController

@synthesize docWithUI, activityIndicator, phoneMenuIcon, phoneMenuPopup;

- (void)setRibbonHeight:(CGFloat)height
{
    self.ribbonHeightConstraint.constant = height;
}

- (void)createTabs
{
    NSDate *expiresDate = self.docWithUI.docSession.docSettings.expiresDate;
    
    if ( expiresDate != nil )
        [self.docWithUI setExpiresDate:expiresDate withPromptBlock:self.docWithUI.docSession.docSettings.expiresPromptBlock];
}

- (UIView*)createTabsForTablet:(NSArray<ARDKTabDesc *> *)tabs
{
    CGRect dummyFrame = CGRectMake(0, 0, 0, 0);
    UIView *lastTab = nil;
    NSArray<NSLayoutConstraint *> *constraints;
    NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];

    for (int i = 0; i < tabs.count; i++)
    {
        ARDKTabDesc *info = tabs[i];
        ARDKSelectButton *tab = [[ARDKSelectButton alloc] initWithFrame:dummyFrame];
        tab.tag = i+1;
        tab.translatesAutoresizingMaskIntoConstraints = NO;
        [tab setTitle:info.text forState:UIControlStateNormal];
        [tab addTarget:self action:info.action forControlEvents:UIControlEventTouchUpInside];
        
        NSInteger inset = [self.docWithUI.session.uiTheme getInt:@"so.ui.menu.inset.tablet"
                                                 fallback:TAB_INSET];
        tab.contentEdgeInsets = UIEdgeInsetsMake(0, inset, 0, 0);
        tab.titleEdgeInsets = UIEdgeInsetsMake(0, -inset, 0, 0);
        
        NSInteger fontSize = [self.docWithUI.session.uiTheme getInt:@"so.ui.menu.font.size"
                                                    fallback:TAB_FONT_SIZE];
        tab.titleLabel.font = [UIFont systemFontOfSize:fontSize];


        UIColor *docTypeColor = [ARDKDocTypeDetail docTypeColor:self.docWithUI.doc.docType];
        Boolean useDocTypeColorForNormal = [self.docWithUI.session.uiTheme getInt:@"so.ui.menu.tab.color.background.fromdoctype"
                                                                  fallback:1] != 0;
        Boolean useDocTypeColorForHighlight = [self.docWithUI.session.uiTheme getInt:@"so.ui.menu.tab.color.background.highlight.fromdoctype"
                                                                     fallback:0] != 0;

        if(useDocTypeColorForNormal)
        {
            tab.backgroundColor = docTypeColor;
        }
        else
        {
            tab.backgroundColor = [UIColor colorNamed:@"so.ui.menu.tab.color.background" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        }
        
        if(useDocTypeColorForHighlight)
        {
            tab.backgroundColorWhenSelected = docTypeColor;
        }
        else
        {
            // get the background color from the theme
            tab.backgroundColorWhenSelected = [UIColor colorNamed:@"so.ui.menu.tab.color.background.highlight" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        }

        // get the font color from the theme, using our contrast color as the fallback
        
        UIColor *fontColor = [UIColor colorNamed:@"so.ui.menu.tab.font.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        [tab setTitleColor:fontColor forState:UIControlStateNormal];
        fontColor = [UIColor colorNamed:@"so.ui.menu.tab.font.color.highlight" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        [tab setTitleColor:fontColor forState:UIControlStateSelected];

        [self.tabletUITabs addSubview:tab];
        constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tab(height)]" options:0 metrics:@{@"height":@(TAB_HEIGHT)} views:@{@"tab":tab}];
        [self.tabletUITabs addConstraints:constraints];
        if (lastTab)
        {
            constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"[lastTab]-(sep)-[thisTab]" options:0 metrics:@{@"sep":@(TAB_SEPARATION)} views:@{@"lastTab":lastTab, @"thisTab":tab}];
            [self.tabletUITabs addConstraints:constraints];
        }
        else
        {
            constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|[tab]" options:0 metrics:nil views:@{@"tab":tab}];
            [self.tabletUITabs addConstraints:constraints];
        }

        lastTab = tab;
    }
    assert(lastTab);

    constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"[tab]|" options:0 metrics:nil views:@{@"tab":lastTab}];
    [self.tabletUITabs addConstraints:constraints];

    return self.tabletUITabs;
}

- (UIView*)createTabsForPhone:(NSArray<ARDKTabDesc *> *)tabs
{
    CGRect dummyFrame = CGRectMake(0, 0, 0, 0);
    UIView *lastTab = nil;
    NSArray<NSLayoutConstraint *> *constraints;
    NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];

    for (int i = 0; i < tabs.count; i++)
    {
        ARDKTabDesc *info = tabs[i];
        ARDKSelectButton *tab = [[ARDKSelectButton alloc] initWithFrame:dummyFrame];
        tab.tag = i+1;
        tab.translatesAutoresizingMaskIntoConstraints = NO;
        [tab setTitle:info.text forState:UIControlStateNormal];
        [tab addTarget:self action:info.action forControlEvents:UIControlEventTouchUpInside];
        tab.layer.cornerRadius = [self.docWithUI.session.uiTheme getInt:@"so.ui.menu.item.rounding"
                                                        fallback:MENU_PHONETAB_RADIUS];
        tab.backgroundColor = [UIColor colorNamed:@"so.ui.menu.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        tab.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        NSInteger inset = [self.docWithUI.session.uiTheme getInt:@"so.ui.menu.inset.phone"
                                                    fallback:PHONE_TAB_INSET];
        tab.titleEdgeInsets = UIEdgeInsetsMake(0, inset, 0, 0);
        NSInteger fontSize = [self.docWithUI.session.uiTheme getInt:@"so.ui.menu.font.size"
                                                    fallback:PHONE_TAB_FONT_SIZE];
        tab.titleLabel.font = [UIFont systemFontOfSize:fontSize];
        tab.backgroundColorWhenSelected = [UIColor colorNamed:@"so.ui.menu.color.highlight" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        UIColor *fontColor = [UIColor colorNamed:@"so.ui.menu.font.color.highlight" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        [tab setTitleColor:fontColor forState:UIControlStateSelected];
        fontColor = [UIColor colorNamed:@"so.ui.menu.font.color"];
        [tab setTitleColor:fontColor forState:UIControlStateNormal];

        // the ribbon view tint will be applied to all contained buttons
        self.phoneMenuPopup.tintColor = [UIColor colorNamed:@"so.ui.menu.button.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];

        self.phoneMenuPopup.layer.borderColor = [UIColor colorNamed:@"so.ui.menu.phonetab.border.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil].CGColor;
        self.phoneMenuPopup.layer.borderWidth = [self.docWithUI.session.uiTheme getInt:@"so.ui.menu.border.width"
                                                             fallback:MENU_BORDER_WIDTH];
        self.phoneMenuPopup.layer.cornerRadius = [self.docWithUI.session.uiTheme getInt:@"so.ui.menu.rounding"
                                                              fallback:MENU_CORNER_RADIUS];
        [self.phoneMenuPopup addSubview:tab];
        constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|[tab]|" options:0 metrics:nil views:@{@"tab":tab}];
        [self.phoneMenuPopup addConstraints:constraints];
        if (lastTab)
        {
            constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[lastTab][thisTab(height)]" options:0 metrics:@{@"height":@(TAB_HEIGHT)} views:@{@"lastTab":lastTab, @"thisTab":tab}];
            [self.phoneMenuPopup addConstraints:constraints];
        }
        else
        {
            constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tab(height)]" options:0 metrics:@{@"height":@(TAB_HEIGHT)} views:@{@"tab":tab}];
            [self.phoneMenuPopup addConstraints:constraints];
        }

        lastTab = tab;
    }
    assert(lastTab);

    constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[tab]|" options:0 metrics:nil views:@{@"tab":lastTab}];
    [self.phoneMenuPopup addConstraints:constraints];

    if ( 0 == [self.docWithUI.session.uiTheme getInt:@"so.ui.menu.phonetab.color.fromdoctype" fallback:0] )
    {
        self.phoneTabView.backgroundColor = [UIColor colorNamed:@"so.ui.menu.phonetab.color.background" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
    }
    else
    {
        self.phoneTabView.backgroundColor = [ARDKDocTypeDetail docTypeColor:self.docWithUI.doc.docType];
    }

    // Use the tab font color as the tint for menu icon
    self.phoneTabView.tintColor = [UIColor colorNamed:@"so.ui.menu.phonetab.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];

    self.phoneTabView.layer.borderColor = [UIColor colorNamed:@"so.ui.menu.phonetab.border.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil].CGColor;
    self.phoneTabView.layer.borderWidth = [self.docWithUI.session.uiTheme
                                           getInt:@"so.ui.menu.border.width"
                                           fallback:MENU_BORDER_WIDTH];
    self.phoneTabView.layer.cornerRadius = [self.docWithUI.session.uiTheme
                                        getInt:@"so.ui.menu.rounding"
                                        fallback:MENU_CORNER_RADIUS];

    UIColor *fontColor = [UIColor colorNamed:@"so.ui.menu.phonetab.font.color.highlight" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
    [self.phoneTab setTitleColor:fontColor forState:UIControlStateSelected];
    fontColor = [UIColor colorNamed:@"so.ui.menu.phonetab.font.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
    [self.phoneTab setTitleColor:fontColor forState:UIControlStateNormal];

    return self.phoneMenuPopup;
}

- (void)updateUI
{
    // set the edit tab controller button color based on background color
    self.view.backgroundColor = self.parentViewController.view.backgroundColor;
    // the ribbon view tint will be applied to all contained buttons

    Boolean useDocTypeColor = [self.docWithUI.session.uiTheme getInt:@"so.ui.menu.tab.color.background.fromdoctype"
                                                              fallback:1] != 0;
    NSInteger defaultTint = DEFAULT_COLOR_LIGHT;

    // if we're using explicit color for the tab bar background,
    // figure out a suitable contrast color for the buttons
    // If we're using docTypeColor then always use the default light color.
    if (!useDocTypeColor)
    {
        defaultTint = DEFAULT_COLOR_DARK;
        if ([self.docWithUI.session.uiTheme contrastColor:[self.view backgroundColor]] == 1)
            defaultTint = DEFAULT_COLOR_LIGHT;

        self.view.tintColor = [self.docWithUI.session.uiTheme getUIColor:@"so.ui.editbar.button.color"
                                                         fallback:defaultTint];
    }
    
    [self.container updateUI];
}

- (void)closeMenu
{
    // Remove the cover view
    [self.coverView removeFromSuperview];
    self.coverView = nil;
    // Fade out the menu
    [UIView animateWithDuration:FADE_DURATION animations:^{
        self.phoneMenuPopup.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.phoneMenuPopup.hidden = YES;
    }];
}

- (void)selectedTabDidChange
{
}

- (void)updateSelection:(NSInteger)senderTag
{
    if (senderTag > 0 && senderTag != self.selectedButtonTag)
    {
        Boolean isTablet = (self.view.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular);
        UIView *container = isTablet ? self.tabletUITabs : self.phoneMenuPopup;
        
        // Look up the button in docWithUIViewController because in
        // Phone UI mode its in the menu which has been moved to docWithUIViewController
        UIButton *oldButton = self.selectedButtonTag > 0 ? [container viewWithTag:self.selectedButtonTag] : nil;
        UIButton *newButton = [container viewWithTag:senderTag];
        if (self.phoneMenuPopup)
        {
            // For the Phone UI, set the text of the single tab
            // according to which menu entry was tapped
            [self.phoneTab setTitle:newButton.titleLabel.text forState:UIControlStateNormal];

            // Close the menu
            [self closeMenu];
        }
        oldButton.selected = NO;
        newButton.selected = YES;
        self.selectedButtonTag = senderTag;
        [self selectedTabDidChange];
    }
}

- (IBAction)menuButtonWasTapped:(id)sender
{
    // Add a covering view to avoid interaction outside of the menu
    self.coverView = [[UIView alloc]init];
    self.coverView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.docWithUIViewContoller.view addSubview:self.coverView];
    NSArray<NSLayoutConstraint *> *horz = [NSLayoutConstraint constraintsWithVisualFormat:@"|[cover]|" options:0 metrics:nil views:@{@"cover":self.coverView}];
    NSArray<NSLayoutConstraint *> *vert = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[cover]|" options:0 metrics:nil views:@{@"cover":self.coverView}];
    [self.docWithUIViewContoller.view addConstraints:horz];
    [self.docWithUIViewContoller.view addConstraints:vert];
    // Dismiss menu if screen tapped outside
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(closeMenu)];
    [self.coverView addGestureRecognizer:tap];
    [self.docWithUIViewContoller.view insertSubview:self.phoneMenuPopup aboveSubview:self.coverView];
    // Remove and readd the positioning constraints. This was added to fix a strange
    // problem where trait changes could cause a mispositioning of the menu
    [self.docWithUIViewContoller.view removeConstraints:self.menuConstraints];
    [self.docWithUIViewContoller.view addConstraints:self.menuConstraints];
    // Fade in the menu
    self.phoneMenuPopup.hidden = NO;
    [UIView animateWithDuration:FADE_DURATION animations:^{
        self.phoneMenuPopup.alpha = 1.0;
    } completion:^(BOOL finished) {
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.themeName = [self.docWithUI.session.uiTheme getString:@"so.ui.theme.name"
                                               fallback:@"default"];

    [self movePhoneMenuToParent];

    if (self.docWithUI.session.docSettings.fullScreenModeEnabled)
        self.fullScreenButton.hidden = NO;
}

- (void)selectDefaultRibbon
{
    [self.container requestSegue:@"file"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear: animated];
    assert(self.docWithUI);
    if (!self.tabsHaveBeenCreated)
    {
        [self createTabs];
        self.tabsHaveBeenCreated = YES;
    }

    if (self.selectedButtonTag == 0)
        [self selectDefaultRibbon];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.selectedButtonTag == 0)
        [self updateSelection:FILE_TAB_TAG];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    if ( self.coverView != nil )
    {
        [self.coverView removeFromSuperview];
        self.coverView = nil;
    }
    self.phoneMenuPopup.hidden = YES;
    self.phoneMenuPopup.alpha = 0;

    [super traitCollectionDidChange:previousTraitCollection];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if ( @available(iOS 13.0, *) )
    {
        BOOL hasUserInterfaceStyleChanged = [previousTraitCollection hasDifferentColorAppearanceComparedToTraitCollection:self.traitCollection];
        
        if ( hasUserInterfaceStyleChanged )
        {
            NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];

            /* CGColor of the dynamic color(named color) doesn't change
               automatically, so reset the color of the control manually. */
            CGColorRef cgColor = [UIColor colorNamed:@"so.ui.menu.phonetab.border.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil].CGColor;
            if ( self.phoneMenuPopup != nil )
                self.phoneMenuPopup.layer.borderColor = cgColor;
            if ( self.phoneTabView != nil )
                self.phoneTabView.layer.borderColor = cgColor;
        }
    }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 */
}

- (void)didMoveToParentViewController:(UIViewController *)parent
{
    [super didMoveToParentViewController:parent];
    // Allow our main view to influence the size of the parent view, via autolayout. The
    // default is for the parent to control the child. The parent view is a simple
    // container, so we add constraints to fill it.
    if (parent)
    {
        self.view.translatesAutoresizingMaskIntoConstraints = NO;
        NSArray<NSLayoutConstraint *> *horz = [NSLayoutConstraint constraintsWithVisualFormat:@"|[child]|" options:0 metrics:nil views:@{@"child":self.view}];
        NSArray<NSLayoutConstraint *> *vert = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[child]|" options:0 metrics:nil views:@{@"child":self.view}];
        [self.view.superview addConstraints:horz];
        [self.view.superview addConstraints:vert];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    // This override is being used to pick up trait collection changes.
    // We use viewDidLayoutSubviews because traitCollectionDidChange is
    // called too early. The Phone and Tablet UI use different ribbon-selecton
    // tabs. When swapping between the UIs, we need to make sure the correct
    // tab is selected within the incoming tabs. We give the two sets of tabs
    // matching tags so we can use that to identify the tab that needs selecting.
    // If we perform this procedure on traitCollectionDidChange, viewWithTag picks
    // up the outgoing tabs.
    Boolean isTablet = (self.view.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular);
    UIView *container = isTablet ? self.tabletUITabs : self.phoneMenuPopup;
    UIButton *selectedTab;
    UIButton *tab;
    for (NSInteger tag = 1; (tab = [container viewWithTag:tag]); tag++)
    {
        tab.selected = (tag == self.selectedButtonTag);
        if (tab.selected)
            selectedTab = tab;
    }
    
    // Ensure the single phone tab is labelled correctly
    [self.phoneTab setTitle:selectedTab.titleLabel.text forState:UIControlStateNormal];
    
#ifdef RIGHT_ALIGNED_MENU
    if( [self.themeName isEqualToString:@"bbedit"] )
    {
        // change the layout of the phoneView tab
        //constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"[undo]-(sep)-[redo]-(sep)-[menu]-(sep)-|" options:0 metrics:@{@"sep":@(TAB_SEPARATION)} views:@{@"undo":self.undoButton, @"redo":self.redoButton, @"menu":self.phoneTabView} ];
        NSArray<NSLayoutConstraint *> *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"[undo]-(sep)-[redo]-(sep)-[menu]-(sep)-|" options:0 metrics:@{@"sep":@(TAB_SEPARATION)} views:@{@"undo":self.undoButton, @"redo":self.redoButton, @"menu":self.phoneTabView} ];
        [self.view addConstraints:constraints];
    }
#endif  /* RIGHT_ALIGNED_MENU */
}

- (void)movePhoneMenuToParent
{
    // Move the menu from the edit-tabs view to the doc-with-bars view
    // so that it will not get clipped and will appear over the document
    // Use the menus position within the edit-tabs view to generate
    // positioning constraints.
    if (self.phoneMenuPopup)
    {
        // get the bottom-left coordinate of the phonetabs view and use that as
        // the origin for our popup menu
        CGPoint menuOrigin = self.phoneTab.frame.origin;
        // the 5 here is an unfortunate hack required due to the 'unique' way
        // the tab element has to be taller than it should be in order to hide
        // the bottom rounded corners and border under the ribbon bar so that we
        // can show 'rounded tabs'
        menuOrigin.y += self.phoneTab.frame.size.height - 5;
        // we also appear to need to apply the leading constraint; are we
        // processing this prior to the constraints being applied?
        // surely not...
        menuOrigin.x += 8;

        [self.phoneMenuPopup removeFromSuperview];
        [self.docWithUIViewContoller.view addSubview:self.phoneMenuPopup];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ( @available(iOS 11.0, *))
        {
            // topLayoutGuide is deprecated in iOS 11.0 SDK, using safeAreaLayoutGuide and anchors instead
            NSMutableArray<NSLayoutConstraint *> *constraintArray = [[NSMutableArray alloc] init];
            
            NSLayoutConstraint *leadingConstraint = [self.phoneMenuPopup.leadingAnchor constraintEqualToAnchor:self.docWithUIViewContoller.view.safeAreaLayoutGuide.leadingAnchor
                                                                                                      constant:menuOrigin.x];
            leadingConstraint.active = YES;
            [constraintArray addObject:leadingConstraint];
            
            NSLayoutConstraint *topConstraint = [self.phoneMenuPopup.topAnchor constraintEqualToAnchor:self.docWithUIViewContoller.view.safeAreaLayoutGuide.topAnchor
                                                                                              constant:menuOrigin.y];
            topConstraint.active = YES;
            [constraintArray addObject:topConstraint];
            
            self.menuConstraints = constraintArray;
        }
        else
        {
            id topLayoutGuide = self.docWithUIViewContoller.topLayoutGuide;

            NSArray<NSLayoutConstraint *> *horz = [NSLayoutConstraint constraintsWithVisualFormat:@"|-x-[menu]" options:0 metrics:@{@"x":@(menuOrigin.x)} views:@{@"menu":self.phoneMenuPopup}];
            NSArray<NSLayoutConstraint *> *vert = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[topLayoutGuide]-y-[menu]" options:0 metrics:@{@"y":@(menuOrigin.y)} views:@{@"topLayoutGuide":topLayoutGuide, @"menu":self.phoneMenuPopup}];
            
            NSMutableArray<NSLayoutConstraint *> *allConstraints = [horz mutableCopy];
            [allConstraints addObjectsFromArray:vert];
            
            self.menuConstraints = allConstraints;
        }
#pragma clang diagnostic pop
    }
}

/// Query the user if they try and close a document with unsaved modifications
- (void)showSaveQuery:(nullable OnClosedHandler) onClosedHandler
{
    UIAlertController *alert;
    UIAlertAction *alertAction;

    alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"There are unsaved changes",
                                                                          @"Title of dialog warning of unsaved changes when closing a document")
                                                message:NSLocalizedString(@"Would you like to continue editing, save your changes or discard your changes?",
                                                                          @"Message of dialog warning of unsaved changes when closing a document")
                                         preferredStyle:UIAlertControllerStyleAlert];



    // Block executed if user cancels operation
    // (defined as local property to avoid duplication)
    void (^cancellationHandler)(UIAlertAction*) = ^(UIAlertAction *action) {
        if (onClosedHandler)
            onClosedHandler(NO);
    };

    BOOL docExpired = NO;
    if ( self.docWithUI.session.docSettings.expiresDate != nil )
    {
        NSTimeInterval interval;
        interval = [self.docWithUI.session.docSettings.expiresDate timeIntervalSinceNow];
        docExpired = (interval <= 0);
    }
    if ( !docExpired )
    {
        alertAction = [UIAlertAction
                       actionWithTitle:NSLocalizedString(@"Continue editing",
                                                         @"Label for continue with editing button")
                       style:UIAlertActionStyleCancel
                       handler:cancellationHandler];
        [alert addAction:alertAction];
    }

    alertAction = [UIAlertAction
                   actionWithTitle:NSLocalizedString(@"Save",
                                                     @"Label for save changes button")
                   style:UIAlertActionStyleDefault
                   handler:^(UIAlertAction *action) {
                       [self.docWithUI presaveCheckFrom:self onSuccess:^{
                           if (self.docWithUI.session.fileState.isReadonly)
                           {
                               // With a readonly path, we cannot save back to the original file
                               // so open a saveAs dialog
                               [self.docWithUI callSaveAsHandler:self];
                           }
                           else
                           {
                               // Save: start the saving process and close the document on completion.
                               __weak typeof(self) weakSelf = self;
                               [self.docWithUI.session saveDocumentAndOnCompletion:^(ARDKSaveResult result, SOError err) {
                                   switch (result)
                                   {
                                       case ARDKSave_Succeeded:
                                           if (onClosedHandler) onClosedHandler(YES);
                                           [weakSelf performSegueWithIdentifier:@"closeDocument" sender:nil];
                                           break;

                                       case ARDKSave_Cancelled:
                                       case ARDKSave_Error:
                                       {
                                           [weakSelf.activityIndicator hideActivityIndicator];

                                           NSString *msg = NSLocalizedString(@"Saving the file failed.\nError code SO%@",
                                                                             @"Message for dialog warning the user the document could not be saved");
                                           msg = [NSString stringWithFormat:msg, [NSNumber numberWithInt:err]];
                                           UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"File could not be saved",
                                                                                                                                    @"Title for dialog warning the user the document could not be saved")
                                                                                                          message:msg
                                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                                           UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil) style:UIAlertActionStyleDefault handler:cancellationHandler];
                                           [alert addAction:defaultAction];
                                           [weakSelf presentViewController:alert animated:YES completion:nil];
                                           break;
                                       }
                                   }
                               }];

                               // Display a busy indicator
                               [self.activityIndicator showActivityIndicator];
                           }
                       }];
                   }];
    [alert addAction:alertAction];

    alertAction = [UIAlertAction
                   actionWithTitle:NSLocalizedString(@"Discard",
                                                     @"Label for discard changes button")
                   style:UIAlertActionStyleDestructive
                   handler:^(UIAlertAction *action) {
                       // Discard: just continue the back-button action
                       if (onClosedHandler) onClosedHandler(YES);
                       [self performSegueWithIdentifier:@"closeDocument" sender:nil];
                   }];
    [alert addAction:alertAction];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Navigation

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller
{
    return UIModalPresentationNone;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"embedRibbonContainer"])
    {
        self.container = segue.destinationViewController;
        self.container.docWithUI = self.docWithUI;
        self.container.activityIndicator = self.activityIndicator;
    }
}

- (void)closeDocument:(void (^)(BOOL))onCompletion {
    OnClosedWrapper* wrapper = [[OnClosedWrapper alloc] init];
    wrapper.handler = onCompletion;

    if ([self shouldPerformSegueWithIdentifier:@"closeDocument" sender: wrapper]) {
        // Since we can proceed to save the document, execute closure
        onCompletion(YES);
        [self performSegueWithIdentifier:@"closeDocument" sender: nil];
    };
}


- (void)documentWillClose
{
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    BOOL performSegue = YES;

    if ([identifier isEqualToString:@"closeDocument"])
    {
        [self documentWillClose];

        if (self.docWithUI.session.documentHasBeenModified && self.docWithUI.session.docSettings.editingEnabled)
        {
            if (self.docWithUI.saveAsHandler)
            {
                // the "showSaveQuery" method uses the "saveAsHandler"
                // defined in "self.docWithUI"

                OnClosedHandler handler = nil;
                if ([sender isKindOfClass:[OnClosedWrapper class]]) {
                    handler = ((OnClosedWrapper *)sender).handler;
                }
                [self showSaveQuery:handler];
                performSegue = NO;
            }
            else if ( self.docWithUI.saveToHandler)
            {
                // the "showSaveQuery" method uses the "saveAsHandler" in
                // defined in "self.docWithUI", if there isn't one defined,
                // but there is a "saveToHandler" defined we call it
                // instead to handle presentation of a document
                // "Save/Discard/Continue" dialog when the user
                // tries to close a document here.
                [self.docWithUI callSaveToHandler:self
                                        fromButton:nil];
                performSegue = NO;
            }
        }
    }

    return performSegue;
}

@end
