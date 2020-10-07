//  Copyright © 2017 Artifex Software Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import "ARDKLib.h"

/// Internal pasteboard implementation
///
/// This stores any pasteboard contents internally to the library
///
/// It is only used if the app has not configured a pasteboard, and means
/// that pasting between the main document view and input boxes that are native
/// text views works (eg. Excel input bar, search box).
@interface ARDKInternalPasteboard : NSObject <ARDKPasteboard>

@end
