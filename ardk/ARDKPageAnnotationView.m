//
//  ARDKPageAnnotationView.m
//  smart-office-nui
//
//  Created by Joseph Heenan on 15/02/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "ARDKGeometry.h"
#import "ARDKPageAnnotationView.h"

#import "ARDKTiledLayer.h"

@implementation ARDKPageAnnotationView
{
    NSMutableArray<NSMutableArray<NSValue *> *> *_path; ///< accessed by CATiledLayer redraw on background threads
    CGFloat _scale;
    CGPoint _origin;
    UIColor *_inkAnnotationColor;
    CGFloat _inkAnnotationThickness;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [super initWithCoder:aDecoder];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        assert(self.layer);
        self.opaque = NO;
        self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
        ((CATiledLayer *)self.layer).levelsOfDetailBias = 4;
        ((CATiledLayer *)self.layer).levelsOfDetail = 4;
    }
    return self;
}

- (instancetype)initWithColor:(UIColor *)color andThickness:(CGFloat)thickness
{
    self = [super init];
    if (self)
    {
        _inkAnnotationColor = color;
        _inkAnnotationThickness = thickness;
    }
    return self;
}

- (UIColor *)inkAnnotationColor
{
    return _inkAnnotationColor;
}

- (void)setInkAnnotationColor:(UIColor *)inkAnnotationColor
{
    @synchronized (self) {
        _inkAnnotationColor = inkAnnotationColor;
    }
    [self setNeedsDisplay];
}

- (CGFloat)inkAnnotationThickness
{
    return _inkAnnotationThickness;
}

- (void)setInkAnnotationThickness:(CGFloat)inkAnnotationThickness
{
    @synchronized (self) {
        _inkAnnotationThickness = inkAnnotationThickness;
    }
    [self setNeedsDisplay];
}

- (CGFloat)scale
{
    return _scale;
}

- (void)setScale:(CGFloat)scale
{
    @synchronized (self) {
        _scale = scale;
    }
    [self setNeedsDisplay];
}

- (NSArray<NSArray<NSValue *> *> *)path
{
    NSMutableArray<NSArray<NSValue *> *> *pathcopy = [[NSMutableArray alloc] initWithCapacity:_path.count];
    for (NSArray *stroke in _path)
        [pathcopy addObject:[stroke copy]];

    return pathcopy;
}

- (void)clearInkAnnotation
{
    @synchronized (self) {
        _path = nil;
    }
    [self setNeedsDisplay];
}

- (void)processTouches:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UITouch *touch=[[event allTouches]anyObject];
    CGRect displayRect = CGRectNull;
    NSMutableArray<NSValue *> *stroke = _path.lastObject;

    if (stroke.count > 0)
    {
        CGPoint lastPoint = stroke.lastObject.CGPointValue;
        displayRect = ARCGRectScale(CGRectInset(CGRectMake(lastPoint.x, lastPoint.y, 0, 0) , -_inkAnnotationThickness/2, -_inkAnnotationThickness/2), _scale);
    }

    @synchronized(self) {
        if ([event respondsToSelector:@selector(coalescedTouchesForTouch:)])
        {
            for (UITouch *t in [event coalescedTouchesForTouch:touch])
            {
                CGPoint point = [t locationInView:self];
                [stroke addObject:[NSValue valueWithCGPoint:ARCGPointScale(point, 1/_scale)]];

                CGRect newPointRect = CGRectInset(CGRectMake(point.x, point.y, 0, 0) , -_inkAnnotationThickness/2, -_inkAnnotationThickness/2);
                displayRect = CGRectUnion(displayRect, newPointRect);
            }
        }
        else
        {
            CGPoint point = [touch locationInView:self];
            [stroke addObject:[NSValue valueWithCGPoint:ARCGPointScale(point, 1/_scale)]];

            CGRect newPointRect = CGRectInset(CGRectMake(point.x, point.y, 0, 0) , -_inkAnnotationThickness/2, -_inkAnnotationThickness/2);
            displayRect = CGRectUnion(displayRect, newPointRect);
        }
    }

    displayRect = CGRectIntersection(displayRect, self.bounds);
    if (!CGRectIsEmpty(displayRect))
        [self setNeedsDisplayInRect:displayRect];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    @synchronized (self) {
        // Make sure _path is allocated
        if (_path == nil)
            _path = [NSMutableArray array];
        // Start a new stroke
        [_path addObject:[NSMutableArray array]];
    }

    [self processTouches:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self processTouches:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self processTouches:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
}

+ (Class)layerClass
{
    return [ARDKTiledLayer class];
}


- (void)drawRect:(CGRect)rect
{
    CGFloat scale;
    CGFloat thickness;
    UIColor *color;
    NSMutableArray *path;
    @synchronized(self) {
        scale = _scale;
        thickness = _inkAnnotationThickness;
        color = _inkAnnotationColor;
        path = [[NSMutableArray alloc] initWithCapacity:_path.count];
        for (NSArray *stroke in _path)
            [path addObject:[stroke copy]];
    }

    CGContextRef cref = UIGraphicsGetCurrentContext();

    CGContextSetLineWidth(cref, thickness * scale);
    CGContextSetStrokeColorWithColor(cref, color.CGColor);

    if (path.count > 0)
    {
        CGContextBeginPath(cref);

        for (NSArray<NSValue *> *stroke in path)
        {
            BOOL first = YES;
            for (NSValue *point in stroke)
            {
                CGPoint pt = point.CGPointValue;
                if (first)
                    CGContextMoveToPoint(cref, pt.x * scale, pt.y * scale);
                else
                    CGContextAddLineToPoint(cref, pt.x * scale, pt.y * scale);

                first = NO;
            }
        }

        CGContextStrokePath(cref);
    }
}

@end
