// Copyright © 2020 Paul Gardiner. All rights reserved.

#import "CustomUIAddAreaRedactionViewController.h"

@interface CustomUIAddAreaRedactionViewController ()

@end

@implementation CustomUIAddAreaRedactionViewController

- (void)onIn
{
    [super onIn];

    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_RedactionAreaSelect;
    [self.doc clearSelection];
}

- (void)onOut
{
    [super onOut];

    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_EditRedaction;
}

- (void)updateUI
{
    [super updateUI];

    // When the user selects text and creates a highligth annotation, the mode
    // reverts to None. We detect that and pop back the main annotation menu
    if (self.docViewController.annotatingMode != MuPDFDKAnnotatingMode_RedactionAreaSelect)
    {
        [self.navigationController popViewControllerAnimated:YES];
    }

}

- (void)barWillClose
{
    [super barWillClose];

    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_EditRedaction;
}

@end
