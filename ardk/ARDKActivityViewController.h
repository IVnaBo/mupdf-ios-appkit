//
//  ARDKActivityViewController.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 12/05/2015.
//  Copyright (c) 2015 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ARDKActivityViewController : UIViewController

+ (instancetype)activityIndicatorWithin:(UIView *)view;

- (void)remove;

@end
