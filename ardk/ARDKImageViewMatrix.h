//
//  ARDKImageViewMatrix.h
//  smart-office-nui
//
//  Displays a bitmap by using multiple small square image views.
//  Setting the image property of an image view can be an intensive
//  process. The use of multiple small image views avoids that process
//  causing UI glitches
//
//  Created by Paul Gardiner on 07/09/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKLib.h"

@interface ARDKImageViewMatrix : NSObject
@property CGFloat width;
@property CGFloat scale;

/// Create an image-view matrix to create and control subviews of the supplied view
+ (ARDKImageViewMatrix *)matrixForView:(UIView *)view;

/// Create, remove and update existing image views to ensure that the specified bitmap
/// is displayed within the specified area. Unless the width or scale have changed or
/// an explicit reset request has been made, it is assumed that the bitmap will not have
/// changed within parts that are common to this currently supplied area and the previous
/// one.
- (void)displayArea:(CGRect)area usingBitmap:(ARDKBitmap *)bm onComplete:(void (^)(void))block;

/// Some render passes contain no changed image data and don't change what area of the page
/// we need to display, but the image data still has to be moved from one bitmap to another
/// This method allows the new bitmap to be passed in for use when calling updateArea.
- (void)changeBitmap:(ARDKBitmap *)bm;

/// Update any image views that cover the specified area. The updated content
/// for that area is taken from the bitmap supplied to the last call to
/// displayArea:usingBitmap:onComplete:
- (void)updateArea:(CGRect)area;

/// Request a complete update, so that the next call to displayArea:usingBitmap:onComplete
/// will recreate all image views and not assume any correlation between the current bitmap and
/// the previous supplied.
- (void)requestReset;

/// Remove all the image views.
- (void)clear;

@end
