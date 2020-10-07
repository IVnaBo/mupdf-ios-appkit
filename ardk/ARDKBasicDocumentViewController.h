//
//  ARDKBasicDocumentViewController.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 14/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKDocSession.h"
#import "ARDKBasicDocViewAPI.h"

@interface ARDKBasicDocumentViewController : UIViewController<ARDKBasicDocViewAPI>
@property(readonly) ARDKDocSession *session;

- (instancetype)initForSession:(ARDKDocSession *)session;

@end
