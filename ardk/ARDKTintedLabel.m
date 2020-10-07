//
//  ARDKTintedLabel
//
//  UILabel class with additional tint support similar to interactive classes
//  Copyright © 2018 Artifex Software Inc. All rights reserved.
//


#import "ARDKTintedLabel.h"


@implementation ARDKTintedLabel

- (void) tintColorDidChange
{
    self.textColor = self.tintColor;
}

@end
