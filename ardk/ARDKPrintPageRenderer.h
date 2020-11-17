//  Copyright © 2016 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>

#import "ARDKLib.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARDKPrintPageRenderer : UIPrintPageRenderer

- initWithDocument:(id<ARDKDoc>)doc;

@end

NS_ASSUME_NONNULL_END
