//
//  CALayer+ARDKAdditions.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 27/07/2015.
//  Copyright (c) 2015 Artifex Software Inc. All rights reserved.
//

#import "CALayer+ARDKAdditions.h"

@implementation CALayer (SODKAdditions)

- (void)setSodkBorderUIColor:(UIColor *)color
{
    self.borderColor = color.CGColor;
}

@end
