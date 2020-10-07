//
//  MuPDFDKUI.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 30/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ARDKUI.h"
#import "MuPDFDKDocViewInternal.h"
#import "MuPDFDKDocumentViewController.h"

@protocol MuPDFDKUI <ARDKUI>
// Redeclare docWithUI - it has type ARDKDocumentViewController<ARDKDocViewInternal> in ARDKUI
@property(weak) MuPDFDKDocumentViewController<MuPDFDKDocViewInternal> *docWithUI;
@end
