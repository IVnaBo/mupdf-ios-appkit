// Copyright © 2017 Artifex Software Inc. All rights reserved.

#import "Accelerate/accelerate.h"
#import "ARDKLib.h"

@implementation ARDKBitmap (ARDKBitmap_ARDKAdditions)

/// Produce a UIImage from the bitmap. The UIImage holds a reference.
- (UIImage *)asImage
{
    vImage_Buffer *buf16 = (vImage_Buffer*)self.buffer;
    int            bpp;

    if ( buf16 == nil || buf16->width == 0 || buf16->height == 0)
        return nil;

    ARDKBitmap *root = self;
    while (root.parent)
        root = root.parent;

    switch (self.bmType)
    {
        case ARDKBitmapType_RGBA8888:
            bpp = 4;
            break;
        case ARDKBitmapType_RGB555:
        case ARDKBitmapType_RGB565:
            bpp = 2;
            break;
        case ARDKBitmapType_A8:
            bpp = 1;
            break;
        default:
            assert("Unknown bitmap type" == NULL);
            break;
    }

    // FIXME: account for soft profile when deriving image
    //ARDKSoftProfile softProfile = root.softProfile;
    CGDataProviderRef cgdata = CGDataProviderCreateWithData((__bridge_retained void *)self, buf16->data,
                                                            buf16->rowBytes * (buf16->height - 1) + buf16->width * bpp,
                                                            releaseData);
    CGColorSpaceRef cgcolor;
    CGImageRef cgimage;

    switch(self.bmType)
    {
        case ARDKBitmapType_RGBA8888:
            cgcolor = CGColorSpaceCreateDeviceRGB();
            cgimage = CGImageCreate(buf16->width, buf16->height, 8, 32, buf16->rowBytes,
                                    cgcolor, kCGBitmapByteOrderDefault|kCGImageAlphaNoneSkipLast, cgdata,
                                    NULL, NO, kCGRenderingIntentDefault);
            break;
        case ARDKBitmapType_RGB555:
        case ARDKBitmapType_RGB565:
            cgcolor = CGColorSpaceCreateDeviceRGB();
            cgimage = CGImageCreate(buf16->width, buf16->height, 5, 16, buf16->rowBytes,
                                    cgcolor, kCGBitmapByteOrder16Little|kCGImageAlphaNoneSkipFirst, cgdata,
                                    NULL, NO, kCGRenderingIntentDefault);
            break;
        case ARDKBitmapType_A8:
            cgcolor = CGColorSpaceCreateDeviceGray();
            cgimage = CGImageCreate(buf16->width, buf16->height, 8, 8, buf16->rowBytes,
                                    cgcolor, kCGBitmapByteOrderDefault|kCGImageAlphaNone, cgdata,
                                    NULL, NO, kCGRenderingIntentDefault);
            break;
        default:
            break;
    }
    assert(cgimage);
    CGDataProviderRelease(cgdata);
    CGColorSpaceRelease(cgcolor);
    UIImage *image = [UIImage imageWithCGImage:cgimage];
    CGImageRelease(cgimage);
    
    return image;
}

- (UIImage *)asImageCombinedWithAlpha:(const ARDKBitmap *)alpha
{
    const int           bpp = 4; // r8g8b8a8 is 4 bytes per pixel

    CGDataProviderRef   cgdata;
    CGColorSpaceRef     cgcolor;
    CGImageRef          cgimage;
    size_t              bufsz;
    uint32_t           *buffer;
    UIImage            *image;
    size_t              rowBytes;

    assert(alpha);

    vImage_Buffer      *vcolour = (vImage_Buffer *) self.buffer;
    vImage_Buffer      *valpha = (vImage_Buffer *) [alpha buffer];

    if (vcolour == nil || alpha == nil ||
        vcolour->width == 0 || vcolour->height == 0 ||
        alpha.width != vcolour->width || alpha.height != vcolour->height)
        return nil;

    ARDKBitmap *root = self;
    while (root.parent)
        root = root.parent;

    if (self.bmType != ARDKBitmapType_RGB565 ||
        alpha.bmType != ARDKBitmapType_A8)
    {
        assert(0);
    }

    rowBytes = (vcolour->width * bpp + 7) & ~7; /* align rows to 8 bytes */
    bufsz = vcolour->height * rowBytes;
    buffer = malloc(bufsz);
    if (buffer == NULL)
        return nil;

    // Merge the b5g6r5 + g8 pixels into r8g8b8a8 (not premultiplied)
    {
        uint16_t *cd = vcolour->data; //   b5g6r5 colour pixels
        uint8_t  *ad = valpha->data;  //       g8  alpha pixels
        uint32_t *dd = buffer;        // r8g8b8a8 output pixels
        int       y;

        for (y = 0; y < vcolour->height; y++)
        {
            uint16_t *cp = cd;
            uint8_t  *ap = ad;
            uint32_t *dp = dd;
            int       x;

            for (x = 0; x < vcolour->width; x++)
            {
                uint16_t cpx = *cp++;
                uint8_t  apx = *ap++;
                uint32_t r,g,b;

                r = (cpx & 0xF800) >> 8; r |= (r >> 5);
                g = (cpx & 0x07E0) >> 3; g |= (g >> 6);
                b = (cpx & 0x001F) << 3; b |= (b >> 5);

                *dp++ = (r << 0) | (g << 8) | (b << 16) | (apx << 24);
            }
            cd += vcolour->width; // advance by a packed row
            ad += vcolour->width; // advance by a packed row
            dd += rowBytes / bpp; // advance by an 8-byte aligned row
        }
    }

    cgdata = CGDataProviderCreateWithData((__bridge_retained void *) self,
                                          buffer,
                                          bufsz,
                                          freeData);
    cgcolor = CGColorSpaceCreateDeviceRGB();
    cgimage = CGImageCreate(vcolour->width, vcolour->height,
                            8, 32, rowBytes,
                            cgcolor,
                            kCGBitmapByteOrderDefault|kCGImageAlphaLast,
                            cgdata,
                            NULL,
                            NO,
                            kCGRenderingIntentDefault);
    assert(cgimage);
    CGDataProviderRelease(cgdata);
    CGColorSpaceRelease(cgcolor);
    image = [UIImage imageWithCGImage:cgimage];
    CGImageRelease(cgimage);

    return image;
}

- (id)debugQuickLookObject
{
    UIImage *image = [self asImage];
    UIGraphicsBeginImageContext(image.size);
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    // Avoid the image being mirrored in the horizontal axis
    CGContextTranslateCTM(currentContext, 0.0, image.size.height);
    CGContextScaleCTM(currentContext, 1.0, -1.0);
    CGContextDrawImage(currentContext, rect, image.CGImage);
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

static void releaseData(void *info, const void *data, size_t size)
{
    // Drop the reference to the bitmap from which the image using
    // this data was created
    (void)(__bridge_transfer ARDKBitmap *)info;
}

static void freeData(void *info, const void *data, size_t size)
{
    free((void *) data);
}

@end

@implementation UIImage (UIImage_ARDKAdditions)

- (UIImage *)ARDKsanitizedImage
{
    UIGraphicsBeginImageContext(self.size);
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectMake(0, 0, self.size.width, self.size.height);
    // Avoid the image being mirrored in the horizontal axis
    CGContextTranslateCTM(currentContext, 0.0, self.size.height);
    CGContextScaleCTM(currentContext, 1.0, -1.0);
    CGContextDrawImage(currentContext, rect, self.CGImage);
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@end
