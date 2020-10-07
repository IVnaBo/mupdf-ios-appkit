//
//  ARDKLib.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 22/06/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "Accelerate/accelerate.h"
#import "ARDKLib.h"


//////////////////////////////////////////////////////////
// ARDKBitmap
//////////////////////////////////////////////////////////

static void darken_bitmap_5551(uint8_t  *bitmap_,
                               uint32_t  w,
                               uint32_t  h,
                               ptrdiff_t span)
{
    uint16_t *bitmap = (uint16_t *)(void *)bitmap_;
    uint32_t x;

    span >>= 1;
    span -= w;
    for (; h > 0; h--)
    {
        for (x = w; x > 0; x--)
        {
            int v = *bitmap;
        int r = (v>>10) & 0x1f;
        int g = (v>> 5) & 0x1f;
        int b = (v    ) & 0x1f;
        int y = (39336 * r + 76884 * g + 14900 * b + 32768)>>16;
        y = 32-y;
        r += y;
        if (r < 0) r = 0; else if (r > 31) r = 31;
        g += y;
        if (g < 0) g = 0; else if (g > 31) g = 31;
        b += y;
        if (b < 0) b = 0; else if (b > 31) b = 31;
        *bitmap++ = b | (g<<5) | (r<<10);
        }
        bitmap += span;
    }
}

static void darken_bitmap_888(uint8_t  *bitmap,
                              uint32_t  w,
                              uint32_t  h,
                              ptrdiff_t span)
{
    uint32_t x;

    span -= w*4;
    for (; h > 0; h--)
    {
        for (x = w; x > 0; x--)
        {
        int r = bitmap[0];
        int g = bitmap[1];
        int b = bitmap[2];
        int y = (39336 * r + 76884 * g + 14900 * b + 32768)>>16;
        y = 259-y;
        r += y;
        if (r < 0) r = 0; else if (r > 255) r = 255;
        g += y;
        if (g < 0) g = 0; else if (g > 255) g = 255;
        b += y;
        if (b < 0) b = 0; else if (b > 255) b = 255;
        bitmap[0] = r;
        bitmap[1] = g;
        bitmap[2] = b;
        bitmap += 4;
        }
        bitmap += span;
    }
}

@implementation ARDKBitmap
{
    ARDKBitmapType _bmType;
    vImage_Buffer buf16;
    size_t bufSize;
}

- (void*)buffer
{
    return &buf16;
}

/// Allocate a bitmap of a specific size
+ (ARDKBitmap *)bitmapAtSize:(CGSize)size ofType:(ARDKBitmapType)bmType
{
    return [[ARDKBitmap alloc] initToSize:size ofType:bmType];
}

/// Give access to a subarea of an already allocated bitmap
+ (ARDKBitmap *)bitmapFromSubarea:(CGRect)area ofBitmap:(ARDKBitmap *)bm
{
    return [[ARDKBitmap alloc]initFromSubarea:area ofBitmap:bm];
}

+ (ARDKBitmap *)bitmapFromARDKBitmapInfo:(ARDKBitmapInfo *)bm
{
    return [[ARDKBitmap alloc]initFromARDKBitmapInfo:bm];
}

- (int)bytesPerPixel
{
    switch(_bmType)
    {
        case ARDKBitmapType_A8:
            return 1;
        case ARDKBitmapType_RGB555:
        case ARDKBitmapType_RGB565:
            return 2;
        case ARDKBitmapType_RGBA8888:
            return 4;
    }
}

- (instancetype)initToSize:(CGSize)size ofType:(ARDKBitmapType)bmType
{
    self = [super init];
    if (self)
    {
        _bmType = bmType;
        buf16.width    = size.width;
        buf16.height   = size.height;
        buf16.rowBytes = buf16.width * self.bytesPerPixel;
        buf16.data     = malloc(buf16.rowBytes * buf16.height);
        bufSize        = buf16.rowBytes * buf16.height;

        if (buf16.data == NULL)
            return nil;
    }

    return self;
}

