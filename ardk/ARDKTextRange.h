//
//  ARDKTextRange.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 25/08/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ARDKTextRange : UITextRange
@property(readonly) NSRange nsRange;

+ (instancetype)range:(NSRange)nsRange;

@end
