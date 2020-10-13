// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>
#import "ARDKLib.h"
#import "ARDKPageController.h"
#import "ARDKBookModePageView.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARDKBookModePageViewController : UIViewController
@property(readonly) NSInteger pageNumber;
@property(readonly) ARDKBitmap *bitmap;
- (instancetype)initForPage:(NSInteger)pageNumber
                 withBitmap:(ARDKBitmap * _Nullable)bitmap
                andDelegate:(id<ARDKBookModePageViewControllerDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
