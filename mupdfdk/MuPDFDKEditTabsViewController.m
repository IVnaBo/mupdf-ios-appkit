//
//  MuPDFDKEditTabsViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 21/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKGeometry.h"
#import "MuPDFDKUI.h"
#import "MuPDFDKTocViewController.h"
#import "MuPDFDKEditTabsViewController.h"

// All localized string in this file should be obtained from the sodk framework
#undef NSLocalizedString
#define NSLocalizedString(key, comment) NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:self.class], comment)

@interface MuPDFDKEditTabsViewController () <MuPDFDKUI>
@property (weak, nonatomic) IBOutlet UIButton *tocButton;
@property (weak, nonatomic)          UIView   *tabletTabs;
@property (weak, nonatomic)          UIView   *phoneTabs;
@end

@implementation MuPDFDKEditTabsViewController

- (void)updateUI
{
    [super updateUI];
    self.tocButton.enabled = self.docWithUI.doc.toc.count > 0;
}

- (void)createTabs
{
    NSString *fileText = NSLocalizedString(@"FILE",@"Text used in tab to select file-based operations");
    NSString *pagesText = NSLocalizedString(@"PAGES",@"Text used in tab to select page-navigation operations");
    NSString *annotateText = NSLocalizedString(@"ANNOTATE",@"Text used in tab to select annotation operations");
    NSString *redactText = NSLocalizedString(@"REDACT",@"Text used in tab to select redaction operations");
    NSString *findText = NSLocalizedString(@"FIND",@"Text used in tab to select text-search operations");
    BOOL editing = self.docWithUI.session.docSettings.editingEnabled;
    BOOL pdfAnnotations = self.docWithUI.session.docSettings.pdfAnnotationsEnabled;
    BOOL pdfRedaction = self.docWithUI.session.docSettings.pdfRedactionEnabled;
    BOOL pdfRedactionAvailable = self.docWithUI.session.docSettings.pdfRedactionAvailable;

    NSMutableArray<ARDKTabDesc *> *tabs = [NSMutableArray array];
    NSMutableArray<NSNumber *> *disabledTabs = [NSMutableArray array];

    [tabs addObject:[ARDKTabDesc tabDescText:fileText doing:@selector(fileTabWasTapped:)]];
    if (editing && pdfAnnotations && self.docWithUI.doc.docType == ARDKDocType_PDF)
    {
        [tabs addObject:[ARDKTabDesc tabDescText:annotateText doing:@selector(annotateTabWasTapped:)]];
    }
    if (editing && pdfRedactionAvailable && self.docWithUI.doc.docType == ARDKDocType_PDF)
    {
        ARDKTabDesc * redactTab = [ARDKTabDesc tabDescText:redactText doing:@selector(redactTabWasTapped:)];
        [tabs addObject:redactTab];
        if (!pdfRedaction) {
            [disabledTabs addObject:@([tabs indexOfObject:redactTab])];
        }
    }
    [tabs addObject:[ARDKTabDesc tabDescText:pagesText doing:@selector(pagesButtonWasTapped:)]];

    UIView *tabletTabs;
    UIView *phoneTabs;
    NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];

    self.tabletTabs = [self createTabsForTablet:tabs];
    tabletTabs = self.tabletTabs;
    tabletTabs.layer.borderColor = [UIColor colorNamed:@"so.ui.menu.border.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil].CGColor;

    // The phone UI menu also needs a FIND option
    [tabs addObject:[ARDKTabDesc tabDescText:findText doing:@selector(findButtonWasTapped:)]];
    self.phoneTabs = [self createTabsForPhone:tabs];
    phoneTabs = self.phoneTabs;
    phoneTabs.layer.borderColor = [UIColor colorNamed:@"so.ui.menu.phonetab.border.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil].CGColor;

    //Send disabled tabs as UIButton to delegate
    ARDKDocumentSettings *settings = self.docWithUI.session.docSettings;
    if (settings.featureDelegate != nil){
        NSArray<UIButton *> *allTabs = [tabletTabs.subviews arrayByAddingObjectsFromArray:phoneTabs.subviews];
        NSArray<UIButton *> *badTabs = [allTabs filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return [disabledTabs containsObject:@(((UIButton *)evaluatedObject).tag - 1)];
        }]];
        [settings.featureDelegate ardkDocumentSettings:settings didDisplayDisabledFeatures:badTabs];
    }

    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    switch (self.docWithUI.doc.docType)
    {
        case ARDKDocType_PDF:
        case ARDKDocType_EPUB:
        case ARDKDocType_FB2:
            break;
        default:
            [self.tocButton removeFromSuperview];
            break;
    }
}

