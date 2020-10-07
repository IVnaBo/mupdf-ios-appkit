//  Copyright © 2018 Artifex Software Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// Manage UI themes
///
/// Provide storage, lookup and retrieval for a theme.
/// A theme comprises an arbitrary set of attributes
@interface ARDKTheme : NSObject

@property(readonly) NSMutableDictionary *theme;

/// Set the current UI theme from a plist file
///
/// Called to set the UI theme from a specific plist.
/// The themes filename will point to a plist file containing the
/// theme attributes
- (void)fromPlist:(NSString *)theme;

/// Set the current UI theme based on a dictionary
///
/// Called to set the UI theme from an existing theme.
- (void)fromDictionary:(NSMutableDictionary *)theme;

/// Set the current UI theme based on an input theme
///
/// Called to set the UI theme from an existing theme.
- (void)fromExisting:(ARDKTheme *)theme;

// Retrieve a value from the prevailing theme
- (NSString *)getString:(NSString *)key
               fallback:(NSString *)defaultValue;
- (NSInteger)getInt:(NSString *)key
           fallback:(NSInteger)defaultValue;
- (float)getFloat:(NSString *)key
         fallback:(float)defaultValue;

// Identify the best contrast colour given a seed colour.
- (int) contrastColor:(UIColor *)color;

// Retrieve a value from the prevailing theme
// Colors can be specified in the plist as an integer,
// HTML notation (#RRGGBB) or hex (0xRRGGBB)
- (NSInteger)getColor:(NSString *)key
             fallback:(NSInteger)defaultValue;
- (UIColor *)getUIColor:(NSString *)key
               fallback:(NSInteger)defaultValue;

@end
