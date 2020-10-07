//
//  ARDKTextPosition.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 25/08/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ARDKTextPosition : UITextPosition
@property(readonly) NSUInteger index;

+ (instancetype)position:(NSUInteger)index;

@end
