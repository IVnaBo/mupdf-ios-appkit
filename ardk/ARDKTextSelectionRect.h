// Copyright © 2018 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>

@interface ARDKTextSelectionRect : UITextSelectionRect

+ (instancetype)selectionRect:(CGRect)rect start:(BOOL)start end:(BOOL)end;

@end
