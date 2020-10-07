// Copyright © 2020 Paul Gardiner. All rights reserved.

#import <mupdfdk/mupdfdk.h>
#import "CustomUIDocumentViewController.h"

#import "CustomUIDocumentListViewController.h"

@implementation CustomUIDocumentListViewController

- (void)documentSelected:(NSString *)documentPath
{
    CustomUIDocumentViewController *vc = [CustomUIDocumentViewController viewControllerForPath:documentPath];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)dismiss
{
    // Back to the previous view controller
    [self.navigationController popViewControllerAnimated:YES];
}


@end
