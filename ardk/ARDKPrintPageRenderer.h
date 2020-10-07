//  Copyright © 2016 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>

#import "ARDKLib.h"

@interface ARDKPrintPageRenderer : UIPrintPageRenderer

- initWithDocument:(id<ARDKDoc>)doc;

@end
