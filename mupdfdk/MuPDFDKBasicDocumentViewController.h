//
//  MuPDFDKBasicDocumentViewController.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 21/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKBasicDocumentViewController.h"
#import "MuPDFDKBasicDocumentViewAPI.h"

@interface MuPDFDKBasicDocumentViewController : ARDKBasicDocumentViewController<MuPDFDKBasicDocumentViewAPI>
// Active document session that can be used to create another view
@property(readonly) ARDKDocSession *session;

// Create a document view based on a document file path
+ (instancetype) viewControllerForPath:(NSString *)path;

// Create a document view based on an active session
+ (instancetype) viewControllerForSession:(ARDKDocSession *)session;


@end
