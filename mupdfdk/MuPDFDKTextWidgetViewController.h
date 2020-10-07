// Copyright © 2018 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>

@interface MuPDFDKTextWidgetViewController : UIViewController
@property NSString *text;
@property void (^onUpdate)(void);
@property void (^onCancel)(void);
@end
