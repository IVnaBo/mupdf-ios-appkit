//
//  ARDKContainerViewController.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 22/12/2015.
//  Copyright © 2015 Artifex Software Inc. All rights reserved.
//

/// This class supports storyboard-driven container views with
/// multiple alternative embeddings. Multiple view controllers
/// can be connected to a view controller of this type using
/// empty segues. requestSegue is used to select which of the
/// alternatives to embed, passing the segue identifier.

#import <UIKit/UIKit.h>

@interface ARDKContainerViewController : UIViewController

- (void)requestSegue:(NSString *)segue;

- (void)requestChild:(UIViewController *)child;

- (void)transitioningToChild:(UIViewController *)child;

@end
