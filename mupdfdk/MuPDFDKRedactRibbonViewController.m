// Copyright © 2019 Artifex Software Inc. All rights reserved.

#import "ARDKUIDimensions.h"
#import "MuPDFDKRedactRibbonViewController.h"

#define MENU_BUTTON_COLOR   0x000000
#define MENU_RIBBON_COLOR   0xEBEBEB

#define NSLocalizedString2(key, comment) NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:self.class], comment)

@interface MuPDFDKRedactRibbonViewController ()
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *defaultButtonWidth;
@property (weak, nonatomic) IBOutlet UIButton *markButton;
@property (weak, nonatomic) IBOutlet UIView *markTextHighlight;
@property (weak, nonatomic) IBOutlet UIButton *markAreaButton;
@property (weak, nonatomic) IBOutlet UIView *markAreaHighlight;
@property (weak, nonatomic) IBOutlet UIButton *applyButton;
@property (weak, nonatomic) IBOutlet UIButton *removeButton;
@end

@implementation MuPDFDKRedactRibbonViewController

@synthesize activityIndicator, docWithUI;

- (void)updateUI
{
    [self.view layoutIfNeeded];

    BOOL loadingComplete = self.docWithUI.doc.loadingComplete;
    BOOL markingArea = (self.docWithUI.docView.annotatingMode == MuPDFDKAnnotatingMode_RedactionAreaSelect);
    BOOL markingText = (self.docWithUI.docView.annotatingMode == MuPDFDKAnnotatingMode_RedactionTextSelect);
    BOOL marking = (markingArea || markingText);
    self.markButton.enabled = loadingComplete;
    self.markAreaButton.enabled = loadingComplete;
    self.applyButton.enabled = loadingComplete && !marking && self.docWithUI.doc.hasRedactions;
    self.removeButton.enabled = loadingComplete && !marking && self.docWithUI.doc.selectionIsRedaction;
    self.markAreaHighlight.hidden = !markingArea;
    self.markTextHighlight.hidden = !markingText;
}

- (IBAction)markButtonWasTapped:(id)sender
{
    if ([self isFeatureDisabled:sender])
        return;

    if (self.docWithUI.doc.haveTextSelection)
    {
        [self.docWithUI.doc addRedactAnnotation];
        [self.docWithUI.doc clearSelection];
        [self updateUI];
    }
    else
    {
        if (self.docWithUI.docView.annotatingMode != MuPDFDKAnnotatingMode_RedactionTextSelect)
            self.docWithUI.docView.annotatingMode = MuPDFDKAnnotatingMode_RedactionTextSelect;
        else
            self.docWithUI.docView.annotatingMode = MuPDFDKAnnotatingMode_EditRedaction;

        [self.docWithUI.doc clearSelection];
        [self updateUI];
    }
}

- (IBAction)markAreaButtonWasTapped:(id)sender
{
    if ([self isFeatureDisabled:sender])
        return;

    if (self.docWithUI.docView.annotatingMode != MuPDFDKAnnotatingMode_RedactionAreaSelect)
        self.docWithUI.docView.annotatingMode = MuPDFDKAnnotatingMode_RedactionAreaSelect;
    else
        self.docWithUI.docView.annotatingMode = MuPDFDKAnnotatingMode_EditRedaction;

    [self.docWithUI.doc clearSelection];
    [self updateUI];
}

- (IBAction)applyButtonWasTapped:(id)sender
{
    if ([self isFeatureDisabled:sender])
        return;

    NSString *message = NSLocalizedString2(@"Applying redactions cannot be undone. Do you want to continue?",
                                           @"Warning when user attempts to apply the marked redactions.");
    NSString *continueLabel = NSLocalizedString2(@"Continue",
                                                 @"Button label");
    NSString *cancelLabel = NSLocalizedString2(@"Cancel",
                                               @"Button label");
    __weak typeof(self) weakSelf = self;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *continueAction = [UIAlertAction actionWithTitle:continueLabel style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self.activityIndicator showActivityIndicator];
        [self.docWithUI.doc clearSelection];
        [self.docWithUI.doc finalizeRedactAnnotations:^{
            [weakSelf.activityIndicator hideActivityIndicator];
        }];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelLabel style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:continueAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)isFeatureDisabled:(UIButton *)sender
{
    // Check if feature is enabled on doc settings first, if not notify delegate and return
    ARDKDocumentSettings *settings = (ARDKDocumentSettings *)self.docWithUI.session.docSettings;
    if(!settings.pdfRedactionEnabled && settings.featureDelegate)
    {
        [settings.featureDelegate ardkDocumentSettings:settings pressedDisabledFeature:sender atPosition:CGPointZero];
        return YES;
    }

    return NO;
}

- (IBAction)removeButtonWasTapped:(id)sender
{
    if ([self isFeatureDisabled:sender])
        return;

    [self.docWithUI.doc deleteSelectedAnnotation];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.defaultButtonWidth.constant = [ARDKUIDimensions defaultRibbonButtonWidth];
    self.docWithUI.docView.annotatingMode = MuPDFDKAnnotatingMode_EditRedaction;
    [self updateUI];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // Set the annotating mode back to None. One side effect
    // of this is that any draw annomation in progress gets
    // committed to the page.
    self.docWithUI.docView.annotatingMode = MuPDFDKAnnotatingMode_None;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.scrollView layoutIfNeeded];
    [self.docWithUI setRibbonHeight:self.scrollView.contentSize.height];
}

@end
