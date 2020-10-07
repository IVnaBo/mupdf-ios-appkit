//
//  ARDKButton
//  smart-office-nui
//
//  Copyright © 2018 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ARDKButton : UIButton 
@property IBInspectable NSString *backgroundColorNameWhenSelected;
@property IBInspectable NSString *tintColorNameWhenSelected;
@property IBInspectable NSString *backgroundColorNameWhenUnselected;
@property IBInspectable NSString *tintColorNameWhenUnselected;

@end
