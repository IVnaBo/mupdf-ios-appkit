//
//  ARDKUIDimensions.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 24/10/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "ARDKUIDimensions.h"

/// Some of the UI dimensions need adjusting for different localizations. This
/// class represents them as localized strings hence making them part of the
/// translation.

// All localized string in this file should be obtained from the sodk framework
#undef NSLocalizedString
#define NSLocalizedString(key, comment) NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:self], comment)

@implementation ARDKUIDimensions

+ (CGFloat)defaultRibbonButtonWidth
{
    return NSLocalizedString(@"70.0 DefaultRibbonButtonWidth", @"Do not translate").floatValue;
}

+ (CGFloat)formulasRibbonButtonWidth
{
    return NSLocalizedString(@"80.0 FormulasRibbonButtonWidth", @"Do not translate").floatValue;
}

+ (CGFloat)alignmentButtonWidth
{
    return NSLocalizedString(@"70.0 AlignmentButtonWidth", @"Do not translate").floatValue;
}

+ (CGFloat)trackChangesButtonWidth
{
    return NSLocalizedString(@"70.0 TrackChangesButtonWidth", @"Do not translate").floatValue;
}

@end
