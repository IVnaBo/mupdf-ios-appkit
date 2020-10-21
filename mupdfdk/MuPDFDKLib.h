//
//  MuPDFDKLib.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 21/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKLib.h"
#import "ARDKPKCS7.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum
{
    MuPDFPrintProfile_USWebCoatedSWOP,
    MuPDFPrintProfile_CoatedFOGRA39,
    MuPDFPrintProfile_EuroscaleCoated,
    MuPDFPrintProfile_JapanWebCoated,
    MuPDFPrintProfile_None
} MuPDFPrintProfile;

typedef enum
{
    MuPDFAlertIcon_Error,
    MuPDFAlertIcon_Warning,
    MuPDFAlertIcon_Question,
    MuPDFAlertIcon_Status
} MuPDFAlertIcon;

typedef enum
{
    MuPDFAlertButton_None,
    MuPDFAlertButton_Ok,
    MuPDFAlertButton_Cancel,
    MuPDFAlertButton_No,
    MuPDFAlertButton_Yes
} MuPDFAlertButton;

typedef enum
{
    MuPDFAlertButtonGroup_Ok,
    MuPDFAlertButtonGroup_OkCancel,
    MuPDFAlertButtonGroup_YesNo,
    MuPDFAlertButtonGroup_YesNoCancel
} MuPDFAlertButtonGroup;

typedef enum
{
    MuPDFAnnotType_Text,
    MuPDFAnnotType_Link,
    MuPDFAnnotType_FreeText,
    MuPDFAnnotType_Line,
    MuPDFAnnotType_Square,
    MuPDFAnnotType_Circle,
    MuPDFAnnotType_Polygon,
    MuPDFAnnotType_PolyLine,
    MuPDFAnnotType_Highlight,
    MuPDFAnnotType_Underline,
    MuPDFAnnotType_Squiggly,
    MuPDFAnnotType_StrikeOut,
    MuPDFAnnotType_Redact,
    MuPDFAnnotType_Stamp,
    MuPDFAnnotType_Caret,
    MuPDFAnnotType_Ink,
    MuPDFAnnotType_Popup,
    MuPDFAnnotType_FileAttachment,
    MuPDFAnnotType_Sound,
    MuPDFAnnotType_Movie,
    MuPDFAnnotType_Widget,
    MuPDFAnnotType_Screen,
    MuPDFAnnotType_PrinterMark,
    MuPDFAnnotType_TrapNet,
    MuPDFAnnotType_Watermark,
    MuPDFAnnotType_3d,
    MuPDFAnnotType_Unknown = -1
} MuPDFAnnotType;

@interface MuPDFAlert : NSObject
@property(nullable, nonatomic, copy) NSString *message;
@property(nullable, nonatomic, copy) NSString *title;
@property MuPDFAlertIcon icon;
@property MuPDFAlertButtonGroup buttonGroup;
@property (nonnull, copy) void (^reply)(MuPDFAlertButton buttonPressed);
@end

@interface MuPDFDKTextLayoutLine : NSObject
@property(readonly) CGRect lineRect;
@property(readonly) NSArray<NSValue *> *charRects;
@end

@interface MuPDFDKAnnotation : NSObject
@property(readonly) MuPDFAnnotType type;
@property(readonly) CGRect rect;
@end

@class MuPDFDKWidgetText;
@class MuPDFDKWidgetList;
@class MuPDFDKWidgetRadio;
@class MuPDFDKWidgetSignedSignature;
@class MuPDFDKWidgetUnsignedSignature;

@interface MuPDFDKWidget : NSObject
@property CGRect rect;
@property MuPDFDKAnnotation *annot;
- (void)switchCaseText:(nonnull void (^)(MuPDFDKWidgetText *widget))textBlock
              caseList:(nonnull void (^)(MuPDFDKWidgetList *widget))listBlock
             caseRadio:(nonnull void (^)(MuPDFDKWidgetRadio *widget))radioBlock
   caseSignedSignature:(nonnull void (^)(MuPDFDKWidgetSignedSignature *widget))signedSignatureBlock
 caseUnsignedSignature:(nonnull void (^)(MuPDFDKWidgetUnsignedSignature *widget))unsignedSignatureBlock;
@end

@interface MuPDFDKWidgetText : MuPDFDKWidget
@property(nullable, nonatomic, copy) NSString *text;
@property BOOL isMultiline;
@property BOOL isNumber;
@property NSInteger maxChars;
// Update the text widget's text. Because of javascript-based event handlers
// the update may be rejected. A BOOL is returned so that the caller can react to the
// possibility (e.g., if a modal view was used to allow entry of the text,
// that view could be reopened and/or a message could be displayed). The BOOL final
// allows the caller to specify that the update is the last of a sequence as the
// user types in some text. Certain checks and applications of formatting are
// applied only on the final update.
@property (nonnull, copy) BOOL (^setText)(NSString *text, BOOL final);
@property (nonnull, copy) NSArray<MuPDFDKTextLayoutLine *> *(^getTextLayout)(void);
@end

@interface MuPDFDKWidgetList : MuPDFDKWidget
@property(nullable, nonatomic, copy) NSArray<NSString *> *optionText;
// Update the widget's selected option. Because of javascript-based event handlers
// the update may be rejected. A block is passed that can respond to that
// possibility (e.g., if a modal view was used to allow selection of the option,
// that view could be reopened and/or a message could be displayed).
@property (nonnull, copy) void (^setOption)(NSString *opt, void (^result)(BOOL accepted));
@end

