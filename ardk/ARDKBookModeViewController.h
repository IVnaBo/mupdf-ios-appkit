// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>

#import "ARDKPageController.h"

@interface ARDKBookModeViewController : UIViewController<ARDKPageController>
- (instancetype)initWithDelegate:(id<ARDKPageControllerDelegate>)delegate;
@end
