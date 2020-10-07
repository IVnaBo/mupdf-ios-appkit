//
//  ARDKUIContainerViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 13/01/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "ARDKUIContainerViewController.h"

#define MENU_BUTTON_COLOR   0x000000

@interface ARDKUIContainerViewController ()
@property id<ARDKUI> child;
@end

@implementation ARDKUIContainerViewController

@synthesize docWithUI, activityIndicator;

- (void)viewDidLoad {
    // the ribbon view tint will be applied to all contained buttons
    self.view.tintColor = [self.docWithUI.session.uiTheme getUIColor:@"so.ui.menu.button.color"
                                                     fallback:MENU_BUTTON_COLOR];
    [self.view setNeedsLayout];
    [self.view layoutSubviews];
}

- (void)updateUI
{
    [self.child updateUI];
}

- (void)transitioningToChild:(UIViewController *)child
{
    self.child = (id<ARDKUI>)child;
    self.child.docWithUI = self.docWithUI;
    self.child.activityIndicator = self.activityIndicator;
}

@end