- (IBAction)tocButtonWasTapped:(id)sender
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"mupdfcallouts" bundle:[NSBundle bundleForClass:self.class]];
    MuPDFDKTocViewController *tvc = [sb instantiateViewControllerWithIdentifier:@"toc"];
    tvc.docWithUI = self.docWithUI;
    CGSize preferredSize = ARCGSizeScale(self.docWithUIViewContoller.view.bounds.size, 0.5);
    tvc.preferredContentSize = preferredSize;
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
        tvc.modalPresentationStyle = UIModalPresentationPopover;
    else
        tvc.modalPresentationStyle = UIModalPresentationFullScreen;
    tvc.popoverPresentationController.backgroundColor = tvc.view.backgroundColor;
    [self presentViewController:tvc animated:YES completion:nil];
    UIPopoverPresentationController *pop = tvc.popoverPresentationController;
    // Make the Toc view controller its own popover presentation controller
    // so that it gets told whether it is being presented that way or not
    // and can adjust behaviour accordingly.
    pop.delegate = tvc;
    pop.sourceView = self.tocButton;
    pop.sourceRect = self.tocButton.bounds;
}

- (IBAction)fullScreenButtonWasTapped:(id)sender
{
    if (!self.docWithUI.fullScreenMode)
    {
        self.docWithUI.fullScreenMode = YES;
        [self.docWithUI.docView endTextWidgetEditing];
        self.docWithUI.docView.annotatingMode = MuPDFDKAnnotatingMode_None;
        [self.docWithUI.doc clearSelection];
    }
}

- (IBAction)fileTabWasTapped:(id)sender
{
    [self updateSelection:((UIView *)sender).tag];
    [self.container requestSegue:@"file"];
    self.docWithUI.pagesViewIsVisible = NO;
}

- (IBAction)annotateTabWasTapped:(id)sender
{
    [self updateSelection:((UIView *)sender).tag];
    [self.container requestSegue:@"annotate"];
    self.docWithUI.pagesViewIsVisible = NO;
}

- (IBAction)redactTabWasTapped:(id)sender
{
    [self updateSelection:((UIView *)sender).tag];
    [self.container requestSegue:@"redact"];
    self.docWithUI.pagesViewIsVisible = NO;
}

- (IBAction)pagesButtonWasTapped:(id)sender
{
    [self updateSelection:((UIView *)sender).tag];
    [self.container requestSegue:@"pages"];
    self.docWithUI.pagesViewIsVisible = YES;
    self.docWithUI.recordViewedPageTrack = YES;
}

- (IBAction)findButtonWasTapped:(id)sender
{
    [self updateSelection:((UIView *)sender).tag];
    [self.container requestSegue:@"find"];
    self.docWithUI.pagesViewIsVisible = NO;
}

- (void)documentWillClose
{
    [super documentWillClose];

    // Finalize and remove text widget if present
    [self.docWithUI.docView endTextWidgetEditing];

    // There may be an ink annotation drawn but not committed to the document. Ensure it is.
    self.docWithUI.docView.annotatingMode = MuPDFDKAnnotatingMode_None;
    [self updateUI];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
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
            CGColorRef cgTableColor = [UIColor colorNamed:@"so.ui.menu.border.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil].CGColor;
            CGColorRef cgPhoneColor = [UIColor colorNamed:@"so.ui.menu.phonetab.border.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil].CGColor;
            if ( self.tabletTabs != nil )
                self.tabletTabs.layer.borderColor = cgTableColor;
            if ( self.phoneTabs != nil )
                self.phoneTabs.layer.borderColor = cgPhoneColor;
        }
    }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 */
}

@end
