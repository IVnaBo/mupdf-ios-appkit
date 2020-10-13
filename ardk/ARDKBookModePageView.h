// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>
#import "ARDKLib.h"
#import "ARDKPageController.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ARDKBookModePageViewControllerDelegate <NSObject>
- (void) onPageSizeUpdate;
- (UIView *) view;
@end

@interface ARDKBookModePageView: UIView<ARDKPageCell>
- (instancetype)initForPage:(NSInteger)pageNumber
                 withBitmap:(ARDKBitmap *)bitmap
                   delegate:(id<ARDKBookModePageViewControllerDelegate>)delegate;

- (void)setPageSize:(CGSize)size;

- (void)renderZoomed:(BOOL)zoomed onComplete:(void (^ _Nullable)(void))completeBlock;

@end

NS_ASSUME_NONNULL_END
