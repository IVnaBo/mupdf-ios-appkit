//
//  MuPDFDKPageView.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 21/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKGeometry.h"
#import "ARDKPageAnnotationView.h"
#import "MuPDFDKSelectionView.h"
#import "MuPDFDKLib.h"
#import "MuPDFDKTextWidgetView.h"
#import "MuPDFDKRadioWidgetView.h"
#import "MuPDFDKPageView.h"

@interface MuPDFDKPageView ()
@property ARDKPageAnnotationView *annotationView;
@property MuPDFDKSelectionView *selectionView;
@property BOOL selectionViewPresent;
@property UIView<MuPDFDKWidgetView> *widgetView;
@end

@implementation MuPDFDKPageView
{
    MuPDFDKAnnotatingMode _annotatingMode;
    UIColor *_inkAnnotationColor;
    CGFloat _inkAnnotationThickness;
    BOOL _selectionIsBeingAdjusted;
}

- (MuPDFDKDoc *)mudoc
{
    return (MuPDFDKDoc *)self.doc;
}

- (MuPDFDKPage *)mupage
{
    return (MuPDFDKPage *)self.page;
}

- (void)resizeOverlays
{
    [super resizeOverlays];
    self.annotationView.scale = self.baseZoom;
    self.selectionView.scale = self.baseZoom;
    self.widgetView.scale = self.baseZoom;
}

- (MuPDFDKAnnotatingMode)annotatingMode
{
    return _annotatingMode;
}

- (void)setAnnotatingMode:(MuPDFDKAnnotatingMode)annotatingMode
{
    if (annotatingMode == _annotatingMode)
        return;

    if (annotatingMode == MuPDFDKAnnotatingMode_Draw)
    {
        self.annotationView = [[ARDKPageAnnotationView alloc]initWithColor:_inkAnnotationColor andThickness:_inkAnnotationThickness];
        self.annotationView.scale = self.baseZoom;
        assert(self.annotationView.translatesAutoresizingMaskIntoConstraints);
        self.annotationView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        self.annotationView.frame = self.bounds;
        [self addSubview:self.annotationView];
        // Ensure the in-prepartion annotation stays visible above document display tiles
        self.annotationView.layer.zPosition = 1;
    }
    else
    {
        if (self.annotationView.path.count > 0)
        {
            [self.mupage addInkAnnotationWithPaths:self.annotationView.path
                                             color:self.inkAnnotationColor
                                         thickness:self.inkAnnotationThickness];
        }

        [self.annotationView removeFromSuperview];
        self.annotationView = nil;
    }

    _annotatingMode = annotatingMode;
}

- (UIColor *)inkAnnotationColor
{
    return _inkAnnotationColor;
}

- (void)setInkAnnotationColor:(UIColor *)inkAnnotationColor
{
    _inkAnnotationColor = inkAnnotationColor;
    self.annotationView.inkAnnotationColor = inkAnnotationColor;
}

- (CGFloat)inkAnnotationThickness
{
    return _inkAnnotationThickness;
}

- (void)setInkAnnotationThickness:(CGFloat)inkAnnotationThickness
{
    _inkAnnotationThickness = inkAnnotationThickness;
    self.annotationView.inkAnnotationThickness = inkAnnotationThickness;
}

- (void)clearInkAnnotation
{
    [self.annotationView clearInkAnnotation];
}

- (BOOL)selectionViewPresent
{
    return self.selectionView != nil;
}

