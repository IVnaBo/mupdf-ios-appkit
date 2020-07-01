//
//  ARDKGeometry.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 19/02/2015.
//  Copyright (c) 2015 Artifex Software Inc. All rights reserved.
//

#ifndef __ARDKGeometry__
#define __ARDKGeometry__

#include <CoreGraphics/CoreGraphics.h>


#define ARCGRectAdjustSizeAboutCenter(rect, newsize) \
    CGRectInset((rect), ((rect).size.width - (newsize).width)/2, \
                        ((rect).size.height - (newsize).height)/2)

#define ARCGSizeScale(size, scale) CGSizeMake((size).width * (scale), (size).height * (scale))

#define ARCGPointScale(point, scale) CGPointMake((point).x * (scale), (point).y * (scale))

#define ARCGPointMagnitude(point) sqrt((point).x * (point).x + (point).y * (point).y)

#define ARCGPointDotProduct(point1, point2) ((point1).x * (point2).x + (point1).y * (point2).y)

#define ARCGRectScale(rect, scale) \
    CGRectMake((rect).origin.x * (scale), (rect).origin.y * (scale), \
               (rect).size.width * (scale), (rect).size.height * (scale))

#define ARCGPointOffset(pt, xoff, yoff) \
    CGPointMake((pt).x + (xoff), (pt).y + (yoff))

#define ARCGRectDistanceToPoint(rect, pt) \
    fmax(fmax((rect).origin.x - (pt).x, fmax((pt).x - ((rect).origin.x + (rect).size.width), 0.0)), \
         fmax((rect).origin.y - (pt).y, fmax((pt).y - ((rect).origin.y + (rect).size.height), 0.0)))


#endif /* defined(__ARDKGeometry__) */
