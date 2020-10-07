// Copyright © 2019 Artifex Software Inc. All rights reserved.

#import <Foundation/Foundation.h>

@protocol MuPDFDKWidgetView <NSObject>
@property CGFloat scale;
@property CGPoint selectionStart;
@property CGPoint selectionEnd;

- (BOOL)finalizeField;

- (void)resetField;

- (BOOL)focusOnField:(MuPDFDKWidget *)widget;

- (BOOL)tapAt:(CGPoint)pt;

- (BOOL)doubleTapAt:(CGPoint)pt;

- (void)showRect;

- (void)willBeRemoved;

@end
