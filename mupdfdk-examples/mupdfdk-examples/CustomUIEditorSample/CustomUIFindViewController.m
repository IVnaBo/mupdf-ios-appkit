// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "CustomUIFindViewController.h"

@interface CustomUIFindViewController () < UITextFieldDelegate>
@property UITextField *textField;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *searchBackButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *searchForwardButton;
@property BOOL searchInProgress;
@end

@implementation CustomUIFindViewController

- (void)onIn
{
    [super onIn];

    self.textField = [[UITextField alloc] init];
    self.textField.layer.borderWidth = 1;
    self.textField.layer.cornerRadius = 5;
    self.textField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.textField.widthAnchor constraintEqualToConstant:200].active = YES;
    self.navigationItem.titleView = self.textField;
    self.textField.delegate = self;
}

- (void)onOut
{
    [super onOut];

    [self.doc cancelSearch];
    [self.doc closeSearch];
}

- (void)barWillClose
{
    [super barWillClose];

    [self.doc cancelSearch];
    [self.doc closeSearch];
}

- (void)updateUI
{
    [super updateUI];

    BOOL haveText = self.textField.text.length > 0;
    self.searchBackButton.enabled = haveText && !self.searchInProgress;
    self.searchForwardButton.enabled = haveText && !self.searchInProgress;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self.textField becomeFirstResponder];
    [self.doc setSearchStartPage:self.docViewController.currentPage offset:CGPointZero];
}

- (void)searchInDirection:(MuPDFDKSearchDirection)direction
{
    NSString *text = self.textField.text;
    __weak typeof(self) weakSelf = self;

    if (text.length == 0)
        return;

    [self.doc searchFor:text inDirection:direction onEvent:^(MuPDFDKSearchEvent event, NSInteger page, CGRect area) {
        switch (event)
        {
            case MuPDFDKSearch_Progress:
                // If we had a progress indicator, we could set it here according
                // to where page is between 0 and self.doc.pageCount
                break;

            case MuPDFDKSearch_Found:
                weakSelf.searchInProgress = NO;
                [weakSelf updateUI];
                // Pan to show the found occurence
                [weakSelf.docViewController showArea:area onPage:page];
                break;

            case MuPDFDKSearch_NotFound:
                weakSelf.searchInProgress = NO;
                [weakSelf updateUI];
                // Could ask the user here whether to restart the search from
                // the start of the document
                break;

            case MuPDFDKSearch_Cancelled:
                weakSelf.searchInProgress = NO;
                [weakSelf updateUI];
                break;

            case MuPDFDKSearch_Error:
                weakSelf.searchInProgress = NO;
                [weakSelf updateUI];
                break;
        }
    }];

    self.searchInProgress = YES;
    [self updateUI];
}

- (IBAction)searchBackButtonWasTapped:(id)sender
{
    [self searchInDirection:MuPDFDKSearch_Backwards];
}

- (IBAction)searchForwardButtonWasTapped:(id)sender
{
    [self searchInDirection:MuPDFDKSearch_Forwards];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self searchInDirection:MuPDFDKSearch_Forwards];

    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    [self updateUI];

    return YES;
}

@end
