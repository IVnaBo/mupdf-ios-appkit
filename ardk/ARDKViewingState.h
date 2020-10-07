// Copyright © 2019 Artifex Software Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ARDKViewingState : NSObject<NSCoding>
@property(readonly) NSInteger page;
@property(readonly) CGPoint offset;
@property CGFloat scale;

+ (instancetype)stateWithPage:(NSInteger)page offset:(CGPoint)offset scale:(CGFloat)scale;
@end

@interface ARDKViewingStateStack : NSObject<NSCoding>
@property ARDKViewingState *viewingState;
@property(readonly) BOOL previousAllowed;
@property(readonly) BOOL nextAllowed;

- (void)previous;

- (void)next;

+ (instancetype)viewingStateStack;

- (void)push:(ARDKViewingState *)viewingState;

- (void)push:(NSInteger)page offset:(CGPoint)offset scale:(CGFloat)scale;

@end
