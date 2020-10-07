// Copyright © 2017 Artifex Software Inc. All rights reserved.

#import "ARDKUIDimensions.h"
#import "MuPDFDKColorPickerViewController.h"
#import "MuPDFDKLineWidthViewController.h"
#import "MuPDFDKAnnotateRibbonViewController.h"
#import "ARDKDocTypeDetail.h"

#define MENU_BUTTON_COLOR   0x000000
#define MENU_RIBBON_COLOR   0xEBEBEB

@interface MuPDFDKAnnotateRibbonViewController () <UIAdaptivePresentationControllerDelegate>
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIButton *highlightButton;
@property (weak, nonatomic) IBOutlet UIView *highlightHighlight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *defaultButtonWidth;
@property (weak, nonatomic) IBOutlet UIView *drawHighlight;
@property (weak, nonatomic) IBOutlet UIView *noteHighlight;
@property (weak, nonatomic) IBOutlet UIButton *colorButton;
@property (weak, nonatomic) IBOutlet UIButton *thicknessButton;
@property (weak, nonatomic) IBOutlet UIButton *deleteButton;
@property (weak, nonatomic) IBOutlet UIButton *drawButton;
@property (weak, nonatomic) IBOutlet UIButton *noteButton;
@property (weak, nonatomic) IBOutlet UIButton *signatureButton;
@property (weak, nonatomic) IBOutlet UIView *signatureHighlight;
@property (weak, nonatomic) IBOutlet UIView *signatureView;
@property (weak, nonatomic) IBOutlet UIView *splitterAfterSignatureView;
@property (weak) id<MuPDFDKUI> popup;
@end

@implementation MuPDFDKAnnotateRibbonViewController

@synthesize activityIndicator, docWithUI;

- (void)updateUI
{
    NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];

    [self.view layoutIfNeeded];
    
    MuPDFDKAnnotatingMode mode = self.docWithUI.docView.annotatingMode;
    BOOL loadingComplete = self.docWithUI.doc.loadingComplete;
    self.highlightButton.enabled = loadingComplete;
    self.highlightHighlight.hidden = (mode != MuPDFDKAnnotatingMode_HighlightTextSelect);
    self.drawHighlight.hidden = (mode != MuPDFDKAnnotatingMode_Draw);
    self.noteHighlight.hidden = (mode != MuPDFDKAnnotatingMode_Note);
    self.signatureHighlight.hidden = (mode != MuPDFDKAnnotatingMode_DigitalSignature);
    self.colorButton.enabled = (mode == MuPDFDKAnnotatingMode_Draw);
    self.thicknessButton.enabled = (mode == MuPDFDKAnnotatingMode_Draw);
    self.deleteButton.enabled = loadingComplete && (mode == MuPDFDKAnnotatingMode_Draw || self.docWithUI.doc.haveAnnotationSelection);
    self.drawButton.enabled = loadingComplete;
    self.noteButton.enabled = loadingComplete;
    self.signatureButton.enabled = loadingComplete;
    
    if ( mode == MuPDFDKAnnotatingMode_Draw )
    {
        UIColor *selColor = [UIColor colorNamed:@"so.ui.menu.icontint.color.selected" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];

        self.thicknessButton.tintColor = selColor;
    }
    else
    {
        UIColor *tintColor = [UIColor colorNamed:@"so.ui.menu.ribbon.icontint" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];

        self.thicknessButton.tintColor = tintColor;
    }

    // Setting button tint color also sets the title color, so the button
    // title color should be set after setting the button tint color.
    UIColor *fontColor = [UIColor colorNamed:@"so.ui.menu.ribbon.font.color" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
    [self.drawButton setTitleColor:fontColor forState:UIControlStateNormal];
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller
{
    return UIModalPresentationNone;
}

- (IBAction)highlightButtonWasTapped:(id)sender
{
    if (self.docWithUI.doc.haveTextSelection)
    {
        [self.docWithUI.doc addHighlightAnnotationLeaveSelected:NO];
        [self updateUI];
    }
    else
    {
        if (self.docWithUI.docView.annotatingMode != MuPDFDKAnnotatingMode_HighlightTextSelect)
            self.docWithUI.docView.annotatingMode = MuPDFDKAnnotatingMode_HighlightTextSelect;
        else
            self.docWithUI.docView.annotatingMode = MuPDFDKAnnotatingMode_None;

        [self.docWithUI.doc clearSelection];
        [self updateUI];
    }
}

- (IBAction)drawButtonWasTapped:(id)sender
{
    self.docWithUI.docView.annotatingMode = (self.docWithUI.docView.annotatingMode == MuPDFDKAnnotatingMode_Draw) ? MuPDFDKAnnotatingMode_None : MuPDFDKAnnotatingMode_Draw;
    [self updateUI];
}

- (IBAction)colorButtonWasTapped:(id)sender
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"mupdfcallouts" bundle:[NSBundle bundleForClass:self.class]];
    MuPDFDKColorPickerViewController *vc = [sb instantiateViewControllerWithIdentifier:@"color-picker"];
    vc.modalPresentationStyle = UIModalPresentationPopover;
    vc.preferredContentSize = [vc.view systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    vc.docWithUI = self.docWithUI;
    self.popup = vc;
    vc.presentationController.delegate = self;
    [self presentViewController:vc animated:YES completion:nil];
    UIPopoverPresentationController *pop = vc.popoverPresentationController;
    pop.sourceView = self.colorButton;
    pop.sourceRect = self.colorButton.bounds;
    pop.permittedArrowDirections = UIPopoverArrowDirectionAny;
    pop.backgroundColor = vc.view.backgroundColor;
}

