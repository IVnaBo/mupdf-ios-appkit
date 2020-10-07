//
//  ARDKImageViewMatrix.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 07/09/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#define TILE_SIZE (512.0)

#import "ARDKGeometry.h"
#import "ARDKImageViewMatrix.h"

@interface ARDKImageViewInfo : NSObject
@property UIImageView *imageView;
@property CGRect pixelFrame;

+ (ARDKImageViewInfo *)infoForArea:(CGRect)area ofBitmap:(ARDKBitmap *)bm;

@end

@implementation ARDKImageViewInfo

- (instancetype)initForArea:(CGRect)area ofBitmap:(ARDKBitmap *)bm
{
    self = [super init];
    if (self)
    {
        _pixelFrame = area;
        _imageView = [[UIImageView alloc] initWithImage:bm.asImage];
    }

    return self;
}

+ (ARDKImageViewInfo *)infoForArea:(CGRect)area ofBitmap:(ARDKBitmap *)bm
{
    return [[ARDKImageViewInfo alloc] initForArea:area ofBitmap:bm];
}

@end

@interface ARDKImageViewMatrix ()
@property(weak) UIView *view;
@property NSMutableDictionary<NSValue *, ARDKImageViewInfo *> *tiles;
@end

@implementation ARDKImageViewMatrix
{
    ARDKBitmap *_bm;
    CGRect _bmRect;
    CGFloat _width;
    CGFloat _scale;
    BOOL _needsReset;
}

- (instancetype)initForView:(UIView *)view;
{
    self = [super init];
    if (self)
    {
        _view = view;
        _tiles = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (ARDKImageViewMatrix *)matrixForView:(UIView *)view
{
    return [[ARDKImageViewMatrix alloc] initForView:view];
}

CGRect tileAreaForKey(NSValue *key)
{
    // The key is the x and y index of the tile, wrapped as a CGPoint
    CGPoint pt = key.CGPointValue;
    // Work out the area for this index
    return ARCGRectScale(CGRectMake(pt.x, pt.y, 1, 1), TILE_SIZE);
}

- (void)displayArea:(CGRect)area usingBitmap:(ARDKBitmap *)bm onComplete:(void (^)(void))block
{
    _bm = bm;
    _bmRect = area;
    // Array of tiles that we will no longer need, but do need until others replace them
    NSMutableArray<ARDKImageViewInfo *> *dropLaterList = [NSMutableArray arrayWithCapacity:self.tiles.count];

    // Knock out tiles that are either not needed or no longer suitable
    for (NSValue *key in self.tiles.allKeys)
    {
        ARDKImageViewInfo *tile = self.tiles[key];
        // If the tiles need a reset, we replace them all but mustn't drop them until
        // the replacements are in place.
        BOOL dropLater = _needsReset;
        BOOL dropNow = NO;

        if (!dropLater)
        {
            // Work out the area this tile would have if fully rendered
            CGRect tileLimit = tileAreaForKey(key);
            // Work out what subarea is needed from this tile
            CGRect needed = CGRectIntersection(area, tileLimit);
            // If the tile isn't needed at all or it doesn't currently cover the needed area, drop it
            if (CGRectIsNull(needed))
                dropNow = YES; // Tile isn't needed at all
            else if (!CGRectContainsRect(tile.pixelFrame, needed))
                dropLater = YES; // Tile needed until replacement
        }

        if (dropNow || dropLater)
        {
            [self.tiles removeObjectForKey:key];

            if (dropNow)
                [tile.imageView removeFromSuperview];
            else
                [dropLaterList addObject:tile];
        }
    }

    _needsReset = NO;

    // Create any tiles for areas not currently covered
    // First find out the range of indexes
    CGRect range = CGRectIntegral(ARCGRectScale(area, 1/TILE_SIZE));
    CGFloat xmin = CGRectGetMinX(range);
    CGFloat xmax = CGRectGetMaxX(range);
    CGFloat ymin = CGRectGetMinY(range);
    CGFloat ymax = CGRectGetMaxY(range);
    __block int count = 0;
    for (CGFloat x = xmin; x < xmax; x++)
    {
        for (CGFloat y = ymin; y < ymax; y++)
        {
            NSValue *key = [NSValue valueWithCGPoint:CGPointMake(x,y)];
            if (self.tiles[key] == nil)
            {
                CGRect tileLimit = tileAreaForKey(key);
                CGRect tileArea = CGRectIntersection(tileLimit, area);
                // The bitmap corresponds to area. We need tileArea relative to it
                CGRect bmArea = tileArea;
                bmArea.origin = ARCGPointOffset(bmArea.origin, -area.origin.x, -area.origin.y);
                ARDKBitmap *tileBm = [ARDKBitmap bitmapFromSubarea:bmArea ofBitmap:bm];
                // The creation of a tile info object includes setting the image of the image view,
                // which takes a not insignificant time, so we dispatch them off to avoid doing too
                // many at once. Use a count to tell when they've all finished.
                count++;
                dispatch_async(dispatch_get_main_queue(), ^{
                    ARDKImageViewInfo *info = [ARDKImageViewInfo infoForArea:tileArea ofBitmap:tileBm];
                    [self.view addSubview:info.imageView];
                    info.imageView.frame = ARCGRectScale(tileArea, 1/self.scale);
                    self.tiles[key] = info;
                    if (--count == 0)
                    {
                        for (ARDKImageViewInfo *info in dropLaterList)
                            [info.imageView removeFromSuperview];
                        block();
                    }
                });
            }
        }
    }

    if (count == 0)
    {
        // Handle the case that no tile creations were dispatched
        for (ARDKImageViewInfo *info in dropLaterList)
            [info.imageView removeFromSuperview];
        block();
    }
}

- (void)changeBitmap:(ARDKBitmap *)bm
{
    _bm = bm;
}

- (void)updateArea:(CGRect)area
{
    // The contents of bm will have changed. Update from bm each tile that
    // overlaps the changed area
    for (ARDKImageViewInfo *info in self.tiles.allValues)
    {
        if (CGRectIntersectsRect(area, info.pixelFrame))
        {
            // Intersect the tile frame with the last recorded display rectangle
            // because the tile may not have been updated and might lie partly
            // outside the display rectangle. We can update only the part that the
            // current bitmap cooresponds too. Anything outside that will be off
            // screen in any case.
            CGRect bmArea = CGRectIntersection(info.pixelFrame, _bmRect);
            info.pixelFrame = bmArea;
            bmArea.origin = ARCGPointOffset(bmArea.origin, -_bmRect.origin.x, -_bmRect.origin.y);
            info.imageView.image = [ARDKBitmap bitmapFromSubarea:bmArea ofBitmap:_bm].asImage;
            info.imageView.frame = ARCGRectScale(info.pixelFrame, 1/self.scale);
        }
    }
}

- (void)requestReset
{
    _needsReset = YES;
}

- (void)clear
{
    for (ARDKImageViewInfo *info in self.tiles.allValues)
    {
        [info.imageView removeFromSuperview];
        info.imageView.image = nil;
    }

    [self.tiles removeAllObjects];
}

- (CGFloat)width
{
    return _width;
}

- (void)setWidth:(CGFloat)width
{
    if (width != _width)
    {
        for (ARDKImageViewInfo *info in self.tiles.allValues)
            info.imageView.frame = ARCGRectScale(info.imageView.frame, width/_width);

        _needsReset = YES;
    }

    _width = width;
}

- (CGFloat)scale
{
    return _scale;
}

- (void)setScale:(CGFloat)scale
{
    if (scale != _scale)
        _needsReset = YES;

    _scale = scale;
}

@end
