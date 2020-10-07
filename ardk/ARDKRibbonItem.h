//
//  ARDKRibbonItem.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 28/02/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ARDKRibbonItem : NSObject
@property UIView *view;
@property CGFloat leftMargin;
@property CGFloat rightMargin;
@property CGFloat topMargin;
@property CGFloat bottomMargin;

- (void)addToSuperView:(UIView *)superView nextTo:(ARDKRibbonItem *)lastItem;

- (void)markAsLast;

- (void)updateUI;

@end
