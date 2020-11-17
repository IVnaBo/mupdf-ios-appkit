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

/// List of printers profiles supported for
/// colour profiling
typedef enum
{
    MuPDFPrintProfile_USWebCoatedSWOP,
    MuPDFPrintProfile_CoatedFOGRA39,
    MuPDFPrintProfile_EuroscaleCoated,
    MuPDFPrintProfile_JapanWebCoated,
    MuPDFPrintProfile_None
} MuPDFPrintProfile;

/// List of icons that may be requested when
/// a PDF's Javascript issues an alert dialog
typedef enum
{
    MuPDFAlertIcon_Error,
    MuPDFAlertIcon_Warning,
    MuPDFAlertIcon_Question,
    MuPDFAlertIcon_Status
} MuPDFAlertIcon;

/// List of button types used within alert dialogs
/// issued by javascript within PDF documents
typedef enum
{
    MuPDFAlertButton_None,
    MuPDFAlertButton_Ok,
    MuPDFAlertButton_Cancel,
    MuPDFAlertButton_No,
    MuPDFAlertButton_Yes
} MuPDFAlertButton;

/// List of button groups used within alert dialogs
/// issued by javescript within PDF documents
typedef enum
{
    MuPDFAlertButtonGroup_Ok,
    MuPDFAlertButtonGroup_OkCancel,
    MuPDFAlertButtonGroup_YesNo,
    MuPDFAlertButtonGroup_YesNoCancel
} MuPDFAlertButtonGroup;

/// List of PDF annotation types
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

/// Class representing alert dialogs issued by javascript
/// within PDF documents
@interface MuPDFAlert : NSObject
@property(nullable, nonatomic, copy) NSString *message;
@property(nullable, nonatomic, copy) NSString *title;
@property MuPDFAlertIcon icon;
@property MuPDFAlertButtonGroup buttonGroup;
@property (nonnull, copy) void (^reply)(MuPDFAlertButton buttonPressed);
@end

/// Class representing the positions of the characters within a line of text
@interface MuPDFDKTextLayoutLine : NSObject
@property(readonly) CGRect lineRect;
@property(readonly) NSArray<NSValue *> *charRects;
@end

/// Class representing an annotations positon and type
@interface MuPDFDKAnnotation : NSObject
@property(readonly) MuPDFAnnotType type;
@property(readonly) CGRect rect;
@end

@class MuPDFDKWidgetText;
@class MuPDFDKWidgetList;
@class MuPDFDKWidgetRadio;
@class MuPDFDKWidgetSignedSignature;
@class MuPDFDKWidgetUnsignedSignature;

/// The base class of PDF widgets (i.e., objects appearing
/// within a PDF form
@interface MuPDFDKWidget : NSObject
@property CGRect rect;
@property MuPDFDKAnnotation *annot;
- (void)switchCaseText:(nonnull void (^)(MuPDFDKWidgetText *widget))textBlock
              caseList:(nonnull void (^)(MuPDFDKWidgetList *widget))listBlock
             caseRadio:(nonnull void (^)(MuPDFDKWidgetRadio *widget))radioBlock
   caseSignedSignature:(nonnull void (^)(MuPDFDKWidgetSignedSignature *widget))signedSignatureBlock
 caseUnsignedSignature:(nonnull void (^)(MuPDFDKWidgetUnsignedSignature *widget))unsignedSignatureBlock;
@end

/// Class representing text widgets
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

/// Class representing list and choice widgets
@interface MuPDFDKWidgetList : MuPDFDKWidget
@property(nullable, nonatomic, copy) NSArray<NSString *> *optionText;
// Update the widget's selected option. Because of javascript-based event handlers
// the update may be rejected. A block is passed that can respond to that
// possibility (e.g., if a modal view was used to allow selection of the option,
// that view could be reopened and/or a message could be displayed).
@property (nonnull, copy) void (^setOption)(NSString *opt, void (^result)(BOOL accepted));
@end

// Class representing radio widgets
@interface MuPDFDKWidgetRadio : MuPDFDKWidget
@property void (^toggle)(void);
@end

/// Class representing signature widgets that have been signed
@interface MuPDFDKWidgetSignedSignature : MuPDFDKWidget
@property BOOL unsaved;
@property void (^verify)(id<PKCS7Verifier> verifier,
                         void (^result)(PKCS7VerifyResult r,
                                        int invalidChangePoint,
                                        id<PKCS7DesignatedName> name,
                                        id<PKCS7Description> description));
@end

/// Class representing signature widgets that are yet to be signed
@interface MuPDFDKWidgetUnsignedSignature : MuPDFDKWidget
@property BOOL wasCreatedInThisSession;
@property void (^sign)(id<PKCS7Signer> signer, void (^result)(BOOL accepted));
@end

/// Class representing an ongoing background rendering of
/// part of a page
@interface MuPDFDKRender : NSObject<ARDKRender>
@end

/// Class representing a quadrilateral, often the bounding rectangle
/// of a rotated character.
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

/// Class representing a page of a PDF document
@interface MuPDFDKPage : NSObject<ARDKPage>
/// The quads that make up the current selection, either a section of
/// text a single annotation
@property(nullable, strong, readonly) NSArray<MuPDFDKQuad *> *selectionQuads;
/// The quads that bound the active form fields
@property(nullable, strong, readonly) NSArray<MuPDFDKQuad *> *formFieldQuads;
/// Block called when the selection changes
@property(nullable, copy) void (^onSelectionChanged)(void);

/// Create a rectangular selection, delimited by two points
- (void)makeAreaSelectionFrom:(CGPoint)pt1 to:(CGPoint)pt2;

