// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "CustomUIAddInkViewController.h"

@interface CustomUIAddInkViewController ()
@end

@implementation CustomUIAddInkViewController

- (void)onIn
{
    [super onIn];

    // Set the annotating mode to Draw, so that user finger drags will
    // draw arcs rather than pan the document
    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_Draw;
    [self.doc clearSelection];
}

- (void)onOut
{
    [super onOut];

    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_None;
}

- (void)barWillClose
{
    [super barWillClose];
    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_None;
}

- (IBAction)applyButtonWasTapped:(id)sender
{
    // Change mode to None so as to fix the current ink drawing in the
    // document, and change back to Draw ready to create a new one.
    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_None;
    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_Draw;
}

- (IBAction)clearButtonWasTapped:(id)sender
{
    [self.docViewController clearInkAnnotation];
}

@end
