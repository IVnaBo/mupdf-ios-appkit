//
//  ARDKStackedButton.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 15/03/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ARDKStackedButton : UIButton
@property CGFloat titleTopInset;

- (instancetype)initWithText:(NSString *)text imageName:(NSString *)imageName;
- (UIImage *)tintedImageWithColor:(UIColor *)tintColor image:(UIImage *)image;

@end
