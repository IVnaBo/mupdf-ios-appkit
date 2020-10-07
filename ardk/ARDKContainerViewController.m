//
//  ARDKContainerViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 22/12/2015.
//  Copyright © 2015 Artifex Software Inc. All rights reserved.
//

#import "ARDKContainerViewController.h"

@interface ARDKContainerViewController ()
@property NSString *requestedSegue;
@property UIViewController *requestedChild;
@property BOOL busy;
@end

@implementation ARDKContainerViewController

- (void)transitioningToChild:(UIViewController *)child
{
}

- (void)transitionToChild:(UIViewController *)child
{
    self.requestedChild = nil;
    self.busy = YES;

    [self transitioningToChild:child];
    if (self.childViewControllers.count == 0)
    {
        [self addChildViewController:child];
        child.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
        [self.view addSubview:child.view];
        [child didMoveToParentViewController:self];
        self.busy = NO;
    }
    else
    {
        UIViewController *currentViewController = self.childViewControllers[0];
        [currentViewController willMoveToParentViewController:nil];
        child.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
        [self addChildViewController:child];
        [self transitionFromViewController:currentViewController toViewController:child duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:nil completion:^(BOOL finished)
        {
            [currentViewController removeFromParentViewController];
            [child didMoveToParentViewController:self];

            self.busy = NO;
            if (self.requestedChild)
                [self transitionToChild:self.requestedChild];
        }];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    self.requestedSegue = segue.identifier;
    self.requestedChild = segue.destinationViewController;
    if (!self.busy)
        [self transitionToChild:self.requestedChild];
}

- (void)requestSegue:(NSString *)segue
{
    if (![self.requestedSegue isEqualToString:segue])
        [self performSegueWithIdentifier:segue sender:nil];
}

- (void)requestChild:(UIViewController *)child
{
    self.requestedSegue = nil;
    self.requestedChild = child;
    if (!self.busy)
        [self transitionToChild:self.requestedChild];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
