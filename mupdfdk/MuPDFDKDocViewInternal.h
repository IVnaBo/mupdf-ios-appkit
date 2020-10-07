//
//  MuPDFDKDocViewInternal.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 30/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MuPDFDKLib.h"
#import "MuPDFDKAnnotatingMode.h"
#import "MuPDFDKBasicDocumentViewAPI.h"

@protocol MuPDFDKDocViewInternal <ARDKDocViewInternal>

@property(weak, readonly) id<MuPDFDKBasicDocumentViewAPI> docView;

@property(readonly) MuPDFDKDoc *doc;

@end
