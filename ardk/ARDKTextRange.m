//
//  ARDKTextRange.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 25/08/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "ARDKTextPosition.h"
#import "ARDKTextRange.h"

@implementation ARDKTextRange

+ (instancetype)range:(NSRange)nsRange
{
    if (nsRange.location == NSNotFound)
        return nil;

    ARDKTextRange *r = [[ARDKTextRange alloc]init];
    if (r != nil)
        r->_nsRange = nsRange;
    return r;
}

- (UITextPosition *)start
{
    return [ARDKTextPosition position:_nsRange.location];
}

- (UITextPosition *)end
{
    return [ARDKTextPosition position:_nsRange.location + _nsRange.length];
}

- (BOOL)isEmpty
{
    return _nsRange.length == 0;
}

@end
