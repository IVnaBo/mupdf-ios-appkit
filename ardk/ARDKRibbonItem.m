//
//  ARDKRibbonItem.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 28/02/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKRibbonItem.h"

@implementation ARDKRibbonItem

- (void)addToSuperView:(UIView *)superView nextTo:(ARDKRibbonItem *)lastItem
{
    NSArray<NSLayoutConstraint *> *constraints;

    [superView addSubview:self.view];

    constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(top)-[me]-(bottom)-|" options:0 metrics:@{@"top":@(self.topMargin), @"bottom":@(self.bottomMargin)} views:@{@"me":self.view}];
    [superView addConstraints:constraints];

    if (lastItem)
    {
        CGFloat gap = MAX(lastItem.rightMargin, self.leftMargin);
        constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"[last]-(gap)-[me]" options:0 metrics:@{@"gap":@(gap)} views:@{@"last":lastItem.view, @"me":self.view}];
        [superView addConstraints:constraints];
    }
    else
    {
        constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|[me]" options:0 metrics:nil views:@{@"me":self.view}];
        [superView addConstraints:constraints];
    }
}

- (void)markAsLast
{
    NSArray<NSLayoutConstraint *> *constraints;
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"[me]|" options:0 metrics:nil views:@{@"me":self.view}];
    [self.view.superview addConstraints:constraints];
}

- (void)updateUI
{
}

@end
