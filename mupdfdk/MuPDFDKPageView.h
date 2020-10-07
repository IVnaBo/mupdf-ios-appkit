//
//  MuPDFDKPageView.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 21/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKPageView.h"
#import "MuPDFDKAnnotatingMode.h"

@interface MuPDFDKPageView : ARDKPageView

/// Whether the user is currently adding an annotation and if so what type
@property MuPDFDKAnnotatingMode annotatingMode;

/// The color to use when creating an ink annotation
@property UIColor *inkAnnotationColor;

/// The line width to use when creating an ink annotation
@property CGFloat inkAnnotationThickness;

/// Whether the selection is currently being adjusted. The page view can
/// can cache information on the selection to speed response during
/// adjustment.
@property BOOL selectionIsBeingAdjusted;

/// Clear the in-preparation ink annotation
- (void)clearInkAnnotation;

/// Prepare for reports of selection changes
- (void)prepareForSelection;

/// Attempt to select a word at the given point
- (void)selectWordAt:(CGPoint)pt;

/// Update the start of the selection
- (void)updateTextSelectionStart:(CGPoint)pt;

/// Update the end of the selection
- (void)updateTextSelectionEnd:(CGPoint)pt;

/// For a given point, find the annotations that intersect it and perform an operation on them
- (void)forAnnotationAtPt:(CGPoint)pt onPage:(void (^)(MuPDFDKAnnotation *annot))block;

/// Attempt to select an annotation at the given point
- (void)selectAnnotationAt:(CGPoint)pt;

/// Add a text annotation at a given point
- (BOOL)addTextAnnotationAt:(CGPoint)pt;

/// Add a signature field at a given point
- (BOOL)addSignatureFieldAt:(CGPoint)pt;

/// Test for a hyperlink at a given point
- (void)testAt:(CGPoint)pt forHyperlink:(void (^)(id<ARDKHyperlink> link))block;

/// Send a tap event to the page, and define what to do if tapping focusses a widget
- (void)tapAt:(CGPoint)pt onFocus:(void (^)(MuPDFDKWidget *))block;

/// Add a text-widget view for in-place form-filling
- (void)addTextWidgetView:(MuPDFDKWidgetText *)widget withPasteboard:(id<ARDKPasteboard>)pasteboard
             showRect:(void (^)(CGRect rect))showBlock whenDone:(void (^)(void))doneBlock whenSelectionChanged:(void (^)(void))selBlock;

/// Add a radio-widget view for toggling via the keyboard
- (void)addRadioWidgetView:(MuPDFDKWidgetRadio *)widget showRect:(void (^)(CGRect rect))showBlock whenDone:(void (^)(void))doneBlock;

/// Remove the widget
- (void)removeWidgetView;

/// Check if page has a widget view
- (BOOL)hasWidgetView;

/// Finalise the text widget
- (BOOL)finalizeWidgetView;

/// Reset the text widget to it's original text
- (void)resetWidgetView;

/// Focus the widget view on a different field
- (BOOL)focusOnField:(MuPDFDKWidget *)widget;

/// Pass a tap to the widget view
- (BOOL)tapWithinWidgetView:(CGPoint)pt;

/// Pass a double tap to the widget view
- (BOOL)doubleTapWithinWidgetView:(CGPoint)pt;

/// The start point of the selection within the widget (CGPointZero if no selection or caret)
- (CGPoint)widgetSelectionStart;

/// The end point of the selection within the widget (CGPointZero if no selection or caret)
- (CGPoint)widgetSelectionEnd;

/// Request the page scrolls the text widget on screen
- (void)showWidget;

/// Control visibility of the cut, copy, paste menu
- (void)setWidgetMenuVisible:(BOOL)visible;

/// Focus and exectute a block for the next field after the focussed one
- (void)focusNextField:(void (^)(MuPDFDKWidget *widget))block;

@end
