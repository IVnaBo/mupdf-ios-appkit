// Copyright © 2019 Artifex Software Inc. All rights reserved.
#import <UIKit/UIKit.h>

@interface ARDKPagePoint : NSObject
@property(readonly) NSInteger pageNumber;
@property(readonly) CGPoint pt;

+(instancetype)point:(CGPoint)pt onPage:(NSInteger)pageNumber;
@end

@interface ARDKPageArea : NSObject
@property(readonly) NSInteger pageNumber;
@property(readonly) CGRect area;

+(instancetype)area:(CGRect)area onPage:(NSInteger)pageNumber;
@end
