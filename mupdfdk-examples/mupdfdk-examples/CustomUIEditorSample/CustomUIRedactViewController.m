// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "CustomUIRedactViewController.h"

@interface CustomUIRedactViewController ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *areaButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *textButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *removeButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *applyButton;
@end

@implementation CustomUIRedactViewController

- (void)onIn
{
    [super onIn];

    // Setting the annotation mode ensures that only redaction annotations
    // can be selected.
    self.docViewController.annotatingMode = MuPDFDKAnnotatingMode_EditRedaction;
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

- (void)updateUI
{
    [super updateUI];

    BOOL loadingComplete = self.doc.loadingComplete;
    self.textButton.enabled = loadingComplete;
    self.removeButton.enabled = loadingComplete && self.doc.haveAnnotationSelection;
    self.applyButton.enabled = loadingComplete && self.doc.hasRedactions;
}

- (IBAction)textButtonWasTapped:(id)sender
{
    if (self.doc.haveTextSelection)
    {
        [self.doc addRedactAnnotation];
        [self.doc clearSelection];
    }
    else
    {
        [self performSegueWithIdentifier:@"showTextRedactionBar" sender:self.areaButton];
    }
}

- (IBAction)areaButtonWasTapped:(id)sender
{
    [self performSegueWithIdentifier:@"showAreaRedactionBar" sender:self.areaButton];
}

- (IBAction)removeButtonWasTapped:(id)sender
{
    [self.doc deleteSelectedAnnotation];
}

- (IBAction)applyButtonWasTapped:(id)sender
{
    [self.doc finalizeRedactAnnotations:^{
    }];
}

@end
