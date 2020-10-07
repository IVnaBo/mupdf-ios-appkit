//
//  ARDKTextPosition.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 25/08/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "ARDKTextPosition.h"

@implementation ARDKTextPosition

+ (instancetype)position:(NSUInteger)index
{
    ARDKTextPosition *p = [[ARDKTextPosition alloc] init];
    if (p != nil)
        p->_index = index;
    return p;
}

@end
