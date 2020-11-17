//  Copyright © 2018-2020 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>

@interface ARDKButton : UIButton 
@property(nullable) IBInspectable NSString *backgroundColorNameWhenSelected;
@property(nullable) IBInspectable NSString *tintColorNameWhenSelected;
@property(nullable) IBInspectable NSString *backgroundColorNameWhenUnselected;
@property(nullable) IBInspectable NSString *tintColorNameWhenUnselected;

@end
