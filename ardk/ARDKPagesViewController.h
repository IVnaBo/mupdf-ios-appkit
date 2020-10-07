//
//  ARDKPagesViewController.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 17/11/2015.
//  Copyright © 2015 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKLib.h"
#import "ARDKDocSession.h"

@protocol ARDKPageSelectorDelegate <NSObject>
- (void)selectPage:(NSInteger)page;
- (void)deletePage:(NSInteger)page;
- (void)duplicatePage:(NSInteger)page;
- (void)movePage:(NSInteger)page to:(NSInteger)newPos;
@end

@interface ARDKPagesViewController : UICollectionViewController
@property(weak) id<ARDKPageSelectorDelegate> delegate;

+ (instancetype)viewControllerWithSession:(ARDKDocSession *)session;

- (void)selectPage:(NSInteger)page;

@end
