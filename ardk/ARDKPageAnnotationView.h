//
//  ARDKPageAnnotationView.h
//  smart-office-nui
//
//  Created by Joseph Heenan on 15/02/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ARDKPageAnnotationView : UIView
@property CGFloat scale;
@property UIColor *inkAnnotationColor;
@property CGFloat inkAnnotationThickness;
@property(readonly) NSArray<NSArray<NSValue *> *> *path;

- (void)clearInkAnnotation;

- (instancetype)initWithColor:(UIColor *)color andThickness:(CGFloat)thickness;

@end
