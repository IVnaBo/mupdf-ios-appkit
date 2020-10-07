// Copyright © 2018 Artifex Software Inc. All rights reserved.

#import "ARDKTextSelectionRect.h"

@implementation ARDKTextSelectionRect

@synthesize rect=_rect, writingDirection=_writingDirection, isVertical=_isVertical,
containsStart=_containsStart, containsEnd=_containsEnd;

+ (instancetype)selectionRect:(CGRect)rect start:(BOOL)start end:(BOOL)end
{
    ARDKTextSelectionRect *sr = [[ARDKTextSelectionRect alloc] init];

    if (sr)
    {
        sr->_rect = rect;
        sr->_writingDirection = UITextWritingDirectionLeftToRight;
        sr->_isVertical = NO;
        sr->_containsStart = start;
        sr->_containsEnd = end;
    }

    return sr;
}

@end
