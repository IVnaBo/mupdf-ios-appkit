// Copyright © 2019 Artifex Software Inc. All rights reserved.

#import "ARDKPageGeometry.h"

@implementation ARDKPageArea
+(instancetype)area:(CGRect)area onPage:(NSInteger)pageNumber
{
    ARDKPageArea *pa = [[ARDKPageArea alloc] init];
    if (pa)
    {
        pa->_pageNumber = pageNumber;
        pa->_area = area;
    }
    return pa;
}
@end

@implementation ARDKPagePoint

+(instancetype)point:(CGPoint)pt onPage:(NSInteger)pageNumber
{
    ARDKPagePoint *pp = [[ARDKPagePoint alloc] init];
    if (pp)
    {
        pp->_pageNumber = pageNumber;
        pp->_pt = pt;
    }
    return pp;
}
@end
