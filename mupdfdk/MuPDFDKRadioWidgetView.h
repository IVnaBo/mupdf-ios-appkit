// Copyright © 2019 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>
#import "MuPDFDKLib.h"
#import "MuPDFDKWidgetView.h"

@interface MuPDFDKRadioWidgetView : UIView<MuPDFDKWidgetView>

+ (instancetype)viewForWidget:(MuPDFDKWidgetRadio *)widget atScale:(CGFloat)scale
                     showRect:(void (^)(CGRect rect))showBlock whenDone:(void (^)(void))doneBlock;

@end
