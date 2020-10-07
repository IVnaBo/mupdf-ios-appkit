// Copyright © 2019 Artifex Software Inc. All rights reserved.

#import "ARDKUIDimensions.h"
#import "MuPDFDKPagesRibbonViewController.h"

#define MENU_BUTTON_COLOR   0x000000
#define MENU_RIBBON_COLOR   0xEBEBEB

@interface MuPDFDKPagesRibbonViewController ()
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIButton *lastPageButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *defaultButtonWidth;
@property (weak, nonatomic) IBOutlet UIButton *previousLinkButton;
@property (weak, nonatomic) IBOutlet UIButton *nextLinkButton;

@end

@implementation MuPDFDKPagesRibbonViewController

@synthesize activityIndicator, docWithUI;

- (void)updateUI
{
    [self.view layoutIfNeeded];

    self.lastPageButton.enabled = self.docWithUI.doc.loadingComplete;
    self.previousLinkButton.enabled = self.docWithUI.docView.viewingStatePreviousAllowed;
    self.nextLinkButton.enabled = self.docWithUI.docView.viewingStateNextAllowed;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (IBAction)firstPageButtonWasTapped:(id)sender
{
    [self.docWithUI.docView showPage:0];
}

- (IBAction)lastPageButtonWasTapped:(id)sender
{
    [self.docWithUI.docView showEndOfPage:docWithUI.doc.pageCount - 1];
}

- (IBAction)previousLinkButtonWasTapped:(id)sender
{
    [self.docWithUI.docView viewingStatePrevious];
}

- (IBAction)nextLinkButtonWasTapped:(id)sender
{
    [self.docWithUI.docView viewingStateNext];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.defaultButtonWidth.constant = [ARDKUIDimensions defaultRibbonButtonWidth];
    [self updateUI];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.scrollView layoutIfNeeded];
    [self.docWithUI setRibbonHeight:self.scrollView.contentSize.height];
}

@end
