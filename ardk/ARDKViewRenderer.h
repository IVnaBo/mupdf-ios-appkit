//
//  ARDKViewRenderer.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 12/11/2015.
//  Copyright © 2015 Artifex Software Inc. All rights reserved.
//

#import "ARDKLib.h"
#import "ARDKPageCell.h"

@protocol ARDKViewRendererDelegate <NSObject>
@property UIView *view;
@property ARDKBitmap *bitmap;

- (void)iteratePages:(void (^)(NSInteger i, UIView<ARDKPageCellDelegate> *pageView, CGRect screenRect))block;
@end

#import <Foundation/Foundation.h>

@interface ARDKViewRenderer : NSObject
@property BOOL darkMode;

- (instancetype)initWithDelegate:(id<ARDKViewRendererDelegate>)delegate lib:(id<ARDKDoc>)ardkdoc;

- (void)triggerRender;

- (void)forceRender;

- (void)afterFirstRender:(void (^)(void))block;

@end
