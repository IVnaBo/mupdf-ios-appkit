//  Copyright © 2016 Artifex Software Inc. All rights reserved.

#import "ARDKTheme.h"

static NSInteger colorFromString(NSString *colorString)
{
    unsigned rgbValue = 0;
    unsigned start = 0;
    
    if (colorString != nil)
    {
        NSScanner *scanner = [NSScanner scannerWithString:colorString];
        if ([colorString hasPrefix:@"#"])
            start = 1;
        else if ([colorString hasPrefix:@"0x"])
            start = 2;
        
        if(start==0)
        {
            [scanner scanInt:(int *)&rgbValue];
        }
        else
        {
            [scanner setScanLocation:start]; // bypass any hex character
            [scanner scanHexInt:&rgbValue];
        }
    }
    
    return (NSInteger)rgbValue;
}

@implementation ARDKTheme

@synthesize theme;

// Based on a nice perceptive vision algorithm:
//   https://stackoverflow.com/questions/1855884/determine-font-color-based-on-background-color
// Identify the best contrast colour given a seed colour.
- (int) contrastColor:(UIColor *)color
{
    int d = 0;
    
    if (color == nil)
        return d;
    
    const CGFloat *colors = CGColorGetComponents( color.CGColor );
    
    // Counting the perceptive luminance - human eye favors green color...
    // 'colors' is a 4 element array containing RGBA components
    double a = 1 - ( 0.299 * colors[0] + 0.587 * colors[1] + 0.114 * colors[2]);
    
    if (a > 0.5)
        d = 1; // dark colors - white contrast
    else
        d = 0; // bright colors - black contrast
    
    return  d;
}

/// Set the current UI theme from a plist file
- (void)fromPlist:(NSString *)themeFile
{
    theme = [[NSMutableDictionary alloc] initWithContentsOfFile:themeFile];
}

/// Set the UI theme from a dictionary.
- (void)fromDictionary:(NSMutableDictionary *)themeDict
{
    theme = [[NSMutableDictionary alloc] initWithDictionary:themeDict];
}

/// Set the UI theme from an existing theme.
- (void)fromExisting:(ARDKTheme *)src
{
    theme = [[NSMutableDictionary alloc] initWithDictionary:src.theme];
}

// Retrieve a value from the prevailing theme
- (NSString *)getString:(NSString *)key
               fallback:(NSString *)defaultValue
{
    if (key == nil || theme == nil)
        return defaultValue;
    
    NSString *ret = [theme valueForKey:key];
    return (ret == nil) ? defaultValue : ret;
}

- (NSInteger)getInt:(NSString *)key
           fallback:(NSInteger)defaultValue
{
    if (key == nil || theme == nil)
        return defaultValue;
    
    NSString *ret = [theme valueForKey:key];
    return (ret == nil) ? defaultValue : [ret integerValue];
}


- (NSInteger)getColor:(NSString *)key
           fallback:(NSInteger)defaultValue
{
    if (key == nil || theme == nil)
        return defaultValue;
    
    NSString *ret = [theme valueForKey:key];
    return (ret == nil) ? defaultValue : colorFromString(ret);
}

- (UIColor *)getUIColor:(NSString *)key
               fallback:(NSInteger)defaultValue
{
    NSInteger color = [self getColor:key fallback:defaultValue];
    
    return [UIColor colorWithRed:(color>>16)/255.0
                           green:((color>>8)&0xff)/255.0
                            blue:(color&0xff)/255.0
                           alpha:1.0];
}

- (float)getFloat:(NSString *)key
         fallback:(float)defaultValue
{
    if (key == nil || theme == nil)
        return defaultValue;
    
    NSString *ret = [theme valueForKey:key];
    return (ret == nil) ? defaultValue : [ret floatValue];
}


@end
