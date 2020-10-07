//
//  MuPDFDKFindRibbonViewController.m
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "ARDKUIDimensions.h"
#import "ARDKSearchProgressViewController.h"
#import "MuPDFDKFindRibbonViewController.h"
#import "ARDKTextField.h"
#import "ARDKDocTypeDetail.h"

#define MENU_BUTTON_COLOR   0x000000
#define MENU_RIBBON_COLOR   0xEBEBEB

// All localized string in this file should be obtained from the sodk framework
#undef NSLocalizedString
#define NSLocalizedString(key, comment) NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:self.class], comment)

@interface MuPDFDKFindRibbonViewController ()
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *defaultButtonWidth;
@property (weak, nonatomic) IBOutlet ARDKTextField *textField;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (weak, nonatomic) IBOutlet UIButton *previousButton;
@property (weak, nonatomic) IBOutlet UIView *textView;
@end

@implementation MuPDFDKFindRibbonViewController
{
    __weak MuPDFDKDocumentViewController<MuPDFDKDocViewInternal> *_uiDelegate;
}

@synthesize activityIndicator;

- (void)updateUI
{
    BOOL text_present = (self.textField.text.length > 0);
    self.nextButton.enabled = text_present;
    self.previousButton.enabled = text_present;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.textField.returnKeyType = UIReturnKeyGo;
    
    if ( [self.textField respondsToSelector:@selector(setAttributedPlaceholder:)] )
    {
        NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];

        UIColor *placeholder = [UIColor colorNamed:@"placeholder" inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        self.textField.attributedPlaceholder =
            [[NSAttributedString alloc] initWithString:self.textField.placeholder
                                            attributes:@{NSForegroundColorAttributeName: placeholder}];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    assert(self.docWithUI);
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.defaultButtonWidth.constant = [ARDKUIDimensions defaultRibbonButtonWidth];
    [self.textField becomeFirstResponder];
    [self.docWithUI.doc setSearchStartPage:self.docWithUI.docView.currentPage offset:CGPointZero];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.scrollView layoutIfNeeded];
    [self.docWithUI setRibbonHeight:self.scrollView.contentSize.height];
}

- (void)closeSearchProgress
{
    [self.activityIndicator hideProgressIndicator];
}

- (void)stopSearch
{
    [self.docWithUI.doc cancelSearch];
    [self closeSearchProgress];
    [self.activityIndicator showActivityIndicator];
}

- (void)addSearchProgress
{
    [self.activityIndicator showProgressIndicatorWithTarget:self cancelAction:@selector(stopSearch)];
}

- (void)findInDirection:(MuPDFDKSearchDirection)direcion
{
    NSString *text = self.textField.text;
    __weak typeof(self) weakSelf = self;
    if (text.length == 0)
        return;

    [self.docWithUI.doc searchFor:text inDirection:direcion
                           onEvent:^(MuPDFDKSearchEvent event, NSInteger page, CGRect area) {
        switch (event)
        {
            case MuPDFDKSearch_Progress:
                [weakSelf.activityIndicator setProgressIndicatorProgress: (float)page / (float)weakSelf.docWithUI.doc.pageCount];
                break;

            case MuPDFDKSearch_Found:
                [weakSelf closeSearchProgress];
                // Pan to show the found occurrence
                [weakSelf.docWithUI.docView showArea:area onPage:page];
                break;

            case MuPDFDKSearch_NotFound:
            {
                [weakSelf closeSearchProgress];
                [weakSelf presentContinueDialog:^(BOOL cont) {
                    if (cont)
                        [self findInDirection:direcion];
                }];
                break;
            }

            case MuPDFDKSearch_Cancelled:
                [weakSelf.activityIndicator hideActivityIndicator];
                break;

            case MuPDFDKSearch_Error:
                NSLog(@"Search error");
                [weakSelf closeSearchProgress];
                break;
        }
    }];

    [self addSearchProgress];
}

- (IBAction)nextButtonWasTapped:(id)sender
{
    [self findInDirection:MuPDFDKSearch_Forwards];
}

- (IBAction)previousButtonWasTapped:(id)sender
{
    [self findInDirection:MuPDFDKSearch_Backwards];
}

- (void)presentContinueDialog:(void (^)(BOOL cont))block
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"No more found",
                                                                                             @"The search has found no more matches")
                                                                   message:NSLocalizedString(@"Keep searching?",
                                                                                             @"Continue search by wrapping around to the start or end of the document")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"Continue",
                                                                         @"Continue searching the document")
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
                                                   block(YES);
                                               }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Stop",
                                                                             @"Stop searching the document")
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
                                                       block(NO);
                                                   }];

    [alert addAction:ok];
    [alert addAction:cancel];

    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)textFieldDidChange:(id)sender
{
    [self updateUI];
}

- (IBAction)nextKeyTapped:(id)sender
{
    [self findInDirection:MuPDFDKSearch_Forwards];
    [self.textField resignFirstResponder];
}

- (MuPDFDKDocumentViewController<MuPDFDKDocViewInternal> *)docWithUI
{
    return _uiDelegate;
}

- (void)setDocWithUI:(MuPDFDKDocumentViewController<MuPDFDKDocViewInternal> *)docWithUI
{
    _uiDelegate = docWithUI;
    self.textField.pasteboard = self.docWithUI.doc.pasteboard;
}

// The ui delegate will almost certainly be nil when this is called; we'll
// set it when the docWithUI is set instead.
- (void)setTextField:(ARDKTextField *)textField
{
    _textField = textField;
    self.textField.pasteboard = self.docWithUI.doc.pasteboard;
}

@end
