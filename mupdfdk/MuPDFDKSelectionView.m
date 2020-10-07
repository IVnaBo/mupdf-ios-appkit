// Copyright © 2017 Artifex Software Inc. All rights reserved.

#import "ARDKTiledLayer.h"
#import "MuPDFDKSelectionView.h"

@implementation MuPDFDKSelectionView
{
    NSArray<MuPDFDKQuad *> *_selectionQuads;
    NSArray<MuPDFDKQuad *> *_formFieldQuads;
    CGFloat _scale;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.opaque = NO;
        self.backgroundColor = UIColor.clearColor;
    }
    return self;
}

- (NSArray<MuPDFDKQuad *> *)selectionQuads
{
    return _selectionQuads;
}

- (void)setSelectionQuads:(NSArray<MuPDFDKQuad *> *)quads
{
    @synchronized(self)
    {
        _selectionQuads = quads;
    }

    [self setNeedsDisplay];
}

- (NSArray<MuPDFDKQuad *> *)formFieldQuads
{
    return _formFieldQuads;
}

- (void)setFormFieldQuads:(NSArray<MuPDFDKQuad *> *)formFieldQuads
{
    @synchronized(self)
    {
        _formFieldQuads = formFieldQuads;
    }

    [self setNeedsDisplay];
}

- (CGFloat)scale
{
    return _scale;
}

- (void)setScale:(CGFloat)scale
{
    @synchronized(self)
    {
        _scale = scale;
    }

    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    NSMutableArray<MuPDFDKQuad *> *selectionQuads;
    NSMutableArray<MuPDFDKQuad *> *formFieldQuads;
    CGFloat scale;
    @synchronized(self)
    {
        selectionQuads = [NSMutableArray arrayWithCapacity:_selectionQuads.count];
        for (MuPDFDKQuad *v in _selectionQuads)
            [selectionQuads addObject:v.copy];

        formFieldQuads = [NSMutableArray arrayWithCapacity:_formFieldQuads.count];
        for (MuPDFDKQuad *v in _formFieldQuads)
            [formFieldQuads addObject:v.copy];

        scale = _scale;
    }

    CGContextRef cref = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(cref, scale, scale);
    [self.selectionColor set];
    for (MuPDFDKQuad *v in selectionQuads)
    {
        CGContextBeginPath(cref);
        CGContextMoveToPoint(cref, v.ul.x, v.ul.y);
        CGContextAddLineToPoint(cref, v.ll.x, v.ll.y);
        CGContextAddLineToPoint(cref, v.lr.x, v.lr.y);
        CGContextAddLineToPoint(cref, v.ur.x, v.ur.y);
        CGContextClosePath(cref);
        CGContextFillPath(cref);
    }
    [self.formFieldColor set];
    for (MuPDFDKQuad *v in formFieldQuads)
    {
        CGContextBeginPath(cref);
        CGContextMoveToPoint(cref, v.ul.x, v.ul.y);
        CGContextAddLineToPoint(cref, v.ll.x, v.ll.y);
        CGContextAddLineToPoint(cref, v.lr.x, v.lr.y);
        CGContextAddLineToPoint(cref, v.ur.x, v.ur.y);
        CGContextClosePath(cref);
        CGContextFillPath(cref);
    }
}

@end