- (void)setSelectionViewPresent:(BOOL)selectionViewPresent
{
    if (selectionViewPresent == (self.selectionView != nil))
        return;

    if (selectionViewPresent)
    {
        self.selectionView = [[MuPDFDKSelectionView alloc] init];
        self.selectionView.scale = self.baseZoom;
        self.selectionView.selectionColor = [UIColor colorWithRed:0x25/255.0 green:0x72/255.0 blue:0xAC/255.0 alpha:0.5];
        self.selectionView.formFieldColor = [UIColor colorWithRed:0.0 green:0x35/255.0 blue:1.0 alpha:0.13];
        self.selectionView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        self.selectionView.frame = self.bounds;
        [self addSubview:self.selectionView];
        self.selectionView.layer.zPosition = 1;
    }
    else
    {
        [self.selectionView removeFromSuperview];
        self.selectionView = nil;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = event.allTouches.anyObject;
    CGPoint pt = ARCGPointScale([touch locationInView:self], 1 / self.baseZoom);

    switch (self.annotatingMode)
    {
        case MuPDFDKAnnotatingMode_RedactionAreaSelect:
            [self.mupage makeAreaSelectionFrom:pt to:pt];
            break;

        case MuPDFDKAnnotatingMode_RedactionTextSelect:
        case MuPDFDKAnnotatingMode_HighlightTextSelect:
            [self.mupage selectWordAt:pt];
            break;

        default:
            break;
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    switch (self.annotatingMode)
    {
        case MuPDFDKAnnotatingMode_RedactionAreaSelect:
        case MuPDFDKAnnotatingMode_RedactionTextSelect:
        case MuPDFDKAnnotatingMode_HighlightTextSelect:
        {
            UITouch *touch = event.allTouches.anyObject;
            CGPoint pt = ARCGPointScale([touch locationInView:self], 1 / self.baseZoom);
            [self.mupage updateTextSelectionEnd:pt];
            break;
        }

        default:
            break;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    switch (self.annotatingMode)
    {
        case MuPDFDKAnnotatingMode_RedactionAreaSelect:
        case MuPDFDKAnnotatingMode_RedactionTextSelect:
        {
            UITouch *touch = event.allTouches.anyObject;
            CGPoint pt = ARCGPointScale([touch locationInView:self], 1 / self.baseZoom);
            [self.mupage updateTextSelectionEnd:pt];
            [self.mupage createRedactionAnnotationFromSelection];
            break;
        }

        case MuPDFDKAnnotatingMode_HighlightTextSelect:
        {
            UITouch *touch = event.allTouches.anyObject;
            CGPoint pt = ARCGPointScale([touch locationInView:self], 1 / self.baseZoom);
            [self.mupage updateTextSelectionEnd:pt];
            [self.mudoc addHighlightAnnotationLeaveSelected:YES];
            break;
        }

        default:
            break;
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    switch (self.annotatingMode)
    {
        case MuPDFDKAnnotatingMode_RedactionAreaSelect:
        case MuPDFDKAnnotatingMode_RedactionTextSelect:
        case MuPDFDKAnnotatingMode_HighlightTextSelect:
        {
            [self.mudoc clearSelection];
            break;
        }

        default:
            break;
    }
}

- (void)prepareForSelection
{
    self.mupage.onSelectionChanged = ^{
        NSArray<MuPDFDKQuad *> *selectionQuads = self.mupage.selectionQuads;
        NSArray<MuPDFDKQuad *> *formFieldQuads = self.mupage.formFieldQuads;
        self.selectionViewPresent = (selectionQuads.count > 0 || formFieldQuads.count > 0);
        self.selectionView.selectionQuads = selectionQuads;
        self.selectionView.formFieldQuads = formFieldQuads;
    };
    self.mupage.onSelectionChanged();
}

- (void)selectWordAt:(CGPoint)pt
{
    [self.mupage selectWordAt:ARCGPointScale(pt, 1/self.baseZoom)];
}

- (BOOL)selectionIsBeingAdjusted
{
    return _selectionIsBeingAdjusted;
}

- (void)setSelectionIsBeingAdjusted:(BOOL)selectionIsBeingAdjusted
{
    if (selectionIsBeingAdjusted != _selectionIsBeingAdjusted)
    {
        if (!selectionIsBeingAdjusted)
        {
            // selectionIsBeingAdjusted being changed from YES to NO
            // For redactions, update the annotation quads
            if (self.mudoc.selectionIsRedaction || self.mudoc.selectionIsTextHighlight || self.mudoc.selectionIsWidget)
            {
                // Update annotation rectangle using the current handle positions
                [self.mudoc updateSelectedAnnotationsQuads];
            }
        }

        _selectionIsBeingAdjusted = selectionIsBeingAdjusted;
    }
}

- (void)updateTextSelectionStart:(CGPoint)pt
{
    pt = ARCGPointScale(pt, 1/self.baseZoom);
    if (_widgetView)
    {
        _widgetView.selectionStart = pt;
        [self setWidgetMenuVisible:YES];
    }
    else
    {
        [self.mupage updateTextSelectionStart:pt];
    }
}

- (void)updateTextSelectionEnd:(CGPoint)pt
{
    pt = ARCGPointScale(pt, 1/self.baseZoom);
    if (_widgetView)
    {
        _widgetView.selectionEnd = pt;
        [self setWidgetMenuVisible:YES];
    }
    else
    {
        [self.mupage updateTextSelectionEnd:pt];
    }
}

- (void)forAnnotationAtPt:(CGPoint)pt onPage:(void (^)(MuPDFDKAnnotation *))block
{
    [self.mupage forAnnotationsAtPt:ARCGPointScale(pt, 1/self.baseZoom) onPage:^(NSArray<MuPDFDKAnnotation *> * _Nonnull annots) {
        MuPDFDKAnnotation *found = nil;
        if (self.annotatingMode == MuPDFDKAnnotatingMode_EditRedaction)
        {
            for (MuPDFDKAnnotation *annot in annots)
            {
                if (annot.type == MuPDFAnnotType_Redact)
                    found = annot;
            }
        }
        else
        {
            for (MuPDFDKAnnotation *annot in annots)
            {
                if (annot.type != MuPDFAnnotType_Redact)
                {
                    found = annot;
                    if (annot.type == MuPDFAnnotType_Text || annot.type == MuPDFAnnotType_Highlight)
                        break;
                }
            }
        }
        block(found);
    }];
}

- (void)selectAnnotationAt:(CGPoint)pt;
{
    switch (_annotatingMode)
    {
        case MuPDFDKAnnotatingMode_EditRedaction:
            [self.mupage selectRedactionAt:ARCGPointScale(pt, 1/self.baseZoom)];
            break;

        default:
            [self.mupage selectAnnotationAt:ARCGPointScale(pt, 1/self.baseZoom)];
            break;
    }
}

- (BOOL)addTextAnnotationAt:(CGPoint)pt
{
    return [self.mupage addTextAnnotationAt:ARCGPointScale(pt, 1/self.baseZoom)];
}

- (BOOL)addSignatureFieldAt:(CGPoint)pt
{
    return [self.mupage addSignatureFieldAt:ARCGPointScale(pt, 1/self.baseZoom)];
}

- (void)testAt:(CGPoint)pt forHyperlink:(void (^)(id<ARDKHyperlink>))block
{
    [self.mupage testAt:ARCGPointScale(pt, 1/self.baseZoom) forHyperlink:block];
}

- (void)tapAt:(CGPoint)pt onFocus:(void (^)(MuPDFDKWidget *))block
{
    [self.mupage tapAt:ARCGPointScale(pt, 1/self.baseZoom) onFocus:block];
}

- (void)reset
{
    [super reset];
    [self.widgetView removeFromSuperview];
    self.widgetView = nil;
    self.selectionViewPresent = NO;
}

- (void)addTextWidgetView:(MuPDFDKWidgetText *)widget withPasteboard:(id<ARDKPasteboard>)pasteboard
             showRect:(void (^)(CGRect))showBlock whenDone:(void (^)(void))doneBlock whenSelectionChanged:(void (^)(void))selBlock
{
    [self setWidgetMenuVisible:NO];
    self.widgetView = [MuPDFDKTextWidgetView viewForWidget:widget atScale:self.baseZoom withPasteboard:pasteboard
                                                  showRect:showBlock whenDone:doneBlock whenSelectionChanged:selBlock];
    [self addSubview:self.widgetView];
    [self.widgetView becomeFirstResponder];
}

- (void)addRadioWidgetView:(MuPDFDKWidgetRadio *)widget showRect:(void (^)(CGRect))showBlock whenDone:(void (^)(void))doneBlock
{
    [self setWidgetMenuVisible:NO];
    self.widgetView = [MuPDFDKRadioWidgetView viewForWidget:widget atScale:self.baseZoom showRect:showBlock whenDone:doneBlock];
    [self addSubview:self.widgetView];
    [self.widgetView becomeFirstResponder];
}

- (void)removeWidgetView
{
    [self setWidgetMenuVisible:NO];
    [self.widgetView willBeRemoved];
    [self.widgetView removeFromSuperview];
    self.widgetView = nil;
}

- (BOOL)hasWidgetView
{
    return self.widgetView != nil;
}

- (BOOL)finalizeWidgetView
{
    // Report finalization successful if there is no widget
    return self.widgetView ? [self.widgetView finalizeField] : YES;
}

- (void)resetWidgetView
{
    [self.widgetView resetField];
}

- (BOOL)focusOnField:(MuPDFDKWidget *)widget
{
    [self setWidgetMenuVisible:NO];
    return [self.widgetView focusOnField:widget];
}

- (BOOL)tapWithinWidgetView:(CGPoint)pt
{
    return [self.widgetView tapAt:ARCGPointScale(pt, 1/self.baseZoom)];
}

- (BOOL)doubleTapWithinWidgetView:(CGPoint)pt
{
    return [self.widgetView doubleTapAt:ARCGPointScale(pt, 1/self.baseZoom)];
}

- (CGPoint)widgetSelectionStart
{
    return ARCGPointScale(self.widgetView.selectionStart, self.baseZoom);
}

- (CGPoint)widgetSelectionEnd
{
    return ARCGPointScale(self.widgetView.selectionEnd, self.baseZoom);
}

- (void)showWidget
{
    [self.widgetView showRect];
    [self.widgetView becomeFirstResponder];
}

- (void)setWidgetMenuVisible:(BOOL)visible
{
    if (visible)
        [UIMenuController.sharedMenuController setTargetRect:self.widgetView.bounds inView:self.widgetView];

    [UIMenuController.sharedMenuController setMenuVisible:visible animated:YES];
}

- (void)focusNextField:(void (^)(MuPDFDKWidget *))block
{
    [self.mupage focusNextWidget:block];
}

@end