- (instancetype)initFromSubarea:(CGRect)area ofBitmap:(ARDKBitmap *)parent
{
    self = [super init];
    if (self)
    {
        _parent = parent;

        CGRect prect = CGRectMake(0, 0, parent->buf16.width, parent->buf16.height);
        area = CGRectIntersection(area, prect);

        _bmType = parent->_bmType;
        buf16.width = area.size.width;
        buf16.height = area.size.height;
        buf16.rowBytes = parent->buf16.rowBytes;
        buf16.data = (char *)parent->buf16.data + (int)area.origin.y * buf16.rowBytes + (int)area.origin.x * self.bytesPerPixel;
    }

    return self;
}

- (instancetype)initFromARDKBitmapInfo:(ARDKBitmapInfo *)bm
{
    self = [super init];
    if (self)
    {
        _bmType = bm->type;
        buf16.width = bm->width;
        buf16.height = bm->height;
        buf16.rowBytes = bm->lineSkip;
        buf16.data = bm->memptr;
        bm->memptr = NULL;
    }

    return self;
}

- (void)doDarkModeConversion
{
    ARDKBitmap *root = self;
    while (root.parent)
        root = root.parent;

    if (root.darkMode)
    {
        switch (_bmType)
        {
            case ARDKBitmapType_RGB555:
                darken_bitmap_5551(buf16.data, (uint32_t)buf16.width, (uint32_t)buf16.height, buf16.rowBytes);
                break;

            case ARDKBitmapType_RGBA8888:
                darken_bitmap_888(buf16.data, (uint32_t)buf16.width, (uint32_t)buf16.height, buf16.rowBytes);
                break;

            default:
                assert(NO);
                break;
        }
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: size = %lu x %lu rowbytes = %zu data=%p>",
            NSStringFromClass(self.class),
            buf16.width, buf16.height, buf16.rowBytes, buf16.data];
}

- (void)dealloc
{
    // If there's a parent, the data is owned by it and we
    // just have pointers into it
    if (self.parent == nil)
    {
        free(buf16.data);
    }
}

/// Return details of the bitmap as a SmartOfficeBitmap structure. This
/// is the structure used within the C version of the library.
- (ARDKBitmapInfo)asBitmap
{
    ARDKBitmapInfo bm;

    bm.width    = (int)buf16.width;
    bm.height   = (int)buf16.height;
    bm.lineSkip = (int)buf16.rowBytes;
    bm.memptr   = buf16.data;
    bm.type     = _bmType;
    return bm;
}

- (NSInteger)width
{
    return buf16.width;
}

- (NSInteger)height
{
    return buf16.height;
}

/// Adjust the use of the bitmap's buffer to a different size
- (void)adjustToSize:(CGSize)size
{
    if (self.parent)
        [NSException raise:@"IllegalAspectAdjust" format:@"Cannot adjust aspect of subarea bitmap"];

    buf16.width = size.width;
    buf16.height = size.height;
    buf16.rowBytes = (buf16.width * self.bytesPerPixel + 3) & ~3;

    if (buf16.rowBytes * buf16.height > bufSize)
        [NSException raise:@"IllegalAspectAdjust" format:@"Bitmap too small to adjust to size"];
}

- (void)adjustToWidth:(NSInteger)width
{
    NSInteger height = bufSize / ((width * self.bytesPerPixel + 3) & ~3);
    [self adjustToSize:CGSizeMake(width, height)];
}

- (void)copyFrom:(ARDKBitmap *)otherBm
{
    if (buf16.width != otherBm->buf16.width
        || buf16.height != otherBm->buf16.height)
        [NSException raise:@"BadBitmalCopy" format:@"Attempt to copy from bitmap of different size"];

    uint8_t *src = otherBm->buf16.data;
    uint8_t *tgt = buf16.data;
    for (int y = 0; y < buf16.height; y++)
    {
        memcpy(tgt, src, buf16.width * self.bytesPerPixel);
        src += otherBm->buf16.rowBytes;
        tgt += buf16.rowBytes;
    }
}

@end

