//  Copyright © 2017 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>
#import "ARDKLib.h"

@interface ARDKTextView : UITextView

@property (strong) id <ARDKPasteboard> pasteboard;

@end
