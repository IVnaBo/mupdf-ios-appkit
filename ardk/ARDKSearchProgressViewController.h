//
//  ARDKSearchProgressViewController.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 05/08/2015.
//  Copyright (c) 2015 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ARDKSearchProgressViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

+ (instancetype)progressIndicator;

@end
