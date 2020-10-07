//
//  ARDKDocErrorHandler.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 02/05/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ARDKLib.h"

@interface ARDKDocErrorHandler : NSObject

+ (ARDKDocErrorHandler *)errorHandlerForViewController:(UIViewController *)vc showingDoc:(id<ARDKDoc>)doc;

- (void)handlerError:(ARDKDocErrorType) error;

@end
