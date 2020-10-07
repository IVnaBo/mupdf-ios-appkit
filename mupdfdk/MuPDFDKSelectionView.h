// Copyright © 2017 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>
#import "MuPDFDKLib.h"

@interface MuPDFDKSelectionView : UIView
@property CGFloat scale;
@property UIColor *selectionColor;
@property NSArray<MuPDFDKQuad *> *selectionQuads;
@property UIColor *formFieldColor;
@property NSArray<MuPDFDKQuad *> *formFieldQuads;
@end
