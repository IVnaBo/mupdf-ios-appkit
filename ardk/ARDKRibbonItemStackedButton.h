//
//  ARDKRibbonItemStackedButton.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 28/02/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKRibbonItem.h"

@interface ARDKRibbonItemStackedButton : ARDKRibbonItem
@property BOOL (^enableCondition)(void);
@property BOOL (^selectCondition)(void);
@property BOOL (^hiddenCondition)(void);

+ (ARDKRibbonItemStackedButton *)itemWithText:(NSString *)text imageName:(NSString *)imageName
                                        width:(CGFloat) width target:(id)target action:(SEL)action;

+ (ARDKRibbonItemStackedButton *)itemWithText:(NSString *)text imageName:(NSString *)imageName selectedImageName:(NSString *)selectedImageName
                                        width:(CGFloat) width target:(id)target action:(SEL)action;

@end
