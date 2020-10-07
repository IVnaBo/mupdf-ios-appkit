// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "CustomUIAddHighlightViewController.h"

@interface CustomUIAddHighlightViewController ()
@end

@implementation CustomUIAddHighlightViewController

- (void)onIn
{
    [super onIn];

    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_HighlightTextSelect;
    [self.doc clearSelection];
}

- (void)onOut
{
    [super onOut];

    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_None;
}

- (void)updateUI
{
    [super updateUI];

    // When the user selects text and creates a highligth annotation, the mode
    // reverts to None. We detect that and pop back the main annotation menu
    if (self.docViewController.annotatingMode != MuPDFDKAnnotatingMode_HighlightTextSelect)
    {
        [self.navigationController popViewControllerAnimated:YES];
    }

}

- (void)barWillClose
{
    [super barWillClose];

    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_None;
}

@end
