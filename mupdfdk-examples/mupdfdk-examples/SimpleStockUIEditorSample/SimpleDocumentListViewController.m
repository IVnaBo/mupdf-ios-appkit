// Copyright © 2020 Paul Gardiner. All rights reserved.

#import "mupdfdk/mupdfdk.h"
#import "SimpleDocumentListViewController.h"

@interface SimpleDocumentListViewController ()

@end

@implementation SimpleDocumentListViewController

- (void)documentSelected:(NSString *)documentPath
{
    ARDKDocumentViewController *vc = [MuPDFDKDocumentViewController viewControllerForFilePath:documentPath openOnPage:0];
    [self.navigationController pushViewController:vc animated:YES];
}

/// Triggered by the user pressing the 'back' button in the MuPDF UI.
///
/// The implementation can be left empty, but this function MUST be present
/// in the view controller that should be unwound back to - otherwise nothing
/// will happen when the user clicks the back button.
- (IBAction)sodk_unwindAction:(UIStoryboardSegue *)sender
{
}

@end