@interface MuPDFDKWidgetRadio : MuPDFDKWidget
@property void (^toggle)(void);
@end

@interface MuPDFDKWidgetSignedSignature : MuPDFDKWidget
@property void (^verify)(id<PKCS7Verifier> verifier,
                         void (^result)(PKCS7VerifyResult r,
                                        int invalidChangePoint,
                                        id<PKCS7DesignatedName> name,
                                        id<PKCS7Description> description));
@end

@interface MuPDFDKWidgetUnsignedSignature : MuPDFDKWidget
@property BOOL wasCreatedInThisSession;
@property void (^sign)(id<PKCS7Signer> signer, void (^result)(BOOL accepted));
@end

@interface MuPDFDKRender : NSObject<ARDKRender>
@end

@interface MuPDFDKQuad : NSObject<NSCopying>
@property(readonly) CGPoint ul;
@property(readonly) CGPoint ll;
@property(readonly) CGPoint ur;
@property(readonly) CGPoint lr;
@property(readonly) CGRect enclosingRect;
@property(readonly) CGPoint leftCentre;
@property(readonly) CGPoint rightCentre;

+ (MuPDFDKQuad *)quadFromRect:(CGRect)rect;
@end

@interface MuPDFDKPage : NSObject<ARDKPage>
@property(strong, readonly) NSArray<MuPDFDKQuad *> *selectionQuads;
@property(strong, readonly) NSArray<MuPDFDKQuad *> *formFieldQuads;
@property(nonnull, copy) void (^onSelectionChanged)(void);

- (void)makeAreaSelectionFrom:(CGPoint)pt1 to:(CGPoint)pt2;

- (void)selectWordAt:(CGPoint)pt;

- (void)updateTextSelectionStart:(CGPoint)pt;

- (void)updateTextSelectionEnd:(CGPoint)pt;

- (void)forAnnotationsAtPt:(CGPoint)pt onPage:(void (^)(NSArray<MuPDFDKAnnotation *> *annots))block;

- (void)selectAnnotation:(MuPDFDKAnnotation *)annot;

- (void)selectAnnotationAt:(CGPoint)pt;

- (void)selectRedactionAt:(CGPoint)pt;

- (void)addInkAnnotationWithPaths:(NSArray<NSArray<NSValue *> *> *)paths
                            color:(UIColor *)color
                        thickness:(CGFloat)thickness;

- (BOOL)addTextAnnotationAt:(CGPoint)pt;

- (BOOL)addSignatureFieldAt:(CGPoint)pt;

- (void)createRedactionAnnotationFromSelection;

- (void)testAt:(CGPoint)pt forHyperlink:(void (^)(id<ARDKHyperlink> link))block;

- (void)tapAt:(CGPoint)pt onFocus:(void (^)(MuPDFDKWidget *widget))block;

- (void)focusNextWidget:(void (^)(MuPDFDKWidget *widget))block;

@end

@interface MuPDFDKDoc : NSObject<ARDKDoc>
@property(copy) NSString *documentAuthor;
@property BOOL pdfFormFillingEnabled;
@property BOOL pdfFormSigningEnabled;
@property(readonly) BOOL hasXFAForm;
@property MuPDFPrintProfile printProfile;
@property ARDKSoftProfile softProfile;
@property(nonnull, copy) void (^onSelectionChanged)(void);
@property(readonly) BOOL haveTextSelection;
@property(readonly) BOOL haveAnnotationSelection;
@property(readonly) BOOL selectionIsAnnotationWithText;
@property(readonly) BOOL selectionIsRedaction;
@property(readonly) BOOL selectionIsTextHighlight;
@property(readonly) BOOL selectionIsWidget;
@property(nullable, nonatomic, copy) NSString *selectedAnnotationsText;
@property(nullable, readonly) NSDate *selectedAnnotationsDate;
@property(nullable, readonly) NSString *selectedAnnotationsAuthor;
@property(nullable, readonly) NSArray<id<ARDKTocEntry>> *toc;
@property(nonnull, copy) void (^onAlert)(MuPDFAlert *alert);

- (void)clearFocus;

- (void)clearSelection;

- (void)forSelectedPages:(void (^)(NSInteger pageNo, NSArray<MuPDFDKQuad *> *quads))block;

- (void)addHighlightAnnotationLeaveSelected:(BOOL) leaveSelected;

- (void)addRedactAnnotation;

- (BOOL)hasRedactions;


- (void)finalizeRedactAnnotations:(void (^)(void))onComplete;

- (void)deleteSelectedAnnotation;

- (void)updateSelectedAnnotationsQuads;

typedef enum
{
    MuPDFDKSearch_Forwards,
    MuPDFDKSearch_Backwards
} MuPDFDKSearchDirection;

typedef enum
{
    MuPDFDKSearch_Progress,
    MuPDFDKSearch_Found,
    MuPDFDKSearch_NotFound,
    MuPDFDKSearch_Cancelled,
    MuPDFDKSearch_Error
} MuPDFDKSearchEvent;

/// Set the start location for a search
- (void)setSearchStartPage:(NSInteger)page offset:(CGPoint)offset;

/// Start a search operation
- (void)searchFor:(NSString *)text
      inDirection:(MuPDFDKSearchDirection)direction
          onEvent:(void (^)(MuPDFDKSearchEvent event, NSInteger page, CGRect area))block;

/// Cancel a progressing search
- (void)cancelSearch;

/// Close a completed search
- (void)closeSearch;

@end

@interface MuPDFDKLib : NSObject<ARDKLib>
@end

NS_ASSUME_NONNULL_END
