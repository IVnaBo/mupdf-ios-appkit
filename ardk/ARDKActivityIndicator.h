//
//  ARDKActivityIndicator.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 01/02/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ARDKActivityIndicator <NSObject>

- (void)showActivityIndicator;
- (void)hideActivityIndicator;
- (void)showProgressIndicatorWithTarget:(id)target cancelAction:(SEL)action;
- (void)hideProgressIndicator;
- (void)setProgressIndicatorProgress:(float)progress;
@end
