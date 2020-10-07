//
//  ARDKActivityViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 12/05/2015.
//  Copyright (c) 2015 Artifex Software Inc. All rights reserved.
//

#import "ARDKActivityViewController.h"

@interface ARDKActivityViewController ()
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@end

@implementation ARDKActivityViewController

+ (instancetype)activityIndicatorWithin:(UIView *)view
{
    ARDKActivityViewController *act = [[ARDKActivityViewController alloc] initWithNibName:@"ARDKActivityViewController" bundle:[NSBundle bundleForClass:self.class]];
    act.view.frame = CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
    [view addSubview:act.view];
    return act;
}

- (void)remove
{
    [self.view removeFromSuperview];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.activityIndicator startAnimating];
}

@end
