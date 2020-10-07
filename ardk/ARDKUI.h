//
//  ARDKUI.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 11/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ARDKDocViewInternal.h"
#import "ARDKDocumentViewController.h"
#import "ARDKActivityIndicator.h"

@protocol ARDKUI <NSObject>

@property(weak) ARDKDocumentViewController<ARDKDocViewInternal> *docWithUI;
@property(weak) id<ARDKActivityIndicator> activityIndicator;

/// Tell the UI to update according to changes in the
/// selection state of the document
- (void)updateUI;

@end
