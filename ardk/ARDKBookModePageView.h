// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>
#import "ARDKLib.h"
#import "ARDKPageController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARDKBookModePageView: UIView<ARDKPageCell>
- (instancetype)initForPage:(NSInteger)pageNumber
                 withBitmap:(ARDKBitmap *)bitmap;

- (void)setPageSize:(CGSize)size;

- (void)render:(void (^ _Nullable)(void))completeBlock;

@end

NS_ASSUME_NONNULL_END
