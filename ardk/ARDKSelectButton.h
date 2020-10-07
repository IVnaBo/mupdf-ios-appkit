//
//  ARDKSelectButton.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 12/01/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ARDKSelectButton : UIButton
@property UIColor *backgroundColorWhenSelected;
@property UIColor *tintColorWhenSelected;
@property IBInspectable NSString *backgroundColorNameWhenSelected;
@property IBInspectable NSString *tintColorNameWhenSelected;
@property IBInspectable NSString *tintColorNameWhenUnselected;
@end
