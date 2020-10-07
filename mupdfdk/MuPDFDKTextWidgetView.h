// Copyright © 2018 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>
#import "MuPDFDKLib.h"
#import "MuPDFDKWidgetView.h"

@interface MuPDFDKTextWidgetView : UIView<MuPDFDKWidgetView>
@property CGPoint selectionStart;
@property CGPoint selectionEnd;

+ (instancetype)viewForWidget:(MuPDFDKWidgetText *)widget atScale:(CGFloat)scale withPasteboard:(id<ARDKPasteboard>)pasteBoard
                     showRect:(void (^)(CGRect rect))showBlock whenDone:(void (^)(void))doneBlock whenSelectionChanged:(void (^)(void))selBlock;

@end
