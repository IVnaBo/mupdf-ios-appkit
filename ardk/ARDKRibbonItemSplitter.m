//
//  ARDKRibbonItemSplitter.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 01/03/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKRibbonItemSplitter.h"

#define MARGIN (8)
#define WIDTH (2)
#define COLOR (0xAAAAAA)

static UIColor *colorForHex(unsigned int hex)
{
    return [UIColor colorWithRed:(hex>>16)/255.0 green:((hex>>8)&0xff)/255.0 blue:(hex&0xff)/255.0 alpha:1.0];
}

@implementation ARDKRibbonItemSplitter

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.view = [[UIView alloc] init];
        self.view.translatesAutoresizingMaskIntoConstraints = NO;
        self.view.backgroundColor = colorForHex(COLOR);
        self.leftMargin = MARGIN;
        self.rightMargin = MARGIN;
        self.topMargin = MARGIN;
        self.bottomMargin = MARGIN;
        NSLayoutConstraint *constraint;
        constraint = [NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:WIDTH];
        [self.view addConstraint:constraint];
    }

    return self;
}

+ (ARDKRibbonItemSplitter *)item
{
    return [[ARDKRibbonItemSplitter alloc] init];
}

@end
