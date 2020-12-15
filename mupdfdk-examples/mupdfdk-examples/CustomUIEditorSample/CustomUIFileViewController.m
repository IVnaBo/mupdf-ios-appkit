// Copyright © 2020 Paul Gardiner. All rights reserved.

#import "CustomUIFileViewController.h"

@interface CustomUIFileViewController ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;
@end

@implementation CustomUIFileViewController

- (void)requestFileName:(void (^)(NSString *fileName))block
{
    NSString *currentFileName = self.session.fileState.displayPath.lastPathComponent;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"New file name" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = currentFileName;
    }];
    UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        block(alert.textFields[0].text);
    }];
    [alert addAction:saveAction];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        block(nil);
    }];
    [alert addAction:cancelAction];
    [self.mainViewController presentViewController:alert animated:YES completion:nil];
}

- (void)updateUI
{
    [super updateUI];

    self.saveButton.enabled = self.session.documentHasBeenModified;
}

- (IBAction)saveButtonWasTapped:(id)sender
{
    [self.session saveDocumentAndOnCompletion:^(ARDKSaveResult result, ARError err) {
        [self updateUI];
        switch (result)
        {
            case ARDKSave_Succeeded:
                break;

            case ARDKSave_Cancelled:
            case ARDKSave_Error:
                NSLog(@"Save failed with error: %d", err);
                break;
        }
    }];
}

- (IBAction)saveAsButtonWasTapped:(id)sender
{
    [self requestFileName:^(NSString *fileName) {
        NSString *newPath = [[self.session.fileState.absoluteInternalPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:fileName];
        [self.session saveTo:newPath completion:^(ARDKSaveResult res, ARError err) {
            switch (res)
            {
                case ARDKSave_Succeeded:
                    break;

                case ARDKSave_Cancelled:
                case ARDKSave_Error:
                    NSLog(@"Save failed with error: %d", err);
                    break;
            }
        }];
    }];
}

- (IBAction)printButtonWasTapped:(id)sender
{
    UIPrintInteractionController *printController = [UIPrintInteractionController sharedPrintController];
    ARDKPrintPageRenderer *pageRenderer = [[ARDKPrintPageRenderer alloc] initWithDocument:self.doc];
    printController.printPageRenderer = pageRenderer;
    printController.delegate = pageRenderer;

    [printController presentAnimated:YES completionHandler:^(UIPrintInteractionController * _Nonnull printInteractionController, BOOL completed, NSError * _Nullable error) {
        if (error)
        {
            NSLog(@"Print failed due to error %@", error);
        }
    }];
}

@end
