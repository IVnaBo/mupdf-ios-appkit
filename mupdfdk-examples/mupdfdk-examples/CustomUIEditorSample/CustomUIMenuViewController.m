// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "CustomUIMenuViewController.h"

@interface CustomUIMenuViewController ()
@end

@implementation CustomUIMenuViewController

- (IBAction)doneButtonWasTapped:(id)sender
{
    [self.mainViewController dismissMenu];
}

@end
