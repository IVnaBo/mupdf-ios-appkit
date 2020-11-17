// Copyright © 2017 Artifex Software Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import "MuPDFDKAnnotatingMode.h"
#import "ARDKBasicDocViewAPI.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MuPDFDKBasicDocumentViewAPI <ARDKBasicDocViewAPI>

/// Whether the user is currently adding an annotation and if so what type
@property MuPDFDKAnnotatingMode annotatingMode;

/// The color to use when creating an ink annotation
@property UIColor *inkAnnotationColor;

/// The line width to use when creating an ink annotation
@property CGFloat inkAnnotationThickness;

/// Clear the in-preparation ink annotation
- (void)clearInkAnnotation;

/// Finalise and remove the text widget if present
- (void)endTextWidgetEditing;

@end

NS_ASSUME_NONNULL_END
