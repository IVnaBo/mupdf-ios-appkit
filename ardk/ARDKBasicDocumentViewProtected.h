// Copyright © 2020 Artifex Software Inc. All rights reserved.

// This protocol contains methods of the ARDKBasicDocumentViewController
// class that need to be accessed or overridden by subclasses, but
// are, in a sense, internal and shouldn't be public

#import <Foundation/Foundation.h>
#import "ARDKPageCell.h"
#import "ARDKPageController.h"

@protocol ARDKBasicDocumentViewProtected <ARDKPageControllerDelegate>
@property(nonatomic) BOOL drawingMode;

@property BOOL reflowMode;

@property(readonly) CGFloat zoomScale;
- (void)setZoomScale:(CGFloat)scale animated:(BOOL)animated;

@property BOOL longPressEnabled;

/// Set this property to avoid the document scrolling in reaction
/// to the keyboard being removed from the screen. Controls that
/// need to align with items within the document may set this
/// while on screen.
@property BOOL disableScrollOnKeyboardHidden;

- (void)iteratePages:(void (^)(NSInteger i, UIView<ARDKPageCellDelegate> *pageView, CGRect screenRect))block;

- (void)updateItemSize;

- (void)forgetShowArea;

- (BOOL)reshowArea;

- (void)onReflowZoom;

@end

@interface ARDKBasicDocumentViewController () <ARDKBasicDocumentViewProtected>
@end