- (IBAction)thicknessButtonWasTapped:(id)sender
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"mupdfcallouts" bundle:[NSBundle bundleForClass:self.class]];
    MuPDFDKLineWidthViewController *vc = [sb instantiateViewControllerWithIdentifier:@"line-width"];
    vc.modalPresentationStyle = UIModalPresentationPopover;
    vc.preferredContentSize = [vc.view systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    vc.docWithUI = self.docWithUI;
    self.popup = vc;
    vc.presentationController.delegate = self;
    [self presentViewController:vc animated:YES completion:nil];
    UIPopoverPresentationController *pop = vc.popoverPresentationController;
    pop.sourceView = self.thicknessButton;
    pop.sourceRect = self.thicknessButton.bounds;
    pop.permittedArrowDirections = UIPopoverArrowDirectionAny;
    pop.backgroundColor = vc.view.backgroundColor;
}

- (IBAction)noteButtonWasTapped:(id)sender
{
    self.docWithUI.docView.annotatingMode = (self.docWithUI.docView.annotatingMode == MuPDFDKAnnotatingMode_Note) ? MuPDFDKAnnotatingMode_None : MuPDFDKAnnotatingMode_Note;
    [self.docWithUI.doc clearSelection];
    [self updateUI];
}

- (IBAction)deleteButonWasTapped:(id)sender
{
    if (self.docWithUI.docView.annotatingMode == MuPDFDKAnnotatingMode_Draw)
        [self.docWithUI.docView clearInkAnnotation];
    else
        [self.docWithUI.doc deleteSelectedAnnotation];
}

- (IBAction)signatureButtonWasTapped:(id)sender
{
    self.docWithUI.docView.annotatingMode = (self.docWithUI.docView.annotatingMode == MuPDFDKAnnotatingMode_DigitalSignature) ? MuPDFDKAnnotatingMode_None : MuPDFDKAnnotatingMode_DigitalSignature;
    [self.docWithUI.doc clearSelection];
    [self updateUI];
}

- (void)presentAuthorDialog
{
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"Author",
                                                                           @"Name recorded against changes made to the document")
                                message:NSLocalizedString(@"Would you like to update the author name or retain the current one?",
                                                          @"Message of dialog for viewing and updating the tracked changes author")
                                preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof (alert) weakAlert = alert;
    __weak typeof (self) weakSelf = self;

    UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"Update",
                                                                         @"Label of button for updating the author")
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action)
                         {
                             weakSelf.docWithUI.doc.documentAuthor = weakAlert.textFields[0].text;
                         }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Retain",
                                                                             @"Label of button for retaining the current author")
                                                     style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:ok];
    [alert addAction:cancel];
    if ([alert respondsToSelector:@selector(setPreferredAction:)])
    {
        /* only available >= iOS 9 */
        alert.preferredAction = ok;
    }

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = weakSelf.docWithUI.doc.documentAuthor;
    }];

    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)authorButtonWasTapped:(id)sender
{
    [self presentAuthorDialog];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.defaultButtonWidth.constant = [ARDKUIDimensions defaultRibbonButtonWidth];
    self.docWithUI.docView.annotatingMode = MuPDFDKAnnotatingMode_EditAnnotation;
    if (!self.docWithUI.session.docSettings.pdfSignatureFieldCreationEnabled)
    {
        [self.signatureView removeFromSuperview];
        [self.splitterAfterSignatureView removeFromSuperview];
    }
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
