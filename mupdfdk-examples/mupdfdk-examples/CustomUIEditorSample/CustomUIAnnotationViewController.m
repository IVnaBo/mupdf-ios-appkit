// Copyright © 2020 Paul Gardiner. All rights reserved.

#import "CustomUIAnnotationViewController.h"

@interface CustomUIAnnotationViewController ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *addNoteButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *addInkButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *addHighlightButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteAnnotationButton;
@end

@implementation CustomUIAnnotationViewController

- (void)onIn
{
    [super onIn];
}

- (void)onOut
{
    [super onOut];
}

- (void)barWillClose
{
    [super barWillClose];
}

- (void)updateUI
{
    BOOL loadingComplete = self.doc.loadingComplete;
    self.addNoteButton.enabled = loadingComplete;
    self.addInkButton.enabled = loadingComplete;
    self.addHighlightButton.enabled = loadingComplete;
    self.deleteAnnotationButton.enabled = loadingComplete && self.doc.haveAnnotationSelection;
    [super updateUI];
}

- (IBAction)addHighlightButtonWasTapped:(id)sender
{
    if (self.doc.haveTextSelection)
    {
        [self.doc addHighlightAnnotationLeaveSelected:NO];
    }
    else
    {
        [self performSegueWithIdentifier:@"showAddHighlightBar" sender:self.addHighlightButton];
    }
}

- (IBAction)deleteButtonWasTapped:(id)sender
{
    [self.doc deleteSelectedAnnotation];
}

@end
