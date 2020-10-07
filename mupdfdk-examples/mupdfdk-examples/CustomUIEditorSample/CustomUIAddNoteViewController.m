// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "CustomUIAddNoteViewController.h"

@interface CustomUIAddNoteViewController ()

@end

@implementation CustomUIAddNoteViewController

- (void)onIn
{
    [super onIn];

    // Put the document view into note-annotation-creation mode,
    // so that user taps on a page will create note annotations.
    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_Note;
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

    // When the user taps the page and creates a note annotation, the mode
    // reverts to None. We detect that and pop back to the main annotation
    // menu
    if (self.docViewController.annotatingMode != MuPDFDKAnnotatingMode_Note)
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
