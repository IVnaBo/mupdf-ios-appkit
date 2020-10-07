// Copyright © 2018 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>

@interface MuPDFDKOptionWidgetViewController : UIViewController
@property NSArray<NSString *> *options;
@property(readonly) NSString *currentOption;
@property void (^onUpdate)(void);
@property void (^onCancel)(void);
@end