/// Set the current selection to be a textual, encompassing
/// the word that closest to the specified point
- (void)selectWordAt:(CGPoint)pt;

/// Alter the start point of a text selection so as to
/// enclose fewer or more characters
- (void)updateTextSelectionStart:(CGPoint)pt;

/// Alter the end point of a text selection so as to
/// enclose fewer or more characters
- (void)updateTextSelectionEnd:(CGPoint)pt;

/// Perform an operation on the array of annotations that
/// encompasse a point
- (void)forAnnotationsAtPt:(CGPoint)pt onPage:(void (^)(NSArray<MuPDFDKAnnotation *> *annots))block;

/// Select the specified annotation
- (void)selectAnnotation:(MuPDFDKAnnotation *)annot;

/// Select the annotation at the specified point, if any.
/// This will ignore redaction annotations
- (void)selectAnnotationAt:(CGPoint)pt;

/// Select the redaction annotation at the specified point,
/// if any
- (void)selectRedactionAt:(CGPoint)pt;

/// Add an ink annotation with specified paths, color and thickness
- (void)addInkAnnotationWithPaths:(NSArray<NSArray<NSValue *> *> *)paths
                            color:(UIColor *)color
                        thickness:(CGFloat)thickness;

/// Add a pop up text annotation with it's icon at the specified point
- (BOOL)addTextAnnotationAt:(CGPoint)pt;

/// Add a digital signature fiels at the specified point
- (BOOL)addSignatureFieldAt:(CGPoint)pt;

/// Create a redaction annotation from the current text or area
/// selection
- (void)createRedactionAnnotationFromSelection;

/// Perform an operation on the hyperlink at the specified point.
/// If there is no hyperlink then the operation will be passed nil
- (void)testAt:(CGPoint)pt forHyperlink:(void (^)(id<ARDKHyperlink> _Nullable link))block;

/// Perform a tap, focus and perform an operation on the form widget,
/// if any, at the specified point. Nil will be passed to the operation
/// if there is no widget at the point
- (void)tapAt:(CGPoint)pt onFocus:(void (^)(MuPDFDKWidget *widget))block;

/// If a form widget is currently focussed then move the focus
/// to the next widget
- (void)focusNextWidget:(void (^)(MuPDFDKWidget * _Nullable widget))block;

@end

/// Class representing a PDF document while being viewed or altered
@interface MuPDFDKDoc : NSObject<ARDKDoc>
/// Author string used when creating annotations
@property(copy) NSString *documentAuthor;
/// Whether form filling is enabled
@property BOOL pdfFormFillingEnabled;
/// Whether form signing is enabled
@property BOOL pdfFormSigningEnabled;
/// Whether the document contains an XFA version of a form
@property(readonly) BOOL hasXFAForm;
/// The print profile currently in use
@property MuPDFPrintProfile printProfile;
/// The soft profile currently in use
@property ARDKSoftProfile softProfile;
/// Callback that can be set so as to monitor changes
/// in what is currently selected
@property(nullable, copy) void (^onSelectionChanged)(void);
/// Whether text is currently selected
@property(readonly) BOOL haveTextSelection;
/// Whether an annotation is currently selected
@property(readonly) BOOL haveAnnotationSelection;
/// Whether an annotation that has text is selected
@property(readonly) BOOL selectionIsAnnotationWithText;
/// Whether a redaction annotation is selected
@property(readonly) BOOL selectionIsRedaction;
/// Whether a text highlight annotation is selected
@property(readonly) BOOL selectionIsTextHighlight;
/// Whether a form widget is currently selected. Such a selection is
/// for the purpose of deleting or editing the widget. A widget being
/// selected differs from its being focussed for the purpose of
/// being filled in
@property(readonly) BOOL selectionIsWidget;
/// The text string associated with the selected annotation
@property(nullable, nonatomic, copy) NSString *selectedAnnotationsText;
/// The date associated with the selected annotation
@property(nullable, readonly) NSDate *selectedAnnotationsDate;
/// The author of the selected annotation
@property(nullable, readonly) NSString *selectedAnnotationsAuthor;
/// The table of contents
@property(nullable, readonly) NSArray<id<ARDKTocEntry>> *toc;
/// Call back that can be set so as to monitor alerts issued
/// by Javascript code within the document
@property(nullable, copy) void (^onAlert)(MuPDFAlert *alert);

/// Remove the focus from the current focussed form field, if
/// any
- (void)clearFocus;

/// Clear the current selection
- (void)clearSelection;

/// Perform an operation on the quads of the selection for each page that has a selection
- (void)forSelectedPages:(void (^)(NSInteger pageNo, NSArray<MuPDFDKQuad *> *quads))block;

/// Add a highlight selection based on the current text selection
/// unselect the text and leave the newly created annotation selected
- (void)addHighlightAnnotationLeaveSelected:(BOOL) leaveSelected;

/// Add a redaction annotation based on the currently selected text or area
- (void)addRedactAnnotation;

/// Whether the document has redaction annotations
- (BOOL)hasRedactions;

/// Perform redaction for all the locations defined by redaction
/// annotations
- (void)finalizeRedactAnnotations:(void (^)(void))onComplete;

/// Delete the currently selected annotation
- (void)deleteSelectedAnnotation;

/// Update the quads of the currently selected annotation to reflect
/// changes due to calls to updateSelectionStart and updateSelectionEnd
- (void)updateSelectedAnnotationsQuads;

/// List of search directions
typedef enum
{
    MuPDFDKSearch_Forwards,
    MuPDFDKSearch_Backwards
} MuPDFDKSearchDirection;

/// List of search states
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

/// Class representing the MuPDF render library
@interface MuPDFDKLib : NSObject<ARDKLib>
@end

NS_ASSUME_NONNULL_END
