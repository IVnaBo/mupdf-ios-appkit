// Information passed to an event sent by SODK
//
// Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ARDKHandlerInfo : NSObject

/// Path to applicable file
@property (strong, nonatomic) NSString *path;

/// Filename for display to user
///
/// The filename in the 'path' may be a temporary one, so when displaying a
/// name to the user this string should be used
@property (strong, nonatomic) NSString *filename;

/// The UI button that triggered this handler
///
/// This is provided so that any presented popovers may be positioned
/// correctly next to the button.
@property (weak, nonatomic) UIView *button;

/// A UIViewController provided if the caller wants to call
/// presentViewController:.
@property (weak, nonatomic) UIViewController *presentingVc;

@end

NS_ASSUME_NONNULL_END
