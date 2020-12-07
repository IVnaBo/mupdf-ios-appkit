//
//  MuPDFDKLib.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 21/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#include "mupdf/fitz.h"
#include "mupdf/pdf.h"
#include "mupdf/ucdn.h"
#include "mupdfdk_stream.h"
#include "pdf_signer.h"
#import "ARDKGeometry.h"
#import "MuPDFDKLib.h"

#include "TargetConditionals.h"

#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
#if !defined(SODK_EXCLUDE_OPENSSL_PDF_SIGNING)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import <openssl/ssl.h>
#import <openssl/err.h>
#pragma clang diagnostic pop

#endif // SODK_EXCLUDE_OPENSSL_PDF_SIGNING
#endif // (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)

#if TARGET_OS_OSX
#import "platform-def.h"
#include "UIScreen.h"
#endif /* TARGET_OS_OSX */

#define FULL_THICKNESS (1.0)
#define VERTICALLY_CENTERED (0.5)
#define SEMI_TRANSPARENT (0.5)

#define UPDATE_BITMAP_PROPORTION (6)
#define INITIAL_FZPAGE_CACHE_SIZE (500)

static float highlight_color[] = {1.0, 1.0, 0.0};

static const char *queue_label = "com.artifex.mupdf.background";

static NSString * const documentAuthorKey = @"DocAuthKey";


static void dispatch_async_if_needed(dispatch_queue_t queue, void (^block)(void))
{
    if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), queue_label) == 0)
    {
        block();
    }
    else
    {
        dispatch_async(queue, block);
    }
}

static fz_point pt_to_fz(CGPoint pt)
{
    fz_point fzpt = {pt.x, pt.y};
    return fzpt;
}

static CGPoint pt_from_fz(fz_point pt)
{
    return CGPointMake(pt.x, pt.y);
}

static fz_rect rect_to_fz(CGRect rect)
{
    fz_rect fzrect = {rect.origin.x, rect.origin.y, rect.origin.x + rect.size.width, rect.origin.y + rect.size.height};
    return fzrect;
}

static CGRect rect_from_fz(fz_rect rect)
{
    return CGRectMake(rect.x0, rect.y0, rect.x1 - rect.x0, rect.y1 - rect.y0);
}

static fz_quad quad_to_fz(MuPDFDKQuad *mquad)
{
    fz_quad quad;
    quad.ll = pt_to_fz(mquad.ll);
    quad.lr = pt_to_fz(mquad.lr);
    quad.ul = pt_to_fz(mquad.ul);
    quad.ur = pt_to_fz(mquad.ur);
    return quad;
}

static MuPDFAnnotType annotTypeFromInt(int type)
{
    switch(type)
    {
        case PDF_ANNOT_TEXT: return MuPDFAnnotType_Text;
        case PDF_ANNOT_LINK: return MuPDFAnnotType_Link;
        case PDF_ANNOT_FREE_TEXT: return MuPDFAnnotType_FreeText;
        case PDF_ANNOT_LINE: return MuPDFAnnotType_Line;
        case PDF_ANNOT_SQUARE: return MuPDFAnnotType_Square;
        case PDF_ANNOT_CIRCLE: return MuPDFAnnotType_Circle;
        case PDF_ANNOT_POLYGON: return MuPDFAnnotType_Polygon;
        case PDF_ANNOT_POLY_LINE: return MuPDFAnnotType_PolyLine;
        case PDF_ANNOT_HIGHLIGHT: return MuPDFAnnotType_Highlight;
        case PDF_ANNOT_UNDERLINE: return MuPDFAnnotType_Underline;
        case PDF_ANNOT_SQUIGGLY: return MuPDFAnnotType_Squiggly;
        case PDF_ANNOT_STRIKE_OUT: return MuPDFAnnotType_StrikeOut;
        case PDF_ANNOT_REDACT: return MuPDFAnnotType_Redact;
        case PDF_ANNOT_STAMP: return MuPDFAnnotType_Stamp;
        case PDF_ANNOT_CARET: return MuPDFAnnotType_Caret;
        case PDF_ANNOT_INK: return MuPDFAnnotType_Ink;
        case PDF_ANNOT_POPUP: return MuPDFAnnotType_Popup;
        case PDF_ANNOT_FILE_ATTACHMENT: return MuPDFAnnotType_FileAttachment;
        case PDF_ANNOT_SOUND: return MuPDFAnnotType_Sound;
        case PDF_ANNOT_MOVIE: return MuPDFAnnotType_Movie;
        case PDF_ANNOT_WIDGET: return MuPDFAnnotType_Widget;
        case PDF_ANNOT_SCREEN: return MuPDFAnnotType_Screen;
        case PDF_ANNOT_PRINTER_MARK: return MuPDFAnnotType_PrinterMark;
        case PDF_ANNOT_TRAP_NET: return MuPDFAnnotType_TrapNet;
        case PDF_ANNOT_WATERMARK: return MuPDFAnnotType_Watermark;
        case PDF_ANNOT_3D: return MuPDFAnnotType_3d;
        case PDF_ANNOT_UNKNOWN:
        default: return MuPDFAnnotType_Unknown;
    }
}

static fz_stext_page *stext_for_page(fz_context *ctx, fz_page *page)
{
    fz_stext_page *text = NULL;
    fz_device *dev = NULL;
    fz_var(text);
    fz_var(dev);

    fz_try(ctx)
    {
        text = fz_new_stext_page(ctx, fz_bound_page(ctx, page));
        dev = fz_new_stext_device(ctx, text, NULL);
        fz_run_page(ctx, page, dev, fz_identity, NULL);
        fz_close_device(ctx, dev);
    }
    fz_always(ctx)
    {
        fz_drop_device(ctx, dev);
    }
    fz_catch(ctx)
    {
        fz_drop_stext_page(ctx, text);
        text = NULL;
    }

    return text;
}

static int widget_is_visible(fz_context *ctx, pdf_widget *widget)
{
    return pdf_signature_is_signed(ctx, widget->page->doc, widget->obj)
    || ((pdf_annot_flags(ctx, widget) & (PDF_ANNOT_IS_HIDDEN|PDF_ANNOT_IS_NO_VIEW)) == 0
        && (pdf_field_flags(ctx, widget->obj) & PDF_FIELD_IS_READ_ONLY) == 0);
}

static void get_fields_arrive_fn(fz_context *ctx, pdf_obj *obj, void *arg, pdf_obj **dummy)
{
    pdf_obj *fields = arg;
    if (pdf_name_eq(ctx, pdf_dict_get(ctx, obj, PDF_NAME(Type)), PDF_NAME(Annot))
        && pdf_name_eq(ctx, pdf_dict_get(ctx, obj, PDF_NAME(Subtype)), PDF_NAME(Widget)))
    {
        pdf_array_push(ctx, fields, obj);
    }
}

static pdf_obj *get_fields(fz_context *ctx, pdf_document *doc)
{
    pdf_obj *field_tree = pdf_dict_getp(ctx, pdf_trailer(ctx, doc), "Root/AcroForm/Fields");
    pdf_obj *fields = pdf_new_array(ctx, doc, 20);
    fz_try(ctx)
    {
        pdf_walk_tree(ctx, field_tree, PDF_NAME(Kids), get_fields_arrive_fn, NULL, fields, NULL, NULL);
    }
    fz_catch(ctx)
    {
        pdf_drop_obj(ctx, fields);
        fz_rethrow(ctx);
    }
    return fields;
}

static pdf_obj *get_field_names(fz_context *ctx, pdf_document *doc)
{
    pdf_obj *fields = get_fields(ctx, doc);
    int n = pdf_array_len(ctx, fields);
    pdf_obj *field_names = NULL;
    char *name = NULL;
    fz_var(field_names);
    fz_var(name);
    fz_try(ctx)
    {
        int i;
        field_names = pdf_new_array(ctx, doc, n);
        for (i = 0; i < n; i++)
        {
            name = pdf_field_name(ctx, pdf_array_get(ctx, fields, i));
            pdf_array_push_drop(ctx, field_names, pdf_new_name(ctx, name));
            fz_free(ctx, name);
            name = NULL;
        }
    }
    fz_always(ctx)
    {
        pdf_drop_obj(ctx, fields);
    }
    fz_catch(ctx)
    {
        fz_free(ctx, name);
        pdf_drop_obj(ctx, field_names);
        fz_rethrow(ctx);
    }
    return field_names;
}

static void make_unused_field_name(fz_context *ctx, pdf_document *doc, const char *fmt, char *buffer)
{
    pdf_obj *field_names = get_field_names(ctx, doc);
    fz_try(ctx)
    {
        int x = 0;
        for (;;)
        {
            int i, n = pdf_array_len(ctx, field_names);
            sprintf(buffer, fmt, x);
            for (i = 0; i < n; i++)
            {
                if (strcmp(buffer, pdf_to_name(ctx, pdf_array_get(ctx, field_names, i))) == 0)
                    break;
            }
            if (i == n)
                break;
            ++x;
        }
    }
    fz_always(ctx)
    {
        pdf_drop_obj(ctx, field_names);
    }
    fz_catch(ctx)
    {
        fz_rethrow(ctx);
    }
}

#define MAX_HITS (500)

@interface MuPDFDKQuad ()
+ (MuPDFDKQuad *)quadFromFzQuad:(fz_quad)fzQuad;
+ (NSArray<MuPDFDKQuad *> *)quadsFromFzQuads:(fz_quad *)qarray count:(int)count;
@end

static NSArray<MuPDFDKQuad *> *search_page(fz_context *ctx, fz_document *doc, fz_page *fzpage, const char *term)
{
    NSArray<MuPDFDKQuad *> *arr = nil;
    fz_stext_page *text = NULL;
    fz_quad *quads = NULL;
    int hit_count;

    fz_var(text);
    fz_var(quads);
    fz_try(ctx)
    {
        quads = fz_calloc(ctx, MAX_HITS, sizeof(fz_quad));
        text = stext_for_page(ctx, fzpage);
        hit_count = fz_search_stext_page(ctx, text, term, quads, MAX_HITS);
        arr = [MuPDFDKQuad quadsFromFzQuads:quads count:hit_count];
    }
    fz_always(ctx)
    {
        fz_drop_stext_page(ctx, text);
        fz_free(ctx, quads);
    }
    fz_catch(ctx)
    {
    }

    return arr ? arr : @[];
}

static void show_alert(MuPDFDKDoc *doc, pdf_alert_event *alert)
{
    assert (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), queue_label) == 0);
    // Correct response to some alerts requires waiting for the UI thread from this function,
    // which is called from the background thread. At the moment, we cannot do so because we
    // have other calls from the UI thread that wait on the background thread, and to have both
    // types risks deadlock. There are plans to pull out the text widget layout features of
    // mupdf into a separate module that can be called on a different thread from the rest of
    // mupdf; use of that may allow us to reenable alert responses.
#ifdef NUI_FORMS_ALERT_RESPONSE
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
#endif
    // Set up some defaults for when we have no handler
    alert->finally_checked = alert->initially_checked;
    alert->button_pressed = PDF_ALERT_BUTTON_OK;
    MuPDFAlert *malert = [[MuPDFAlert alloc] init];
    malert.title = @(alert->title ? alert->title : "");
    malert.message = @(alert->message ? alert->message : "");
    malert.icon = (MuPDFAlertIcon)alert->icon_type;
    malert.buttonGroup = (MuPDFAlertButtonGroup)alert->button_group_type;
    malert.reply = ^(MuPDFAlertButton buttonPressed) {
#ifdef NUI_FORMS_ALERT_RESPONSE
        alert->button_pressed = buttonPressed;
        dispatch_semaphore_signal(sem);
#endif
    };

    dispatch_async(dispatch_get_main_queue(), ^{
        if (doc.onAlert)
        {
            // There's an onAlert block. We can call it with the alert
            // details and it will call us back via the reply block,
            // whereupon we trigger the semaphore to allow show_alert to return.
            doc.onAlert(malert);
        }
        else
        {
            // No onAlert block. Trigger semaphore to allow show_alert to return with default values.
#ifdef NUI_FORMS_ALERT_RESPONSE
            dispatch_semaphore_signal(sem);
#endif
        }
    });

#ifdef NUI_FORMS_ALERT_RESPONSE
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
#endif
}

static void event_cb(fz_context *ctx, pdf_document *idoc, pdf_doc_event *event, void *data)
{
    MuPDFDKDoc *doc = (__bridge MuPDFDKDoc *)data;

    switch (event->type)
    {
        case PDF_DOCUMENT_EVENT_ALERT:
            show_alert(doc, pdf_access_alert_event(ctx, event));
            break;

        default:
            break;
    }
}

@implementation MuPDFAlert
@end

@implementation MuPDFDKQuad
- (instancetype)initWithRect:(CGRect)rect
{
    self = [super init];
    if (self)
    {
        CGFloat minX = CGRectGetMinX(rect);
        CGFloat minY = CGRectGetMinY(rect);
        CGFloat maxX = CGRectGetMaxX(rect);
        CGFloat maxY = CGRectGetMaxY(rect);
        _ul = CGPointMake(minX, minY);
        _ll = CGPointMake(minX, maxY);
        _ur = CGPointMake(maxX, minY);
        _lr = CGPointMake(maxX, maxY);
    }
    return self;
}

- (instancetype)initWithFzQuad:(fz_quad)fzQuad
{
    self = [super init];
    if (self)
    {
        _ul = pt_from_fz(fzQuad.ul);
        _ll = pt_from_fz(fzQuad.ll);
        _ur = pt_from_fz(fzQuad.ur);
        _lr = pt_from_fz(fzQuad.lr);
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    MuPDFDKQuad *c = [[self.class alloc] init];
    c->_ul = _ul;
    c->_ll = _ll;
    c->_ur = _ur;
    c->_lr = _lr;
    return c;
}

- (CGRect)enclosingRect
{
    CGSize zeroSize = {0,0};
    CGRect ulRect = {_ul, zeroSize};
    CGRect llRect = {_ll, zeroSize};
    CGRect urRect = {_ur, zeroSize};
    CGRect lrRect = {_lr, zeroSize};
    return CGRectUnion(ulRect, CGRectUnion(llRect, CGRectUnion(urRect, lrRect)));
}

- (CGPoint)leftCentre
{
    return CGPointMake((_ul.x + _ll.x)/2.0, (_ul.y + _ll.y)/2.0);
}

- (CGPoint)rightCentre
{
    return CGPointMake((_ur.x + _lr.x)/2.0, (_ur.y + _lr.y)/2.0);
}

+ (MuPDFDKQuad *)quadFromRect:(CGRect)rect
{
    return [[MuPDFDKQuad alloc] initWithRect:rect];
}

+ (MuPDFDKQuad *)quadFromFzQuad:(fz_quad)fzQuad
{
    return [[MuPDFDKQuad alloc] initWithFzQuad:fzQuad];
}

+ (NSArray<MuPDFDKQuad *> *)quadsFromFzQuads:(fz_quad *)qarray count:(int)count
{
    NSMutableArray<MuPDFDKQuad *> *quads = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++)
        [quads addObject:[MuPDFDKQuad quadFromFzQuad:qarray[i]]];

    return quads;
}
@end

@protocol MuPDFDKSelection <NSObject>
// If quads is nil then the selection is a rectangle from
// startPt to endPt
@property(readonly) NSArray<MuPDFDKQuad *> *quads;
@property(readonly) CGPoint startPt;
@property(readonly) CGPoint endPt;

- (void)update:(NSObject<MuPDFDKSelection> *)newSelection;

@end

// The rectangle defined by the start and end points
static CGRect selectionAsRect(NSObject<MuPDFDKSelection> *selection)
{
    return CGRectStandardize(CGRectMake(selection.startPt.x, selection.startPt.y,
                                        selection.endPt.x - selection.startPt.x, selection.endPt.y - selection.startPt.y));
}

// Even when a selection has no quads, we sometimes need to interpret the one
// rectangle from startPt to endPt as an array of quads
static NSArray<MuPDFDKQuad *> *selectionAsQuads(NSObject<MuPDFDKSelection> *selection)
{
    if (selection.quads)
    {
        return selection.quads;
    }
    else
    {
        return @[[MuPDFDKQuad quadFromRect:selectionAsRect(selection)]];
    }
}

@interface MuPDFDKTextSelection : NSObject<MuPDFDKSelection>

+ (MuPDFDKTextSelection *)selectionWithQuads:(NSArray<MuPDFDKQuad *> *)quads startPt:(CGPoint)startPt endPt:(CGPoint)endPt;

@end

@implementation MuPDFDKTextSelection
@synthesize quads = _quads, startPt = _startPt, endPt = _endPt;

+ (MuPDFDKTextSelection *)selectionWithQuads:(NSArray<MuPDFDKQuad *> *)quads startPt:(CGPoint)startPt endPt:(CGPoint)endPt
{
    MuPDFDKTextSelection *selection = [[MuPDFDKTextSelection alloc] init];
    if (selection)
    {
        selection->_quads = quads;
        selection->_startPt = startPt;
        selection->_endPt = endPt;
    }
    return selection;
}

- (void)update:(NSObject<MuPDFDKSelection> *)newSelection
{
    _quads = newSelection.quads;
    _startPt = newSelection.startPt;
    _endPt = newSelection.endPt;
}

@end

@implementation MuPDFDKAnnotation
-(instancetype)initWithType:(MuPDFAnnotType)type andRect:(CGRect)rect
{
    self = [super init];
    if (self)
    {
        _type = type;
        _rect = rect;
    }

    return self;
}
@end

@interface MuPDFDKAnnotationInternal : MuPDFDKAnnotation<MuPDFDKSelection>
-(instancetype) initFromAnnot:(pdf_annot *)annot andIndex:(NSInteger)index withCtx:(fz_context *)ctx;
@property(readonly) BOOL isWidget;
@property(readonly) NSInteger index;
@property(readonly) BOOL hasText;
@property NSString *text;
@property(readonly) NSDate *date;
@property(readonly) NSString *author;
+(MuPDFDKAnnotationInternal *) annotFromAnnot:(pdf_annot *)annot andIndex:(NSInteger)index withCtx:(fz_context *)ctx;
+(NSArray<MuPDFDKAnnotationInternal *> *)annotsFromPage:(fz_page *)page withCtx:(fz_context *)ctx;
@end

@implementation MuPDFDKAnnotationInternal
@synthesize quads = _quads, startPt = _startPt, endPt = _endPt;

-(instancetype) initFromAnnot:(pdf_annot *)annot andIndex:(NSInteger)index withCtx:(fz_context *)ctx
{
    MuPDFAnnotType type = annotTypeFromInt(pdf_annot_type(ctx, annot));
    CGRect rect = rect_from_fz(pdf_bound_annot(ctx, annot));
    NSMutableArray<MuPDFDKQuad *> *quads = nil;
    if (pdf_annot_has_quad_points(ctx, annot))
    {
        int count = pdf_annot_quad_point_count(ctx, annot);
        if (count)
        {
            quads = [NSMutableArray arrayWithCapacity:count];
            for (int i = 0; i < count; i++)
                [quads addObject:[MuPDFDKQuad quadFromFzQuad:pdf_annot_quad_point(ctx, annot, i)]];
        }
    }

    self = [super initWithType:type andRect:rect];
    if (self)
    {
        _isWidget = (type == MuPDFAnnotType_Widget);
        _index = index;

        _quads = quads;
        _startPt = quads ? quads.firstObject.leftCentre : rect.origin;
        _endPt = quads ? quads.lastObject.rightCentre : CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
        if (type == MuPDFAnnotType_Text || type == MuPDFAnnotType_Highlight)
        {
            _hasText = YES;
            const char *contents = pdf_annot_contents(ctx, annot);
            _text = @(contents);
            const char *author = pdf_annot_author(ctx, annot);
            _author = @(author);
            _date = [NSDate dateWithTimeIntervalSince1970:pdf_annot_modification_date(ctx, annot)];
        }
    }
    return self;
}

- (void)update:(NSObject<MuPDFDKSelection> *)newSelection
{
    _quads = newSelection.quads;
    _startPt = newSelection.startPt;
    _endPt = newSelection.endPt;
}

+(MuPDFDKAnnotationInternal *) annotFromAnnot:(pdf_annot *)annot andIndex:(NSInteger)index withCtx:(fz_context *)ctx
{
    return [[MuPDFDKAnnotationInternal alloc] initFromAnnot:annot andIndex:index withCtx:ctx];
}

+(NSArray<MuPDFDKAnnotationInternal *> *)annotsFromPage:(fz_page *)page withCtx:(fz_context *)ctx
{
    NSMutableArray<MuPDFDKAnnotationInternal *> *annots = [NSMutableArray array];

    NSInteger index = 0;
    for (pdf_annot *annot = pdf_first_annot(ctx, (pdf_page *)page); annot; annot = pdf_next_annot(ctx, annot))
    {
        [annots addObject:[MuPDFDKAnnotationInternal annotFromAnnot:annot andIndex:index withCtx:ctx]];
        index++ ;
    }

    return  annots;
}
@end

static MuPDFDKTextSelection *selBetween(fz_context *ctx, fz_stext_page *text, CGPoint start, CGPoint end)
{
    NSArray<MuPDFDKQuad *> *arr = nil;
    fz_quad *quads = NULL;
    fz_var(quads);
    fz_try(ctx)
    {
        quads = fz_malloc_array(ctx, MAX_HITS, fz_quad);
        int nquads = fz_highlight_selection(ctx, text, pt_to_fz(start), pt_to_fz(end), quads, MAX_HITS);
        arr = [MuPDFDKQuad quadsFromFzQuads:quads count:nquads];
    }
    fz_always(ctx)
    {
        fz_free(ctx, quads);
    }
    fz_catch(ctx)
    {
    }

    return [MuPDFDKTextSelection selectionWithQuads:arr startPt:start endPt:end];
}

static MuPDFDKTextSelection *selWord(fz_context *ctx, fz_stext_page *text, CGPoint pt)
{
    fz_point start_anchor = pt_to_fz(pt);
    fz_point end_anchor = start_anchor;

    fz_quad handles = fz_snap_selection(ctx, text, &start_anchor, &end_anchor, FZ_SELECT_WORDS);
    if (handles.ll.x == handles.ul.x && handles.ll.y == handles.ul.y)
        return nil;
    else
        return selBetween(ctx, text, pt_from_fz(start_anchor), pt_from_fz(end_anchor));
}

@implementation MuPDFDKWidget
- (void)switchCaseText:(void (^)(MuPDFDKWidgetText *))textBlock
              caseList:(void (^)(MuPDFDKWidgetList *))listBlock
             caseRadio:(void (^)(MuPDFDKWidgetRadio *))radioBlock
   caseSignedSignature:(void (^)(MuPDFDKWidgetSignedSignature *))signedSignatureBlock
 caseUnsignedSignature:(void (^)(MuPDFDKWidgetUnsignedSignature *))unsignedSignatureBlock
{
}
@end

@implementation MuPDFDKWidgetText
- (void)switchCaseText:(void (^)(MuPDFDKWidgetText *))textBlock
              caseList:(void (^)(MuPDFDKWidgetList *))listBlock
             caseRadio:(void (^)(MuPDFDKWidgetRadio *))radioBlock
   caseSignedSignature:(void (^)(MuPDFDKWidgetSignedSignature *))signedSignatureBlock
 caseUnsignedSignature:(void (^)(MuPDFDKWidgetUnsignedSignature *))unsignedSignatureBlock
{
    textBlock(self);
}
@end

@implementation MuPDFDKWidgetList
- (void)switchCaseText:(void (^)(MuPDFDKWidgetText *))textBlock
              caseList:(void (^)(MuPDFDKWidgetList *))listBlock
             caseRadio:(void (^)(MuPDFDKWidgetRadio *))radioBlock
   caseSignedSignature:(void (^)(MuPDFDKWidgetSignedSignature *))signedSignatureBlock
 caseUnsignedSignature:(void (^)(MuPDFDKWidgetUnsignedSignature *))unsignedSignatureBlock
{
    listBlock(self);
}
@end

@implementation MuPDFDKWidgetRadio
- (void)switchCaseText:(void (^)(MuPDFDKWidgetText *))textBlock
              caseList:(void (^)(MuPDFDKWidgetList *))listBlock
             caseRadio:(void (^)(MuPDFDKWidgetRadio *))radioBlock
   caseSignedSignature:(void (^)(MuPDFDKWidgetSignedSignature *))signedSignatureBlock
 caseUnsignedSignature:(void (^)(MuPDFDKWidgetUnsignedSignature *))unsignedSignatureBlock
{
    radioBlock(self);
}
@end

@implementation MuPDFDKWidgetSignedSignature
- (void)switchCaseText:(void (^)(MuPDFDKWidgetText *))textBlock
              caseList:(void (^)(MuPDFDKWidgetList *))listBlock
             caseRadio:(void (^)(MuPDFDKWidgetRadio *))radioBlock
   caseSignedSignature:(void (^)(MuPDFDKWidgetSignedSignature *))signedSignatureBlock
 caseUnsignedSignature:(void (^)(MuPDFDKWidgetUnsignedSignature *))unsignedSignatureBlock
{
    signedSignatureBlock(self);
}
@end

@implementation MuPDFDKWidgetUnsignedSignature
- (void)switchCaseText:(void (^)(MuPDFDKWidgetText *))textBlock
              caseList:(void (^)(MuPDFDKWidgetList *))listBlock
             caseRadio:(void (^)(MuPDFDKWidgetRadio *))radioBlock
   caseSignedSignature:(void (^)(MuPDFDKWidgetSignedSignature *))signedSignatureBlock
 caseUnsignedSignature:(void (^)(MuPDFDKWidgetUnsignedSignature *))unsignedSignatureBlock
{
    unsignedSignatureBlock(self);
}
@end


@interface MuPDFDKWeakEventTarget : NSObject
@property(weak)id<ARDKDocumentEventTarget>target;
+ (instancetype)weakHolder:(id<ARDKDocumentEventTarget>)target;
@end

@implementation MuPDFDKWeakEventTarget
+ (instancetype)weakHolder:(id<ARDKDocumentEventTarget>)target
{
    MuPDFDKWeakEventTarget *targetWeak = [[MuPDFDKWeakEventTarget alloc] init];
    targetWeak.target = target;
    return targetWeak;
}
@end

@interface FzPage : NSObject
@property(readonly) fz_page *fzpage;

+ (FzPage *)pageFromPage:(fz_page *)fzpage ofDoc:(MuPDFDKDoc *)doc;
@end

@interface MuPDFDKLib ()
@property dispatch_queue_t queue;
@property(readonly) fz_context *ctx;
@property ARDKBitmap *updateBm;
@end

@interface MuPDFDKDoc ()
@property NSMutableSet<NSNumber *> *pagesWithRedactions;
@property(readonly) MuPDFDKLib *mulib;
@property(readonly) NSString *path;
@property(readonly) fz_stream *stream;
@property(readonly) fz_document *fzdoc;
@property(readonly) NSMutableArray<NSValue *> *pageSizes;
@property(readonly) NSMutableArray<MuPDFDKWeakEventTarget *> *eventTargets;
// Although currently selections are restricted to a single page, we use a representation
// that will permit selections to extend over several pages. In the case of annotation
// selections, the representation allows for selections on multiple pages, but only a single
// annotation on any page. That may turn out not to be a useful generalisation, but it gives
// the code a common pattern.
@property(readonly) NSMutableDictionary<NSNumber *, NSObject<MuPDFDKSelection> *> *selections;
@property BOOL loadAborted;
@property NSInteger focusPageNumber;

// Search state
@property NSString *searchText;
@property NSInteger searchStartPage;
@property NSInteger searchPage;
@property NSArray<MuPDFDKQuad *> *searchHits;
@property NSInteger searchCurrentHit;
@property BOOL searchCancelled;

// Some actions need delaying until ongoing background tasks have
// completed.
- (void)doAfterBackgroundTasks:(void (^)(void))block;

- (FzPage *)getFzPage:(NSInteger)pageNumber;
- (void)selectionChangedForPage:(NSInteger)pageNo;
- (void)updatePageNumbered:(NSInteger)pageNo changedRects:(NSArray<NSValue *> *)rects;
- (void)updatePages;
- (void)updatePagesRecalc:(BOOL)recalc;
- (void)findFormFields;
- (void)setSelectionIsRedaction:(BOOL)isRedaction;
- (void)selectAnnotation:(MuPDFDKAnnotation *)annot onPage:(NSInteger)pageNum;
@end

@implementation MuPDFDKRender

- (void)abort
{
}

@end

@interface MuPDFDKHyperlink : NSObject<ARDKHyperlink>
@property NSInteger page;
@property CGRect rect;
@property NSString *url;
@end

@implementation MuPDFDKHyperlink

- (void)handleCaseInternal:(void (^)(NSInteger, CGRect))iblock orCaseExternal:(void (^)(NSURL *))eblock
{
    if (self.page != -1 && iblock)
        iblock(self.page, self.rect);
    else if (self.url && eblock)
        eblock([NSURL URLWithString:self.url]);
}

@end

@interface MuPDFDKTocEntry : MuPDFDKHyperlink<ARDKTocEntry>
@end

@implementation MuPDFDKTocEntry
@synthesize label, depth, open, children;

@end

@implementation MuPDFDKTextLayoutLine
- (instancetype)initWithLineRect:(CGRect)lineRect andCharRects:(NSArray<NSValue *> *)charRects
{
    self = [super init];
    if (self)
    {
        self->_lineRect = lineRect;
        self->_charRects = charRects;
    }
    return self;
}
+ (MuPDFDKTextLayoutLine *)layoutWithLineRect:(CGRect)lineRect andCharRects:(NSArray<NSValue *> *)charRects
{
    return [[MuPDFDKTextLayoutLine alloc] initWithLineRect:lineRect andCharRects:charRects];
}
@end

@interface MuPDFDKPage ()
@property(readonly) MuPDFDKDoc *doc;
@property(readonly) void (^update)(CGRect);
@property BOOL displayListDirty;
@property BOOL textDirty;
@property(readonly) fz_page *fzpage;
@property(readonly) fz_display_list *list;
@property(readonly) NSMutableArray<NSValue *> *newlyCreatedSignatures;
@end

@implementation MuPDFDKPage
{
    NSInteger _pageNum;
    FzPage *_fzpageobj;
    fz_display_list *_list;
    fz_stext_page *_text;
}

@synthesize size = _size;

- (fz_page *)fzpage
{
    if (!_fzpageobj)
        _fzpageobj = [self.doc getFzPage:self->_pageNum];

    if (_fzpageobj.fzpage == NULL)
        fz_throw(self.doc.mulib.ctx, FZ_ERROR_MEMORY, "");

    return _fzpageobj.fzpage;
}

- (fz_display_list *)list
{
    if (_list == NULL)
        _list = fz_new_display_list_from_page(self.doc.mulib.ctx, self.fzpage);

    return _list;
}

- (void)drop_list
{
    fz_drop_display_list(self.doc.mulib.ctx, _list);
    _list = NULL;
}

- (void)drop_page
{
    _fzpageobj = nil;
}

- (void)forgetSignatures
{
    _newlyCreatedSignatures = [NSMutableArray array];
}

- (instancetype)initForPage:(NSInteger)pageNum ofDoc:(MuPDFDKDoc *)doc withSize:(CGSize)size update:(void (^)(CGRect))block
{
    self = [super init];
    if (self)
    {
        _doc = doc;
        _size = size;
        _pageNum = pageNum;
        _update = block;
        _newlyCreatedSignatures = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    fz_context *ctx = _doc.mulib.ctx;
    fz_stext_page *text = _text;
    fz_display_list *list = _list;
    dispatch_async_if_needed(_doc.mulib.queue, ^{
        fz_drop_stext_page(ctx, text);
        fz_drop_display_list(ctx, list);
    });
}

- (void)findFormFields
{
    dispatch_async(self.doc.mulib.queue, ^{
        NSMutableArray<MuPDFDKQuad *> *quads = [NSMutableArray array];
        fz_context *ctx = self.doc.mulib.ctx;
        fz_try(ctx)
        {
            pdf_widget *widget;
            pdf_document *idoc = pdf_document_from_fz_document(ctx, self.doc.fzdoc);
            if (idoc)
            {
                for (widget = pdf_first_widget(ctx, (pdf_page *)self.fzpage); widget; widget = pdf_next_widget(ctx, widget))
                {
                    if (widget_is_visible(ctx, widget)
                        && !widget->is_hot)
                        [quads addObject:[MuPDFDKQuad quadFromRect:rect_from_fz(pdf_bound_widget(ctx, widget))]];
                }
            }
        }
        fz_catch(ctx)
        {
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self->_formFieldQuads = quads;
            if (self.onSelectionChanged)
                self.onSelectionChanged();
        });
    });
}

- (ARError)doRenderAtZoom:(CGFloat)zoom withDocOrigin:(CGPoint)orig intoBitmap:(ARDKBitmap *)bm
{
    assert (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), queue_label) == 0);
    ARDKBitmapInfo bmInfo = bm.asBitmap;
    fz_context *ctx = self.doc.mulib.ctx;
    fz_pixmap *pixmap = NULL;
    fz_device *dev = NULL;
    fz_matrix matrix;
    ARError err = 0;

    fz_var(pixmap);
    fz_var(dev);
    fz_var(err);

    fz_try(ctx)
    {
        if (self.displayListDirty)
        {
            [self drop_list];
            self.displayListDirty = NO;
        }

        // FIXME: Make render account for profiles
        // MuPDFPrintProfile printProfile = self.doc.printProfile;
        // ARDKSoftProfile softProfile = self.doc.softProfile;

        pixmap = fz_new_pixmap_with_data(ctx, fz_device_rgb(ctx), bmInfo.width, bmInfo.height, NULL, 1, bmInfo.lineSkip, bmInfo.memptr);
        matrix = fz_pre_scale(fz_translate(orig.x, orig.y), zoom, zoom);
        fz_clear_pixmap_with_value(ctx, pixmap, 0xFF);
        dev = fz_new_draw_device(ctx, matrix, pixmap);
        fz_run_display_list(ctx, self.list, dev, fz_identity, fz_infinite_rect, NULL);
        [self drop_list];
        fz_close_device(ctx, dev);
    }
    fz_always(ctx)
    {
        fz_drop_pixmap(ctx, pixmap);
        fz_drop_device(ctx, dev);
    }
    fz_catch(ctx)
    {
        err = 1;
    }

    return err;
}
- (ARError)doRenderAtZoom:(CGFloat)zoom withDocOrigin:(CGPoint)orig intoBitmap:(ARDKBitmap *)bm usingUpdateBuffer:(BOOL)update
{
    if (update)
    {
        ARError err = 0;
        MuPDFDKLib *lib = self.doc.mulib;

        if (!lib.updateBm)
        {
            UIScreen *screen = [UIScreen mainScreen];
            CGSize size = ARCGSizeScale(screen.bounds.size, screen.scale);
            lib.updateBm = [ARDKBitmap bitmapAtSize:CGSizeMake(size.width, size.height/UPDATE_BITMAP_PROPORTION) ofType:ARDKBitmapType_RGBA8888];
        }

        [lib.updateBm adjustToWidth:bm.width];

        NSInteger yOff = 0;
        while (yOff < bm.height)
        {
            if (yOff + lib.updateBm.height > bm.height)
                [lib.updateBm adjustToSize:CGSizeMake(bm.width, bm.height - yOff)];
            err = [self doRenderAtZoom:zoom withDocOrigin:CGPointMake(orig.x, orig.y - yOff) intoBitmap:lib.updateBm];
            if (err) break;
            ARDKBitmap *sub = [ARDKBitmap bitmapFromSubarea:CGRectMake(0, yOff, lib.updateBm.width, lib.updateBm.height) ofBitmap:bm];
            [sub copyFrom:lib.updateBm];
            yOff += lib.updateBm.height;
        }

        return err;
    }
    else
    {
         return [self doRenderAtZoom:zoom withDocOrigin:orig intoBitmap:bm];
    }
}

- (id<ARDKRender>)renderAtZoom:(CGFloat)zoom withDocOrigin:(CGPoint)orig intoBitmap:(ARDKBitmap *)bm progress:(void (^)(ARError))block
{
    dispatch_async(self.doc.mulib.queue, ^{
        ARError err = [self doRenderAtZoom:zoom withDocOrigin:orig intoBitmap:bm usingUpdateBuffer:NO];
        [bm doDarkModeConversion]; // Does nothing if bm's darkMode flag isn't set
        dispatch_async(dispatch_get_main_queue(), ^{
            block(err);
        });
    });
    return [[MuPDFDKRender alloc] init];
}

- (id<ARDKRender>)updateAtZoom:(CGFloat)zoom withDocOrigin:(CGPoint)orig intoBitmap:(ARDKBitmap *)bm progress:(void (^)(ARError))block
{
    dispatch_async(self.doc.mulib.queue, ^{
        ARError err = [self doRenderAtZoom:zoom withDocOrigin:orig intoBitmap:bm usingUpdateBuffer:YES];
        [bm doDarkModeConversion]; // Does nothing if bm's darkMode flag isn't set
        dispatch_async(dispatch_get_main_queue(), ^{
            block(err);
        });
    });
    return [[MuPDFDKRender alloc] init];
}

- (ARError)renderAtZoom:(CGFloat)zoom withDocOrigin:(CGPoint)orig intoBitmap:(ARDKBitmap *)bm
{
    __block ARError err;
    dispatch_sync(self.doc.mulib.queue, ^{
        err = [self doRenderAtZoom:zoom withDocOrigin:orig intoBitmap:bm usingUpdateBuffer:NO];
    });
    return err;
}


// MuPDF does not support layers


- (ARError)renderLayer:(int)layer atZoom:(CGFloat)zoom withDocOrigin:(CGPoint)orig intoBitmap:(ARDKBitmap *)bm
{
    return 0;
}


- (ARError)renderLayer:(int)layer atZoom:(CGFloat)zoom withDocOrigin:(CGPoint)orig intoBitmap:(ARDKBitmap *)bm andAlpha:(ARDKBitmap *)am
{
    return 0;
}


- (id<ARDKRender>)renderLayer:(int)layer atZoom:(CGFloat)zoom withDocOrigin:(CGPoint)orig intoBitmap:(ARDKBitmap *)bm progress:(void (^)(ARError))block
{
    return 0;
}

- (id<ARDKRender>)renderLayer:(int)layer usingUpdateBuffer:(BOOL)update atZoom:(CGFloat)zoom withDocOrigin:(CGPoint)orig intoBitmap:(ARDKBitmap *)bm andAlpha:(ARDKBitmap *)am progress:(void (^)(ARError))block
{
    return 0;
}



- (void)getText:(void (^)(fz_stext_page *))block
{
    dispatch_async(self.doc.mulib.queue, ^{
        if (self->_textDirty)
        {
            fz_drop_stext_page(self.doc.mulib.ctx, self->_text);
            self->_text = NULL;
            self->_textDirty = NO;
        }

        if (!self->_text)
        {
            self->_text = stext_for_page(self.doc.mulib.ctx, self.fzpage);
        }

        block(self->_text);
    });
}

- (NSArray<MuPDFDKQuad *> *)selectionQuads
{
    if (_pageNum == self.doc.searchPage && self.doc.searchHits)
    {
        return @[self.doc.searchHits[self.doc.searchCurrentHit]];
    }
    else
    {
        return selectionAsQuads(self.doc.selections[@(_pageNum)]);
    }
}

- (void)selectBetween:(CGPoint)pt1 and:(CGPoint)pt2
{
    [self getText:^(fz_stext_page *text) {
        MuPDFDKTextSelection *textSelection = selBetween(self.doc.mulib.ctx, text, pt1, pt2);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (textSelection)
            {
                // If there's already a current selection then update it rather than overwrite it.
                // It may be an annotation in which case we just want to update our cached record
                // of the quads for later writing back to the document.
                NSObject<MuPDFDKSelection> *currentSelection = self.doc.selections[@(self->_pageNum)];
                if (currentSelection)
                    [currentSelection update:textSelection];
                else
                    self.doc.selections[@(self->_pageNum)] = textSelection;

                [self.doc selectionChangedForPage:self->_pageNum];

                if (self.doc.onSelectionChanged)
                    self.doc.onSelectionChanged();
                for (MuPDFDKWeakEventTarget *weakTarget in self.doc.eventTargets)
                    if ([weakTarget.target respondsToSelector:@selector(selectionHasChanged)])
                        [weakTarget.target selectionHasChanged];
            }
        });
    }];
}

- (void)updateSelectionRectFrom:(CGPoint)pt1 and:(CGPoint)pt2
{
    NSObject<MuPDFDKSelection> *currentSelection = self.doc.selections[@(self->_pageNum)];
    if (currentSelection)
    {
        // Slight trick. Create a text selection with no quads to update the rectangle of the current selection
        [currentSelection update:[MuPDFDKTextSelection selectionWithQuads:nil startPt:pt1 endPt:pt2]];
        [self.doc selectionChangedForPage:self->_pageNum];

        if (self.doc.onSelectionChanged)
            self.doc.onSelectionChanged();

        for (MuPDFDKWeakEventTarget *weakTarget in self.doc.eventTargets)
            if ([weakTarget.target respondsToSelector:@selector(selectionHasChanged)])
                [weakTarget.target selectionHasChanged];
    }
}

- (void)makeAreaSelectionFrom:(CGPoint)pt1 to:(CGPoint)pt2
{
    self.doc.selections[@(self->_pageNum)] = [MuPDFDKTextSelection selectionWithQuads:nil startPt:pt1 endPt:pt2];
    [self.doc selectionChangedForPage:self->_pageNum];

    if (self.doc.onSelectionChanged)
        self.doc.onSelectionChanged();
    for (MuPDFDKWeakEventTarget *weakTarget in self.doc.eventTargets)
        if ([weakTarget.target respondsToSelector:@selector(selectionHasChanged)])
            [weakTarget.target selectionHasChanged];
}

- (void)selectWordAt:(CGPoint)pt
{
    [self.doc closeSearch];
    [self.doc clearSelection];
    [self getText:^(fz_stext_page *text) {
        MuPDFDKTextSelection *quads = selWord(self.doc.mulib.ctx, text, pt);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (quads)
            {
                self.doc.selections[@(self->_pageNum)] = quads;
                [self.doc selectionChangedForPage:self->_pageNum];

                if (self.doc.onSelectionChanged)
                    self.doc.onSelectionChanged();
                for (MuPDFDKWeakEventTarget *weakTarget in self.doc.eventTargets)
                    if ([weakTarget.target respondsToSelector:@selector(selectionHasChanged)])
                        [weakTarget.target selectionHasChanged];
            }
        });
    }];
}

- (void)updateTextSelectionStart:(CGPoint)pt
{
    NSObject<MuPDFDKSelection> *currentSelection = self.doc.selections[@(self->_pageNum)];
    // For now, we will allow selections only within a single page
    if (currentSelection)
    {
        if (currentSelection.quads)
            [self selectBetween:pt and:currentSelection.endPt];
        else
            [self updateSelectionRectFrom:pt and:currentSelection.endPt];
    }
}

- (void)updateTextSelectionEnd:(CGPoint)pt
{
    NSObject<MuPDFDKSelection> *currentSelection = self.doc.selections[@(self->_pageNum)];
    // For now, we will allow selections only within a single page
    if (currentSelection)
    {
        if (currentSelection.quads)
            [self selectBetween:currentSelection.startPt and:pt];
        else
            [self updateSelectionRectFrom:currentSelection.startPt and:pt];
    }
}

- (void)selectAnnotation:(MuPDFDKAnnotation *)annot
{
    [self.doc selectAnnotation:annot onPage:self->_pageNum];

}

- (void)forAnnotationsOnPage:(void (^)(NSArray<MuPDFDKAnnotation *> *annots))block
{
    dispatch_async(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        fz_try(ctx)
        {
            if (pdf_document_from_fz_document(self.doc.mulib.ctx, self.doc.fzdoc))
            {
                NSArray<MuPDFDKAnnotationInternal *> *annots = [MuPDFDKAnnotationInternal annotsFromPage:self.fzpage withCtx:ctx];
                dispatch_async(dispatch_get_main_queue(), ^{
                    block(annots);
                });
            }
        }
        fz_catch(ctx)
        {
        }
    });
}

- (void)forAnnotationsAtPt:(CGPoint)pt onPage:(void (^)(NSArray<MuPDFDKAnnotation *> *annots))block
{
    [self forAnnotationsOnPage:^(NSArray<MuPDFDKAnnotation *> *annots) {
        NSMutableArray<MuPDFDKAnnotation *> *annotsAtPt = [NSMutableArray arrayWithCapacity:annots.count];
        for (MuPDFDKAnnotation *annot in annots)
        {
            if (CGRectContainsPoint(annot.rect, pt))
                [annotsAtPt addObject:annot];
        }

        block(annotsAtPt);
    }];
}

- (void)selectAnnotationAt:(CGPoint)pt redactions:(BOOL)redactions
{
    [self.doc clearSelection];
    [self forAnnotationsAtPt:pt onPage:^(NSArray<MuPDFDKAnnotation *> *annots) {
        MuPDFDKAnnotationInternal *annotAtPoint = nil;
        for (MuPDFDKAnnotationInternal *annot in annots)
        {
            if (annot.type == MuPDFAnnotType_Widget || (annot.type == MuPDFAnnotType_Redact) != redactions)
                continue;

            annotAtPoint = annot;

            // Rather than select the first annotation at this user tapped
            // point (i.e. the top item in Z order returned by the call
            // to annotsFromPage()), we'll favour TEXT and HIGHLIGHT
            // annotations over INK and other annotation types. This will
            // allow users to select a TEXT or HIGHLIGHT annotation that
            // is placed inside the bounds of an INK or other types of
            // annotation.
            //
            // This is not a perfect solution but should work for most
            // use cases. Really we should be controlling the Z order of
            // annotations in a way that keeps TEXT and HIGHLIGHT annotations
            // always above any overlapping INK or other annotation types,
            // but that's a much bigger change to make at this point in time.
            if ((annot.type == MuPDFAnnotType_Text) ||
                (annot.type == MuPDFAnnotType_Highlight))
            {
                break;
            }
        }

        // did we find an annotation at the point "pt"?
        if (annotAtPoint)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self selectAnnotation:annotAtPoint];
            });
        }
    }];
}

- (void)selectAnnotationAt:(CGPoint)pt
{
    [self selectAnnotationAt:pt redactions:NO];
}

- (void)selectRedactionAt:(CGPoint)pt
{
    [self selectAnnotationAt:pt redactions:YES];
}

- (void)addInkAnnotationWithPaths:(NSArray<NSArray<NSValue *> *> *)paths
                            color:(UIColor *)color
                        thickness:(CGFloat)thickness
{
    // This may be called during session closedown because of an in-preparation annotation.
    // In that case, the marking of the document as changed within updatePageNumbered:withFzpage:
    // is too late, so we do it up front
    self.doc.hasBeenModified = TRUE;

    dispatch_async(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        pdf_document *idoc = pdf_specifics(ctx, self.doc.fzdoc);
        if (!idoc)
            return;

        fz_point *pts = NULL;

        fz_var(pts);
        fz_try(ctx)
        {
            pdf_annot *annot = pdf_create_annot(ctx, (pdf_page *)self.fzpage, PDF_ANNOT_INK);
            CGFloat red, green, blue;
            [color getRed:&red green:&green blue:&blue alpha:NULL];
            float fcolor[] = {red, green, blue};
            pdf_set_annot_border(ctx, annot, thickness);
            pdf_set_annot_color(ctx, annot, 3, fcolor);
            for (NSArray<NSValue *> *path in paths)
            {
                int n = (int)path.count;
                pts = fz_malloc_array(ctx, n, fz_point);
                for (int i = 0; i < n; i++)
                    pts[i] = pt_to_fz(path[i].CGPointValue);
                pdf_add_annot_ink_list(ctx, annot, n, pts);
                fz_free(ctx, pts);
                pts = NULL;
            }
            [self.doc updatePages];
        }
        fz_catch(ctx)
        {
            fz_free(ctx, pts);
            NSLog(@"Ink annotation creations failed");
        }
    });
}
- (BOOL)addTextAnnotationAt:(CGPoint)pt
{
    NSString *author = self.doc.documentAuthor;
    [self.doc clearSelection];
    // Avoid adding an annotation off page
    if (!CGRectContainsPoint(CGRectMake(0, 0, self.size.width, self.size.height), pt))
        return FALSE;

    dispatch_async(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        pdf_document *idoc = pdf_specifics(ctx, self.doc.fzdoc);
        if (!idoc)
            return;

        fz_try(ctx)
        {
            pdf_annot *annot = pdf_create_annot(ctx, (pdf_page *)self.fzpage, PDF_ANNOT_TEXT);
            fz_rect rect = pdf_bound_annot(ctx, annot);
            fz_point fz_pt = pt_to_fz(pt);
            float width = rect.x1 - rect.x0;
            float height = rect.y1 - rect.y0;
            pdf_set_annot_rect(ctx, annot,
                               fz_make_rect(fz_pt.x - width/2,
                                            fz_pt.y - height/2,
                                            fz_pt.x + width/2,
                                            fz_pt.y + height/2));
            if (author)
                pdf_set_annot_author(ctx, annot, author.UTF8String);
            pdf_set_annot_modification_date(ctx, annot, NSDate.date.timeIntervalSince1970);
            [self.doc updatePages];

            // Look up the created annotation to find it's index.
            // Possibly we shouldn't be using indexs, but caching the annotations themselves
            // is risky when they may get deleted.
            NSInteger index = 0;
            for (pdf_annot *a = pdf_first_annot(ctx, (pdf_page *)self.fzpage); a; a = pdf_next_annot(ctx, a))
            {
                if (a == annot)
                {
                    MuPDFDKAnnotationInternal *wannot = [MuPDFDKAnnotationInternal annotFromAnnot:a andIndex:index withCtx:ctx];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self selectAnnotation:wannot];
                    });
                    break;
                }
                ++index;
            }
        }
        fz_catch(ctx)
        {
            NSLog(@"Text annotation creation failed");
        }
    });

    return TRUE;
}

- (BOOL)addSignatureFieldAt:(CGPoint)pt
{
    [self.doc clearSelection];
    // Avoid adding an annotation off page
    if (!CGRectContainsPoint(CGRectMake(0, 0, self.size.width, self.size.height), pt))
        return FALSE;

    dispatch_async(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        pdf_document *idoc = pdf_specifics(ctx, self.doc.fzdoc);
        if (!idoc)
            return;

        fz_try(ctx)
        {
            char name[80];
            pdf_widget *widget;
            CGSize pageSize = self.size;
            make_unused_field_name(ctx, (pdf_document *)self.doc.fzdoc, "Signature%d", name);
            widget = pdf_create_signature_widget(ctx, (pdf_page *)self.fzpage, name);
            fz_rect rect = pdf_bound_annot(ctx, widget);
            fz_point fz_pt = pt_to_fz(pt);
            float width = rect.x1 - rect.x0;
            float height = rect.y1 - rect.y0;
            pdf_set_annot_rect(ctx, widget,
                               fz_make_rect(fz_pt.x,
                                            fz_pt.y,
                                            MIN(fz_pt.x + width, pageSize.width),
                                            MIN(fz_pt.y + height, pageSize.height)));
            [self.doc updatePages];

            // Look up the created annotation to find it's index.
            // Possibly we shouldn't be using indexes, but caching the annotations themselves
            // is risky when they may get deleted.
            NSInteger index = 0;
            for (pdf_widget *w = pdf_first_widget(ctx, (pdf_page *)self.fzpage); w; w = pdf_next_widget(ctx, w))
            {
                if (w == widget)
                {
                    MuPDFDKAnnotationInternal *wannot = [MuPDFDKAnnotationInternal annotFromAnnot:w andIndex:index withCtx:ctx];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.newlyCreatedSignatures addObject:[NSValue valueWithPointer:widget]];
                        [self selectAnnotation:wannot];
                    });
                    break;
                }
                ++index;
            }
        }
        fz_catch(ctx)
        {
            NSLog(@"Signature field creation failed");
        }
    });

    return TRUE;
}

- (void)createRedactionAnnotationFromSelectionDelayed
{
    NSObject<MuPDFDKSelection> *currentSelection = self.doc.selections[@(self->_pageNum)];
    if (currentSelection == nil)
        return;

    NSArray<MuPDFDKQuad *> *quads = currentSelection.quads;
    CGRect area = selectionAsRect(currentSelection);
    [self.doc clearSelection];

    dispatch_async(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        fz_quad *fzquads = NULL;
        pdf_document *idoc = pdf_specifics(ctx, self.doc.fzdoc);
        if (!idoc)
            return;

        fz_var(quads);
        fz_try(ctx)
        {
            pdf_annot *annot = pdf_create_annot(ctx, (pdf_page *)self.fzpage, PDF_ANNOT_REDACT);
            if (quads != nil)
            {
                int i;
                fzquads = fz_malloc_array(ctx, (int)quads.count, fz_quad);
                for (i = 0; i < quads.count; i++)
                    fzquads[i] = quad_to_fz(quads[i]);
                pdf_set_annot_quad_points(ctx, annot, (int)quads.count, fzquads);
            }
            else
            {
                pdf_set_annot_rect(ctx, annot, rect_to_fz(area));
            }
            pdf_set_annot_modification_date(ctx, annot, NSDate.date.timeIntervalSince1970);
            [self.doc updatePages];

            // Look up the created annotation to find it's index.
            // Possibly we shouldn't be using indexs, but caching the annotations themselves
            // is risky when they may get deleted.
            NSInteger index = 0;
            for (pdf_annot *a = pdf_first_annot(ctx, (pdf_page *)self.fzpage); a; a = pdf_next_annot(ctx, a))
            {
                if (a == annot)
                {
                    MuPDFDKAnnotationInternal *wannot = [MuPDFDKAnnotationInternal annotFromAnnot:a andIndex:index withCtx:ctx];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.doc.pagesWithRedactions addObject:[NSNumber numberWithInteger:self->_pageNum]];
                        [self selectAnnotation:wannot];
                    });
                    break;
                }
                ++index;
            }
        }
        fz_always(ctx)
        {
            fz_free(ctx, fzquads);
        }
        fz_catch(ctx)
        {
            NSLog(@"Redaction annotation creations failed");
        }
    });
}

-(void)createRedactionAnnotationFromSelection
{
    // This is called on completion of a sequence of touches, and after
    // other touches cause selWordAt: to be called. selWordAt: requires
    // background actions, and so we need to delay this call until
    // after any pending background actions are complete.
    __weak typeof(self) weakSelf = self;
    [self.doc doAfterBackgroundTasks:^{
        [weakSelf createRedactionAnnotationFromSelectionDelayed];
    }];
}

- (void)testAt:(CGPoint)pt forHyperlink:(void (^)(id<ARDKHyperlink>))block
{
    dispatch_async(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        fz_link *links = NULL;
        MuPDFDKHyperlink *hl = nil;
        fz_var(link);
        fz_try(ctx)
        {
            fz_link *link;

            links = fz_load_links(ctx, self.fzpage);
            for (link = links; link; link = link->next)
            {
                fz_rect rect = link->rect;
                if (rect.x0 <= pt.x && pt.x <= rect.x1 && rect.y0 <= pt.y && pt.y <= rect.y1)
                {
                    hl = [[MuPDFDKHyperlink alloc] init];
                    if (fz_is_external_link(ctx, link->uri))
                    {
                        hl.page = -1;
                        hl.url = @(link->uri);
                    }
                    else
                    {
                        float x, y;
                        fz_location location = fz_resolve_link(ctx, link->doc, link->uri, &x, &y);
                        hl.page = fz_page_number_from_location(ctx, link->doc,  location);
                        hl.rect = CGRectMake(x, y, 0, 0);
                    }
                    break;
                }
            }
        }
        fz_always(ctx)
        {
            fz_drop_link(ctx, links);
        }
        fz_catch(ctx)
        {
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            block(hl);
        });
    });
}

- (pdf_widget *)findWidget:(pdf_obj *)obj
{
    pdf_widget *widget;
    fz_context *ctx = self.doc.mulib.ctx;
    pdf_document *idoc = pdf_specifics(ctx, self.doc.fzdoc);
    if (idoc == NULL)
        return NULL;

    for (widget = pdf_first_widget(ctx, (pdf_page *)self.fzpage); widget; widget = pdf_next_widget(ctx, widget))
        if (widget->obj == obj)
            break;

    return widget;
}

- (BOOL)setWidget:(pdf_obj *)obj text:(NSString *)text isFinal:(BOOL)final
{
    __block BOOL accepted = NO;

    dispatch_sync(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        fz_var(accepted);
        fz_try(ctx)
        {
            pdf_widget *widget = [self findWidget:obj];
            if (widget)
            {
                pdf_set_widget_editing_state(ctx, widget, text.length == 0 || !final);
                accepted = (pdf_set_text_field_value(ctx, widget, (char *)text.UTF8String) != 0);
            }

            if (accepted)
                [self.doc updatePagesRecalc:final];

        }
        fz_catch(ctx)
        {
            accepted = NO;
        }
    });

    return accepted;
}

- (NSArray<MuPDFDKTextLayoutLine *> *)getWidgetTextLayout:(pdf_obj *)obj
{
    NSMutableArray<MuPDFDKTextLayoutLine *> *lines = [NSMutableArray array];

    dispatch_sync(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        fz_layout_block *layout = NULL;

        fz_var(layout);
        fz_try(ctx)
        {
            pdf_widget *widget = [self findWidget:obj];

            if (widget)
            {
                fz_rect bounds = pdf_bound_widget(ctx, widget);
                layout = pdf_layout_text_widget(ctx, widget);
                fz_matrix mat = fz_concat(layout->inv_matrix, fz_translate(-bounds.x0, -bounds.y0));
                for (fz_layout_line *line = layout->head;
                     line;
                     line = line->next)
                {
                    NSMutableArray<NSValue *> *charRects = [NSMutableArray array];
                    float y = line->y - line->h * 0.2;
                    fz_rect fzLineRect = fz_transform_rect(fz_make_rect(line->x, y, line->x, line->y + line->h), mat);
                    CGRect lineRect = rect_from_fz(fzLineRect);

                    for (fz_layout_char *ch = line->text; ch; ch = ch->next)
                    {
                        fz_rect fzCharRect = fz_transform_rect(fz_make_rect(ch->x, y, ch->x + ch->w, line->y + line->h), mat);
                        CGRect charRect = rect_from_fz(fzCharRect);
                        lineRect = CGRectUnion(lineRect, charRect);
                        [charRects addObject:[NSValue valueWithCGRect:charRect]];
                    }

                    [lines addObject:[MuPDFDKTextLayoutLine layoutWithLineRect:lineRect andCharRects:charRects]];
                }
            }
        }
        fz_always(ctx)
        {
            fz_drop_layout(ctx, layout);
        }
        fz_catch(ctx)
        {
        }
    });

    return lines;
}

- (void)setWidget:(pdf_obj *)obj option:(NSString *)opt onCheck:(void (^)(BOOL accepted))result
{
    dispatch_async(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        BOOL accepted = NO;
        fz_var(accepted);
        fz_try(ctx)
        {
            pdf_widget *widget = [self findWidget:obj];
            if (widget)
            {
                const char *utf8opt = opt.UTF8String;
                pdf_choice_widget_set_value(ctx, widget, 1, &utf8opt);
                accepted = YES;
                [self.doc updatePages];
            }
        }
        fz_catch(ctx)
        {
            accepted = NO;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            result(accepted);
        });
    });
}

- (void)toggleWidget:(pdf_obj *)obj
{
    dispatch_async(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        fz_try(ctx)
        {
            pdf_widget *widget = [self findWidget:obj];
            if (widget)
            {
                pdf_toggle_widget(ctx, widget);
                [self.doc updatePages];
            }
        }
        fz_catch(ctx)
        {
        }
    });
}

- (void)verifyWidget:(pdf_obj *)obj with:(id<PKCS7Verifier>)verifier reply:(void (^)(PKCS7VerifyResult r, int invalidChangePoinr, id<PKCS7DesignatedName> name, id<PKCS7Description> description))result
{
    dispatch_async(self.doc.mulib.queue, ^{
        PKCS7VerifyResult res = PKCS7VerifyResult_Unknown;
        int invalidChangePoint = 0;
        id<PKCS7DesignatedName> name = nil;
        id<PKCS7Description> description = nil;
        fz_context *ctx = self.doc.mulib.ctx;
        fz_stream *bytes = NULL;
        char *contents = NULL;

        fz_var(bytes);
        fz_var(contents);
        fz_try(ctx)
        {
            pdf_document *idoc = pdf_specifics(ctx, self.doc.fzdoc);
            pdf_widget *focus = [self findWidget:obj];
            if (focus)
            {
                size_t contents_len = pdf_signature_contents(ctx, idoc, focus->obj, &contents);
                if (contents)
                {
                    NSData *sig = [NSData dataWithBytesNoCopy:contents length:contents_len freeWhenDone:NO];
                    unsigned char buf[4096];
                    size_t n;
                    bytes = pdf_signature_hash_bytes(ctx, idoc, focus->obj);
                    [verifier begin];
                    while ((n = fz_read(ctx, bytes, buf, sizeof(buf))) > 0)
                    {
                        [verifier data:[NSData dataWithBytesNoCopy:buf length:n freeWhenDone:NO]];
                    }
                    res = [verifier verify:sig];
                    name = [verifier name:sig];
                    description = [verifier description:sig];
                }

                // Find which update invalidated the signature. 0 means it's still
                // valid. 1 means the last update invalidated it. 2 means the last but one, etc..
                invalidChangePoint = pdf_validate_signature(ctx, focus);
            }
        }
        fz_catch(ctx)
        {
            fz_drop_stream(ctx, bytes);
            fz_free(ctx, contents);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            result(res, invalidChangePoint, name, description);
        });
    });
}

- (void)signWidget:(pdf_obj *)obj with:(id<PKCS7Signer>)signer onCheck:(void (^)(BOOL accepted))result
{
    dispatch_async(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        BOOL success = NO;
        pdf_pkcs7_signer *csigner = pdf_pkcs7_signer_create(ctx, signer);

        if (csigner)
        {
            fz_try(ctx)
            {
                pdf_widget *focus = [self findWidget:obj];

                if (focus)
                {
                    pdf_sign_signature(ctx, focus, csigner);
                    // Signing may cause some fields to become readonly. Reload info.
                    [self findFormFields];
                    [self.doc updatePages];
                    success = YES;
                }
            }
            fz_catch(ctx)
            {
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            result(success);
        });
    });
}

- (MuPDFDKWidget *)interpretWidget:(pdf_widget *)focus withIndex:(NSInteger)index
{
    fz_context *ctx = self.doc.mulib.ctx;
    const char *text = NULL;
    const char **opts = NULL;
    MuPDFDKWidget *widget = nil;

    fz_var(text);
    fz_var(opts);
    fz_try(ctx)
    {
        pdf_document *idoc = pdf_specifics(ctx, self.doc.fzdoc);

        if (idoc)
        {
            pdf_obj *focus_obj = focus->obj;
            switch (pdf_widget_type(ctx, focus))
            {
                case PDF_WIDGET_TYPE_TEXT:
                {
                    MuPDFDKWidgetText *twidget = [[MuPDFDKWidgetText alloc] init];
                    text = pdf_field_value(ctx, focus->obj);
                    twidget.text = @(text ? text : "");
                    twidget.isNumber = pdf_text_widget_format(ctx, focus) != PDF_WIDGET_TX_FORMAT_NONE;
                    twidget.isMultiline = pdf_field_flags(ctx, focus_obj) & PDF_TX_FIELD_IS_MULTILINE;
                    twidget.maxChars = pdf_text_widget_max_len(ctx, focus);
                    twidget.setText = ^(NSString *text, BOOL final) {
                        return [self setWidget:focus_obj text:text isFinal:final];
                    };
                    twidget.getTextLayout = ^NSArray<MuPDFDKTextLayoutLine *> *{
                        return [self getWidgetTextLayout:focus_obj];
                    };

                    widget = twidget;
                    break;
                }

                case PDF_WIDGET_TYPE_LISTBOX:
                case PDF_WIDGET_TYPE_COMBOBOX:
                {
                    MuPDFDKWidgetList *lwidget = [[MuPDFDKWidgetList alloc] init];
                    int nopts = pdf_choice_widget_options(ctx, focus, 0, NULL);
                    if (nopts <= 0)
                        break;

                    opts = fz_malloc(ctx, nopts * sizeof(*opts));
                    (void)pdf_choice_widget_options(ctx, focus, 0, opts);
                    NSMutableArray<NSString *> *options = [NSMutableArray array];
                    for (int i = 0; i < nopts; i++)
                    {
                        if (opts[i] && @(opts[i]) != nil)
                        {
                            [options addObject:@(opts[i])];
                        }
                    }
                    lwidget.optionText = options;
                    lwidget.setOption = ^(NSString *opt, void (^result)(BOOL accepted)) {
                        [self setWidget:focus_obj option:opt onCheck:result];
                    };

                    widget = lwidget;
                    break;
                }

                case PDF_WIDGET_TYPE_RADIOBUTTON:
                case PDF_WIDGET_TYPE_CHECKBOX:
                {
                    MuPDFDKWidgetRadio *rwidget = [[MuPDFDKWidgetRadio alloc] init];
                    rwidget.toggle = ^{
                        [self toggleWidget:focus_obj];
                    };

                    widget = rwidget;
                    break;
                }

                case PDF_WIDGET_TYPE_SIGNATURE:
                {
                    if ( self.doc.pdfFormSigningEnabled )
                    {
                        if (pdf_dict_get(ctx, focus->obj, PDF_NAME(V)))
                        {
                            // Already signed
                            MuPDFDKWidgetSignedSignature *uswidget = [[MuPDFDKWidgetSignedSignature alloc] init];
                            uswidget.unsaved = pdf_xref_obj_is_unsaved_signature(idoc, focus_obj);
                            uswidget.verify = ^(id<PKCS7Verifier> verifier,
                                                void (^result)(PKCS7VerifyResult r,
                                                               int invalidChangePoint,
                                                               id<PKCS7DesignatedName> name,
                                                               id<PKCS7Description> description)) {
                                [self verifyWidget:focus_obj with:verifier reply:result];
                            };
                            widget = uswidget;
                        }
                        else
                        {
                            // Unsigned
                            MuPDFDKWidgetUnsignedSignature *swidget = [[MuPDFDKWidgetUnsignedSignature alloc] init];
                            swidget.wasCreatedInThisSession = [self.newlyCreatedSignatures containsObject:[NSValue valueWithPointer:focus]];
                            swidget.sign = ^(id<PKCS7Signer> signer, void (^result)(BOOL accepted)) {
                                [self signWidget:focus_obj with:signer onCheck:result];
                            };
                            widget = swidget;
                        }
                    }
                    break;
                }

                default:
                    break;
            }
        }

        if (widget)
        {
            widget.rect = rect_from_fz(pdf_bound_widget(ctx, focus));
            widget.annot = [MuPDFDKAnnotationInternal annotFromAnnot:focus andIndex:index withCtx:self.doc.mulib.ctx];
        }
    }
    fz_always(ctx)
    {
        fz_free(ctx, opts);
    }
    fz_catch(ctx)
    {
    }

    return widget;
}

- (void)tapAt:(CGPoint)pt onFocus:(void (^)(MuPDFDKWidget *))block
{
    dispatch_async(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        MuPDFDKWidget *widget = nil;
        fz_try(ctx)
        {
            pdf_document *idoc = pdf_specifics(ctx, self.doc.fzdoc);
            if (idoc)
            {
                pdf_widget *focus = NULL;
                NSInteger focusIndex = 0;
                NSInteger index = 0;
                for (pdf_widget *w = pdf_first_widget(ctx, (pdf_page *)self.fzpage)
                     ; w
                     ; w = pdf_next_widget(ctx, w))
                {
                    fz_rect rect = pdf_bound_widget(ctx, w);
                    fz_point fz_pt = pt_to_fz(pt);

                    if (w->is_hot)
                    {
                        w->is_hot = 0;
                        pdf_annot_event_blur(ctx, w);
                    }

                    if (rect.x0 < fz_pt.x && fz_pt.x < rect.x1 && rect.y0 < fz_pt.y && fz_pt.y < rect.y1)
                    {
                        focus = w;
                        focusIndex = index;
                    }

                    ++index;
                }

                if (focus && !widget_is_visible(ctx, focus))
                    focus = NULL;

                if (focus)
                {
                    self.doc.focusPageNumber = self->_pageNum;
                    focus->is_hot = 1;
                    pdf_annot_event_focus(ctx, focus);
                    pdf_annot_event_down(ctx, focus);
                    pdf_annot_event_up(ctx, focus);
                    [self.doc updatePages];
                    widget = [self interpretWidget:focus withIndex:focusIndex];
                }
            }
        }
        fz_catch(ctx)
        {
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.doc findFormFields];
            block(widget);
        });
    });
}

- (void)focusNextWidget:(void (^)(MuPDFDKWidget *))block
{
    dispatch_async(self.doc.mulib.queue, ^{
        fz_context *ctx = self.doc.mulib.ctx;
        MuPDFDKWidget *widget = nil;
        fz_try(ctx)
        {
            pdf_widget *focus;
            int foundFocus = 0;
            pdf_document *idoc = pdf_specifics(ctx, self.doc.fzdoc);
            if (idoc)
            {
                NSInteger index = 0;
                for (focus = pdf_first_widget(ctx, (pdf_page *)self.fzpage); focus; focus = pdf_next_widget(ctx, focus))
                {
                    if (foundFocus)
                    {
                        int type = pdf_widget_type(ctx, focus);
                        if ((type == PDF_WIDGET_TYPE_TEXT ||
                             type == PDF_WIDGET_TYPE_LISTBOX || type == PDF_WIDGET_TYPE_COMBOBOX ||
                             type == PDF_WIDGET_TYPE_RADIOBUTTON || type == PDF_WIDGET_TYPE_CHECKBOX) && widget_is_visible(ctx, focus))
                        {
                            focus->is_hot = 1;
                            pdf_annot_event_focus(ctx,  focus);
                            widget = [self interpretWidget:focus withIndex:index];
                            break;
                        }
                    }
                    else if (focus->is_hot)
                    {
                        foundFocus = 1;
                        focus->is_hot = 0;
                        pdf_annot_event_blur(ctx, focus);
                    }

                    ++index;
                }
            }
        }
        fz_catch(ctx)
        {
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.doc findFormFields];
            block(widget);
        });
    });
}

@end

@implementation FzPage
{
    MuPDFDKDoc *_doc;
}

- (instancetype)initWithPage:(fz_page *)fzpage ofDoc:(MuPDFDKDoc *)doc
{
    self = [super init];
    if (self)
    {
        self->_fzpage = fzpage;
        self->_doc = doc;
    }
    return self;
}

- (void)dealloc
{
    MuPDFDKDoc *doc = _doc;
    fz_page *fzpage = _fzpage;
    dispatch_async_if_needed(doc.mulib.queue, ^{
        fz_drop_page(doc.mulib.ctx, fzpage);
    });
}

+ (FzPage *)pageFromPage:(fz_page *)fzpage ofDoc:(MuPDFDKDoc *)doc
{
    return [[FzPage alloc] initWithPage:fzpage ofDoc:doc];
}

@end

@interface FzPageHolder : NSObject
@property NSInteger pageNo;
@property(weak) FzPage *page;

+ (FzPageHolder *)holderForPage:(FzPage *)page numbered:(NSInteger)pageNo;
@end

@implementation FzPageHolder : NSObject

+ (FzPageHolder *)holderForPage:(FzPage *)page numbered:(NSInteger)pageNo
{
    FzPageHolder *holder = [[FzPageHolder alloc] init];
    holder.page = page;
    holder.pageNo = pageNo;
    return holder;
}

@end

@interface MuPDFDKPageHolder : NSObject
@property NSInteger pageNo;
@property(weak) MuPDFDKPage *page;

+ (MuPDFDKPageHolder *)holderForPage:(MuPDFDKPage *)page numbered:(NSInteger)pageNo;
@end

@implementation MuPDFDKPageHolder

+ (MuPDFDKPageHolder *)holderForPage:(MuPDFDKPage *)page numbered:(NSInteger)pageNo
{
    MuPDFDKPageHolder *holder = [[MuPDFDKPageHolder alloc] init];
    holder.pageNo = pageNo;
    holder.page = page;
    return holder;
}

@end

@interface MuPDFDKDoc()
@property BOOL isBeingSaved;
@end

@implementation MuPDFDKDoc
{
    MuPDFPrintProfile _printProfile;
    ARDKSoftProfile _softProfile;
    NSInteger _reportedPageCount;
    NSMutableDictionary<NSNumber *, FzPageHolder *> *_fzpages;
    NSArray<MuPDFDKPageHolder *> *_pages;
    BOOL _pdfFormFillingEnabled;
}

@synthesize progressBlock=_progressBlock, successBlock=_successBlock, errorBlock=_errorBlock,
            docType = _docType, hasBeenModified = _hasBeenModified, loadingComplete = _loadingComplete,
            pageCount = _pageCount, pdfFormSigningEnabled = _pdfFormSigningEnabled, pasteboard = _pasteboard;

+ (ARDKDocType)docTypeFromFileExtension:(NSString *)filePath
{
    NSString *ext = [filePath pathExtension].uppercaseString;
    if ([ext isEqualToString:@"PDF"])
        return ARDKDocType_PDF;
    else if ([ext isEqualToString:@"CBZ"]
        || [ext isEqualToString:@"CBT"])
        return ARDKDocType_CBZ;
    else if ([ext isEqualToString:@"FB2"]
             || [ext isEqualToString:@"XHTML"])
        return ARDKDocType_FB2;
    else if ([ext isEqualToString:@"SVG"])
        return ARDKDocType_SVG;
    else if ([ext isEqualToString:@"XPS"]
             || [ext isEqualToString:@"OXPS"])
        return ARDKDocType_XPS;
    else if ([ext isEqualToString:@"EPUB"])
        return ARDKDocType_EPUB;
    return ARDKDocType_Other;
}

- (instancetype)initForPath:(NSString *)path ofType:(ARDKDocType)docType lib:(MuPDFDKLib *)lib
{
    self = [super init];
    if (self)
    {
        _mulib = lib;
        _docType = docType;
        _path = path;
        _pageSizes = [NSMutableArray array];
        _pages = [NSArray array];
        _selections = [NSMutableDictionary dictionary];
        _pagesWithRedactions = [NSMutableSet set];
        _eventTargets = [NSMutableArray array];
        _fzpages = [NSMutableDictionary dictionaryWithCapacity:INITIAL_FZPAGE_CACHE_SIZE];
    }
    return self;
}

- (void)dealloc
{
    fz_context *ctx = _mulib.ctx;
    fz_stream *stream = _stream;
    fz_document *doc = _fzdoc;
    dispatch_async_if_needed(_mulib.queue, ^{
        fz_drop_document(ctx, doc);
        fz_drop_stream(ctx, stream);
    });
}

- (void)doAfterBackgroundTasks:(void (^)(void))block
{
    dispatch_async(self.mulib.queue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            block();
        });
    });
}
- (void)addTarget:(id<ARDKDocumentEventTarget>)target
{
    [_eventTargets addObject:[MuPDFDKWeakEventTarget weakHolder:target]];
    if (self.loadingComplete)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [target updatePageCount:self.pageCount andLoadingComplete:YES];
        });
    }
}

- (NSInteger)pageCount
{
    @synchronized (self.pageSizes) {
        return self.pageSizes.count;
    }
}

- (id<ARDKLib>)lib
{
    return _mulib;
}

- (void)enableJS:(BOOL)enable
{
    assert(strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), queue_label) == 0);
    fz_context *ctx = self.mulib.ctx;
    pdf_document *idoc = pdf_specifics(ctx, self->_fzdoc);
    if (idoc)
    {
        if (enable)
        {
            pdf_enable_js(ctx, idoc);
            // Pass self into the mupdf library. This is safe because the callback
            // is triggered only by calls that we make, for which we ensure a reference
            // is kept.
            pdf_set_doc_event_callback(ctx, idoc, event_cb, (__bridge void *)self);
        }
        else
        {
            pdf_disable_js(ctx, idoc);
            pdf_set_doc_event_callback(ctx, idoc, NULL, NULL);
        }
    }
}

- (NSString *)documentAuthor
{
    NSString *author = [[NSUserDefaults standardUserDefaults] stringForKey:documentAuthorKey];
    if (!author)
        author = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    return author;
}

- (void)setDocumentAuthor:(NSString *)documentAuthor
{
    [[NSUserDefaults standardUserDefaults] setObject:documentAuthor forKey:documentAuthorKey];
}

- (void)setSelectionIsRedaction:(BOOL)isRedaction
{
    self->_selectionIsRedaction = isRedaction;
}

- (BOOL)pdfFormFillingEnabled
{
    return _pdfFormFillingEnabled;
}

- (void)setPdfFormFillingEnabled:(BOOL)pdfFormFillingEnabled
{
    _pdfFormFillingEnabled = pdfFormFillingEnabled;
    dispatch_async(self.mulib.queue, ^{
        [self enableJS:pdfFormFillingEnabled];
    });
}

- (BOOL)pdfFormSigningEnabled
{
    return _pdfFormSigningEnabled;
}

- (void)setPdfFormSigningEnabled:(BOOL)pdfFormSigningEnabled
{
    _pdfFormSigningEnabled = pdfFormSigningEnabled;
}

- (ARDKBitmap *)bitmapAtSize:(CGSize)size
{
    return [ARDKBitmap bitmapAtSize:size ofType:ARDKBitmapType_RGBA8888];
}

static NSMutableArray<id<ARDKTocEntry>> *tocFromOutline(fz_outline *outline, int depth)
{
    NSMutableArray<id<ARDKTocEntry>> *arr = [NSMutableArray array];

    for (;outline; outline = outline->next)
    {
        MuPDFDKTocEntry *tocEntry = [[MuPDFDKTocEntry alloc] init];
        if (outline->title)
            tocEntry.label = @(outline->title);
        if (outline->uri)
            tocEntry.url = @(outline->uri);
        tocEntry.page = outline->page;
        tocEntry.rect = CGRectMake(outline->x, outline->y, 0, 0);
        tocEntry.depth = depth;
        tocEntry.open = outline->is_open != 0;
        tocEntry.children = tocFromOutline(outline->down, depth+1);

        [arr addObject:tocEntry];
    }

    return arr;
}

- (void)loadToc
{
    dispatch_async(self.mulib.queue, ^{
        fz_context *ctx = self.mulib.ctx;
        fz_outline *outline = NULL;
        pdf_document *idoc = pdf_specifics(ctx, self->_fzdoc);
        if (!idoc)
            return;

        NSArray<id<ARDKTocEntry>> *toc;

        fz_var(outline);
        fz_try(ctx)
        {
            outline = pdf_load_outline(ctx, idoc);
            toc = tocFromOutline(outline, 0);
        }
        fz_always(ctx)
        {
            fz_drop_outline(ctx, outline);
        }
        fz_catch(ctx)
        {
        }

        if(toc)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_toc = toc;
                // Trick: report a selection change so that the app updates the UI
                if (self.onSelectionChanged)
                    self.onSelectionChanged();
                for (MuPDFDKWeakEventTarget *weakTarget in self.eventTargets)
                    if ([weakTarget.target respondsToSelector:@selector(selectionHasChanged)])
                        [weakTarget.target selectionHasChanged];
            });
        }
    });
}

- (void)loadSomePages
{
    assert([NSThread isMainThread]);
    if (self->_pageCount >= self->_reportedPageCount)
    {
        _loadingComplete = YES;
        if (self.progressBlock)
            self.progressBlock(self->_pageCount, YES);
        if (self.successBlock)
            self.successBlock();
        for (MuPDFDKWeakEventTarget *weakTarget in _eventTargets)
            [weakTarget.target updatePageCount:self->_pageCount andLoadingComplete:YES];
        [self loadToc];
    }
    else
    {
        dispatch_async(self.mulib.queue, ^{
            fz_context *ctx = self.mulib.ctx;
            NSMutableArray<NSNumber *> *pagesWithRedactions = [NSMutableArray array];
            NSInteger count = MIN(16, self->_reportedPageCount - self->_pageCount);
            while (count--)
            {
                FzPage *page = [self getFzPage:self->_pageCount];
                fz_try(ctx)
                {
                    pdf_document *pdf;
                    pdf_annot *annot;
                    fz_rect rect = page.fzpage ? fz_bound_page(ctx, page.fzpage) : fz_empty_rect;
                    @synchronized (self.pageSizes) {
                        self.pageSizes[self->_pageCount] = [NSValue valueWithCGSize:CGSizeMake(rect.x1 - rect.x0, rect.y1 - rect.y0)];
                    }

                    pdf = pdf_document_from_fz_document(ctx, self.fzdoc);
                    if (pdf)
                    {
                        pdf_page *ppage = (pdf_page *)page.fzpage;
                        if (ppage)
                        {
                            for (annot = pdf_first_annot(ctx, ppage); annot; annot = pdf_next_annot(ctx, annot))
                            {
                                if (pdf_annot_type(ctx, annot) == PDF_ANNOT_REDACT)
                                    [pagesWithRedactions addObject:[NSNumber numberWithInteger:self->_pageCount]];
                            }
                        }
                    }

                    self->_pageCount++;
                }
                fz_catch(ctx)
                {
                }
            }
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                typeof(self) strongSelf = weakSelf;
                if (strongSelf)
                {
                    [strongSelf->_pagesWithRedactions addObjectsFromArray:pagesWithRedactions];
                    if (strongSelf.progressBlock)
                        strongSelf.progressBlock(strongSelf.pageCount, NO);
                    for (MuPDFDKWeakEventTarget *weakTarget in strongSelf.eventTargets)
                        [weakTarget.target updatePageCount:strongSelf.pageCount andLoadingComplete:NO];
                    [strongSelf loadSomePages];
                }
            });
        });
    }
}

- (ARError)loadDocument
{
    BOOL jsEnable = _pdfFormFillingEnabled;
    const char *magic = "file.pdf";
    switch (_docType)
    {
        case ARDKDocType_EPUB: magic = "file.epub"; break;
        case ARDKDocType_SVG: magic = "file.svg"; break;
        case ARDKDocType_XPS: magic = "file.xps"; break;
        case ARDKDocType_FB2: magic = "file.fb2"; break;
        case ARDKDocType_CBZ: magic = "file.cbz"; break;
        default: break;
    }
    dispatch_async(self.mulib.queue, ^{
        fz_context *ctx = self.mulib.ctx;
        pdf_document *pdoc = NULL;
        NSInteger count = 0;
        BOOL needsPassword = NO;
        BOOL failed = NO;
        BOOL acroForm = NO;
        BOOL xfaForm = NO;
        fz_var(count);
        fz_var(needsPassword);
        fz_var(failed);
        fz_var(xfaForm);
        fz_try(ctx)
        {
            if (MuPDFDKLib.secureFS && [MuPDFDKLib.secureFS ARDKSecureFS_isSecure:@(self.path.UTF8String)])
                self->_stream = secure_stream(ctx, [MuPDFDKLib.secureFS ARDKSecureFS_fileHandleForReadingAtPath:@(self.path.UTF8String)]);
            else
                self->_stream = fz_open_file(ctx, self.path.UTF8String);

            self->_fzdoc = fz_open_document_with_stream(ctx, magic, self->_stream);
            needsPassword = fz_needs_password(ctx, self->_fzdoc) != 0;
            pdoc = pdf_document_from_fz_document(ctx, self->_fzdoc);
            if (pdoc)
            {
                pdf_obj *fields = pdf_dict_getp(ctx, pdf_trailer(ctx, pdoc), "Root/AcroForm/Fields");
                pdf_obj *xfa = pdf_dict_getp(ctx, pdf_trailer(ctx, pdoc), "Root/AcroForm/XFA");
                xfaForm = (xfa != NULL);
                acroForm = (fields != NULL && pdf_array_len(ctx, fields) > 0);
            }
            count = fz_count_pages(ctx, self.fzdoc);
            [self enableJS:jsEnable];
        }
        fz_catch(ctx)
        {
            failed = YES;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (failed)
            {
                if (self.errorBlock)
                    self.errorBlock(ARDKDocErrorType_UnableToLoadDocument);
                return;
            }

            self->_reportedPageCount = count;
            if (needsPassword)
            {
                if (self.errorBlock)
                    self.errorBlock(ARDKDocErrorType_PasswordRequest);
            }
            else if (count <= 0)
            {
                if (self.errorBlock)
                    self.errorBlock(ARDKDocErrorType_UnableToLoadDocument);
                // A document may continue to load after an error, but
                // not in this case, so signal loading compelete.
                if (self.progressBlock)
                    self.progressBlock(0, YES);
                for (MuPDFDKWeakEventTarget *weakTarget in self.eventTargets)
                    [weakTarget.target updatePageCount:0 andLoadingComplete:YES];
            }
            else
            {
                self->_hasXFAForm = xfaForm;

                if (xfaForm && !acroForm)
                {
                    if (self.errorBlock)
                        self.errorBlock(ARDKDocErrorType_XFAForm);
                }

                [self loadSomePages];
            }
        });
    });

    return 0;
}

- (BOOL)haveTextSelection
{
    return [self.selections.allValues.firstObject isKindOfClass:MuPDFDKTextSelection.class];
}

- (BOOL)haveAnnotationSelection
{
    return [self.selections.allValues.firstObject isKindOfClass:MuPDFDKAnnotationInternal.class];
}

- (void)selectAnnotation:(MuPDFDKAnnotation *)annot onPage:(NSInteger)pageNum
{
    self.selections[@(pageNum)] = (MuPDFDKAnnotationInternal *)annot;
    [self selectionChangedForPage:pageNum];
    [self setSelectionIsRedaction:(annot.type == MuPDFAnnotType_Redact)];

    if (self.onSelectionChanged)
        self.onSelectionChanged();
    for (MuPDFDKWeakEventTarget *weakTarget in self.eventTargets)
        if ([weakTarget.target respondsToSelector:@selector(selectionHasChanged)])
            [weakTarget.target selectionHasChanged];
}

- (BOOL)selectionIsTextHighlight
{
    NSObject<MuPDFDKSelection> *selection = self.selections.allValues.firstObject;
    if ([selection isKindOfClass:MuPDFDKAnnotationInternal.class])
    {
        return ((MuPDFDKAnnotationInternal *)selection).type == MuPDFAnnotType_Highlight;
    }
    else
    {
        return  NO;
    }
}

- (BOOL)selectionIsWidget
{
    NSObject<MuPDFDKSelection> *selection = self.selections.allValues.firstObject;
    if ([selection isKindOfClass:MuPDFDKAnnotationInternal.class])
    {
        return ((MuPDFDKAnnotationInternal *)selection).type == MuPDFAnnotType_Widget;
    }
    else
    {
        return  NO;
    }
}

- (BOOL)selectionIsAnnotationWithText
{
    NSObject<MuPDFDKSelection> *selection = self.selections.allValues.firstObject;
    return [selection isKindOfClass:MuPDFDKAnnotationInternal.class] && ((MuPDFDKAnnotationInternal *)selection).hasText;
}

- (NSString *)selectedAnnotationsText
{
    NSObject<MuPDFDKSelection> *selection = self.selections.allValues.firstObject;
    return [selection isKindOfClass:MuPDFDKAnnotationInternal.class] ? ((MuPDFDKAnnotationInternal *)selection).text : nil;
}

- (void)setText:(NSString *)text forAnnotIndex:(NSInteger)index onPage:(NSInteger)pageNo
{
    NSObject<MuPDFDKSelection> *selection = self.selections[@(pageNo)];
    if ([selection isKindOfClass:MuPDFDKAnnotationInternal.class])
    {
        ((MuPDFDKAnnotationInternal *)selection).text = text;
        dispatch_async(self.mulib.queue, ^{
            fz_context *ctx = self.mulib.ctx;
            FzPage *page = [self getFzPage:pageNo];

            fz_var(page);
            fz_try(ctx)
            {
                pdf_annot *annot = page.fzpage ? pdf_first_annot(ctx, (pdf_page *)page.fzpage) : NULL;
                for (int i = 0; i < index && annot; i++)
                    annot = pdf_next_annot(ctx, annot);

                if (annot)
                {
                    pdf_set_annot_contents(ctx, annot, text.UTF8String);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self.onSelectionChanged)
                            self.onSelectionChanged();
                        for (MuPDFDKWeakEventTarget *weakTarget in self.eventTargets)
                            if ([weakTarget.target respondsToSelector:@selector(selectionHasChanged)])
                                [weakTarget.target selectionHasChanged];
                    });
                }
            }
            fz_catch(ctx)
            {
            }
        });
    }
}

- (void)setSelectedAnnotationsText:(NSString *)text
{
    NSNumber *p = self.selections.allKeys.firstObject;
    NSObject<MuPDFDKSelection> *selection = self.selections[p];
    if ([selection isKindOfClass:MuPDFDKAnnotationInternal.class])
        [self setText:text forAnnotIndex:((MuPDFDKAnnotationInternal *)selection).index onPage:p.integerValue];
}

- (NSDate *)selectedAnnotationsDate
{
    NSObject<MuPDFDKSelection> *selection = self.selections.allValues.firstObject;
    return [selection isKindOfClass:MuPDFDKAnnotationInternal.class] ? ((MuPDFDKAnnotationInternal *)selection).date : nil;
}

- (NSString *)selectedAnnotationsAuthor
{
    NSObject<MuPDFDKSelection> *selection = self.selections.allValues.firstObject;
    return [selection isKindOfClass:MuPDFDKAnnotationInternal.class] ? ((MuPDFDKAnnotationInternal *)selection).author : nil;
}

- (void)selectionChangedForPage:(NSInteger)pageNo
{
    for (MuPDFDKPageHolder *h in _pages)
        if (h.pageNo == pageNo && h.page && h.page.onSelectionChanged)
            h.page.onSelectionChanged();
}

- (void)clearSelection
{
    BOOL changed = NO;

    for (NSNumber *n in self.selections)
    {
        changed = YES;
        self.selections[n] = nil;
        [self selectionChangedForPage:n.integerValue];
    }

    for (NSNumber *n in self.selections)
    {
        changed = YES;
        self.selections[n] = nil;
        [self selectionChangedForPage:n.integerValue];
    }

    [self setSelectionIsRedaction:NO];

    if (changed)
    {
        if (_onSelectionChanged)
            _onSelectionChanged();
        for (MuPDFDKWeakEventTarget *weakTarget in _eventTargets)
            if ([weakTarget.target respondsToSelector:@selector(selectionHasChanged)])
                [weakTarget.target selectionHasChanged];
    }
}

- (void)forSelectedPages:(void (^)(NSInteger, NSArray<MuPDFDKQuad *> *))block
{
    NSInteger first = NSIntegerMax;
    NSInteger last = NSIntegerMin;

    for (NSNumber *n in [self.selections.allKeys arrayByAddingObjectsFromArray:self.selections.allKeys])
    {
        if (n.integerValue < first)
            first = n.integerValue;
        if (n.integerValue > last)
            last = n.integerValue;
    }

    for (NSInteger p = first; p <= last; p++)
    {
        block(p, selectionAsQuads(self.selections[@(p)]));
    }
}

- (void)findFormFields
{
    @synchronized(_pages)
    {
        for (MuPDFDKPageHolder *holder in _pages)
            [holder.page findFormFields];
    }
}

- (void)clearFocus
{
    dispatch_async(self.mulib.queue, ^{
        fz_context *ctx = self.mulib.ctx;
        fz_try(ctx)
        {
            pdf_document *idoc = pdf_document_from_fz_document(ctx, self.fzdoc);
            if (idoc)
            {
                FzPage *fzPage = [self getFzPage:self.focusPageNumber];
                for (pdf_widget *w = pdf_first_widget(ctx, (pdf_page *)fzPage.fzpage)
                     ; w
                     ; w = pdf_next_widget(ctx, w))
                {
                    if (w->is_hot)
                    {
                        w->is_hot = 0;
                        pdf_annot_event_blur(ctx, w);
                    }
                }
            }
        }
        fz_catch(ctx)
        {
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self findFormFields];
        });
    });
}

- (void)annotateSelection:(enum pdf_annot_type)annot_type leaveSelected:(BOOL)leaveSelected
{
    NSString *author = self.documentAuthor;
    [self forSelectedPages:^(NSInteger pageNo, NSArray<MuPDFDKQuad *> *quads) {
        if (quads.count > 0)
        {
            if (annot_type == PDF_ANNOT_REDACT)
                [self->_pagesWithRedactions addObject:[NSNumber numberWithInteger:pageNo]];

            dispatch_async(self.mulib.queue, ^{
                fz_context *ctx = self.mulib.ctx;
                pdf_document *idoc;
                FzPage *page = [self getFzPage:pageNo];
                fz_quad *fzquads = NULL;

                idoc = pdf_specifics(ctx, self->_fzdoc);
                if (!idoc)
                    return;

                fz_var(fzquads);
                fz_try(ctx)
                {
                    int i;
                    pdf_annot *annot;

                    fzquads = fz_malloc_array(ctx, (int)quads.count, fz_quad);
                    for (i = 0; i < quads.count; i++)
                        fzquads[i] = quad_to_fz(quads[i]);

                    if (page.fzpage)
                    {
                        annot = pdf_create_annot(ctx, (pdf_page *)page.fzpage, annot_type);
                        pdf_set_annot_quad_points(ctx, annot, (int)quads.count, fzquads);
                        if (annot_type == PDF_ANNOT_HIGHLIGHT)
                            pdf_set_annot_color(ctx, annot, 3, highlight_color);

                        if (author)
                            pdf_set_annot_author(ctx, annot, author.UTF8String);
                        pdf_set_annot_modification_date(ctx, annot, NSDate.date.timeIntervalSince1970);
                        [self updatePages];

                        if (leaveSelected)
                        {
                            // Look up the created annotation to find it's index.
                            // Possibly we shouldn't be using indexs, but caching the annotations themselves
                            // is risky when they may get deleted.
                            NSInteger index = 0;
                            for (pdf_annot *a = pdf_first_annot(ctx, (pdf_page *)page.fzpage); a; a = pdf_next_annot(ctx, a))
                            {
                                if (a == annot)
                                {
                                    MuPDFDKAnnotationInternal *wannot = [MuPDFDKAnnotationInternal annotFromAnnot:a andIndex:index withCtx:ctx];
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [self selectAnnotation:wannot onPage:pageNo];
                                    });
                                    break;
                                }
                                ++index;
                            }
                        }
                        else
                        {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self clearSelection];
                            });
                        }
                    }
                }
                fz_always(ctx)
                {
                    fz_free(ctx, fzquads);
                }
                fz_catch(ctx)
                {
                    NSLog(@"Annotation creation failed");
                }
            });
        }
    }];
}

- (void)addHighlightAnnotationDelayedLeaveSelected:(BOOL)leaveSelected
{
    [self annotateSelection:PDF_ANNOT_HIGHLIGHT leaveSelected:leaveSelected];
}

- (void)addHighlightAnnotationLeaveSelected:(BOOL)leaveSelected
{
    __weak typeof(self) weakSelf = self;
    [self doAfterBackgroundTasks:^{
        [weakSelf addHighlightAnnotationDelayedLeaveSelected:leaveSelected];
    }];
}

- (void)addRedactAnnotation
{
    [self annotateSelection:PDF_ANNOT_REDACT leaveSelected:NO];
}

- (BOOL)hasRedactions
{
    return _pagesWithRedactions.count > 0;
}

- (void)finalizeRedactAnnotations:(void (^)(void))onComplete
{
    __block NSInteger numPages = _pagesWithRedactions.count;

    if (numPages == 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            onComplete();
        });
    }
    else
    {
        for (NSNumber *n in _pagesWithRedactions)
        {
            dispatch_async(self.mulib.queue, ^{
                fz_context *ctx = self.mulib.ctx;
                fz_try(ctx)
                {
                    pdf_document *idoc = pdf_specifics(ctx, self->_fzdoc);
                    if (idoc)
                    {
                        pdf_redact_options opts = {1, PDF_REDACT_IMAGE_PIXELS};
                        FzPage *fzPage = [self getFzPage:n.integerValue];
                        pdf_redact_page(ctx, idoc, (pdf_page *)fzPage.fzpage, &opts);
                        // pdf_redact_page doesn't mark any annotations as changed, so
                        // calling updatePages wont work. Instead trigger an update for
                        // the entire page.
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self updatePageNumbered:n.integerValue];
                        });
                    }
                }
                fz_catch(ctx)
                {
                }

                if (--numPages == 0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        onComplete();
                    });
                }
            });
        }

        [_pagesWithRedactions removeAllObjects];
    }
}

- (void)deleteSelectedAnnotation
{
    for (NSNumber *n in self.selections.allKeys)
    {
        NSInteger pageNumber = n.integerValue;
        NSObject<MuPDFDKSelection> *selection = self.selections[n];
        if ([selection isKindOfClass:MuPDFDKAnnotationInternal.class])
        {
            MuPDFDKAnnotationInternal *mannot = ((MuPDFDKAnnotationInternal *)selection);
            NSInteger index = mannot.index;
            BOOL isWidget = mannot.isWidget;
            dispatch_async(self.mulib.queue, ^{
                fz_context *ctx = self.mulib.ctx;
                pdf_document *idoc = pdf_specifics(ctx, self->_fzdoc);
                if (!idoc)
                    return;

                FzPage *page = [self getFzPage:n.integerValue];
                fz_try(ctx)
                {
                    pdf_annot *annot;
                    if (isWidget)
                    {
                        annot = page.fzpage ? pdf_first_widget(ctx, (pdf_page *)page.fzpage) : NULL;
                        for (int i = 0; i < index && annot; i++)
                            annot = pdf_next_widget(ctx, annot);
                    }
                    else
                    {
                        annot = page.fzpage ? pdf_first_annot(ctx, (pdf_page *)page.fzpage) : NULL;
                        for (int i = 0; i < index && annot; i++)
                            annot = pdf_next_annot(ctx, annot);
                    }

                    if (annot)
                    {
                        fz_rect rect = pdf_bound_annot(ctx, annot);
                        pdf_delete_annot(ctx, (pdf_page *)page.fzpage, annot);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self updatePageNumbered:pageNumber changedRects:@[[NSValue valueWithCGRect:rect_from_fz(rect)]]];
                        });
                    }
                }
                fz_catch(ctx)
                {
                }
            });
        }
    }

    [self clearSelection];
}

- (void)updateSelectedAnnotationsQuads
{
    for (NSNumber *n in self.selections.allKeys)
    {
        NSInteger pageNumber = n.integerValue;
        NSObject<MuPDFDKSelection> *selection = self.selections[n];
        if ([selection isKindOfClass:MuPDFDKAnnotationInternal.class])
        {
            NSArray<MuPDFDKQuad *> *quads = selection.quads;
            int quadCount = (int)quads.count;
            NSInteger index = ((MuPDFDKAnnotationInternal *)selection).index;
            NSInteger isWidget = ((MuPDFDKAnnotationInternal *)selection).isWidget;
            dispatch_async(self.mulib.queue, ^{
                fz_context *ctx = self.mulib.ctx;
                fz_quad *fzquads = NULL;
                pdf_document *idoc = pdf_specifics(ctx, self->_fzdoc);
                if (!idoc)
                    return;

                FzPage *page = [self getFzPage:n.integerValue];
                fz_var(fzquads);
                fz_try(ctx)
                {
                    pdf_annot *annot = NULL;
                    if (isWidget)
                    {
                        annot = page.fzpage ? pdf_first_widget(ctx, (pdf_page *)page.fzpage) : NULL;
                        for (int i = 0; i < index && annot; i++)
                            annot = pdf_next_widget(ctx, annot);
                    }
                    else
                    {
                        annot = page.fzpage ? pdf_first_annot(ctx, (pdf_page *)page.fzpage) : NULL;
                        for (int i = 0; i < index && annot; i++)
                            annot = pdf_next_annot(ctx, annot);
                    }

                    if (annot)
                    {
                        fz_rect oldrect = pdf_bound_annot(ctx, annot);
                        if (quads)
                        {
                            fzquads = fz_malloc_array(ctx, quadCount, fz_quad);
                            for (int i = 0; i < quadCount; i++)
                                fzquads[i] = quad_to_fz(quads[i]);
                            pdf_set_annot_quad_points(ctx, annot, quadCount, fzquads);
                        }
                        else
                        {
                            CGRect rect = selectionAsQuads(selection).firstObject.enclosingRect;
                            pdf_set_annot_rect(ctx, annot, rect_to_fz(rect));
                        }
                        [self updatePages];
                        fz_rect newrect = pdf_bound_annot(ctx, annot);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self selectionChangedForPage:pageNumber];
                            [self updatePageNumbered:pageNumber changedRects:@[[NSValue valueWithCGRect:rect_from_fz(oldrect)],
                                                                               [NSValue valueWithCGRect:rect_from_fz(newrect)]]];
                        });
                    }
                }
                fz_always(ctx)
                {
                    fz_free(ctx, fzquads);
                }
                fz_catch(ctx)
                {
                }
            });
        }
    }
}

- (void)setSearchStartPage:(NSInteger)page offset:(CGPoint)offset
{
    self.searchStartPage = page;
}

- (void)searchFor:(NSString *)text inDirection:(MuPDFDKSearchDirection)direction
          onEvent:(void (^)(MuPDFDKSearchEvent, NSInteger, CGRect))block
{
    // States:
    // New - text != self.searchText - this is a new search
    // Found - text == self.searchText && self.searchHits.count > 0 - this is continuation after previous success
    // NotFound - text == self.searchText && self.searchHits.count == 0 - this is continuation after previous failure
    NSInteger inc = direction == MuPDFDKSearch_Forwards ? 1 : -1;
    [self clearSelection];
    self.searchCancelled = NO;

    if (!self.searchText || ![self.searchText isEqualToString:text])
    {
        // This is a new search.
        // Clear the existing search if any
        if (self.searchHits.count > 0)
        {
            self.searchHits = nil;
            [self selectionChangedForPage:self.searchPage];
        }
        // Start from the requested start page
        self.searchPage =  direction == MuPDFDKSearch_Forwards ? self.searchStartPage : self.searchStartPage - 1;
        self.searchText = text;
    }

    if (self.searchHits.count > 0)
    {
        // This is continuation after a previous success
        self.searchCurrentHit += inc;
        if (0 <= self.searchCurrentHit && self.searchCurrentHit < self.searchHits.count)
        {
            // There was another hit on the same page
            [self selectionChangedForPage:self.searchPage];
            self.searchStartPage = self.searchPage;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.searchCancelled)
                {
                    [self closeSearch];
                    block(MuPDFDKSearch_Cancelled, 0, CGRectNull);
                }
                else
                {
                    block(MuPDFDKSearch_Found, self.searchPage, self.searchHits[self.searchCurrentHit].enclosingRect);
                }
            });
            return;
        }
        else
        {
            // No more hits on this page. Move to the next page
            self.searchHits = nil;
            [self selectionChangedForPage:self.searchPage];
            self.searchPage += inc;
        }
    }

    // This could be a new search, continuation after failure or continuation after
    // success but for the last hit on a page. We should look for the next page with
    // hits until we run off the end of the docuement. Because of the third case
    // mentioned above, we may already have run off the end of the document
    assert(self.searchHits.count == 0);
    assert(self.searchText.length > 0);
    NSString *searchText = self.searchText;

    dispatch_async(self.mulib.queue, ^{
        NSInteger page = self.searchPage;
        NSArray<MuPDFDKQuad *> *hits = nil;
        while (0 <= page && page < self.pageCount)
        {
            FzPage *fzpage = [self getFzPage:page];
            hits = fzpage.fzpage ? search_page(self.mulib.ctx, self->_fzdoc, fzpage.fzpage, searchText.UTF8String) : NSArray.array;
            if (self.searchCancelled || hits.count > 0)
                break;

            page += inc;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!self.searchCancelled)
                    block(MuPDFDKSearch_Progress, page, CGRectNull);
            });
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.searchCancelled)
            {
                [self closeSearch];
                block(MuPDFDKSearch_Cancelled, 0, CGRectNull);
            }
            else if (hits.count > 0)
            {
                // Found a page with at least one hit
                NSInteger currentHit = direction == MuPDFDKSearch_Forwards ? 0 : hits.count -1;
                self.searchStartPage = self.searchPage = page;
                self.searchHits = hits;
                self.searchCurrentHit = currentHit;
                [self selectionChangedForPage:page];
                block(MuPDFDKSearch_Found, page, hits[currentHit].enclosingRect);
            }
            else
            {
                // Failed to find a page with a hit
                // Set up page for potential wrap around
                self.searchPage = direction == MuPDFDKSearch_Forwards ? 0 : self.pageCount - 1;
                block(MuPDFDKSearch_NotFound, 0, CGRectNull);
            }
        });
    });
}

- (void)cancelSearch
{
    self.searchCancelled = YES;
}

- (void)closeSearch
{
    if (self.searchHits.count > 0)
    {
        self.searchHits = nil;
        [self selectionChangedForPage:self.searchPage];
    }
    self.searchText = nil;
}

- (void)updateAllPages
{
    for (MuPDFDKPageHolder *holder in _pages)
    {
        if (holder.page.update)
        {
            CGSize size = holder.page.size;
            holder.page.update(CGRectMake(0, 0, size.width, size.height));
        }
    }
}

- (void)updatePageNumbered:(NSInteger)pageNo changedRects:(NSArray<NSValue *> *)rects
{
    self.hasBeenModified = YES;
    if (self.onSelectionChanged)
        self.onSelectionChanged();
    for (MuPDFDKWeakEventTarget *weakTarget in _eventTargets)
        if ([weakTarget.target respondsToSelector:@selector(selectionHasChanged)])
            [weakTarget.target selectionHasChanged];

    for (MuPDFDKPageHolder *h in self->_pages)
    {
        if (h.pageNo == pageNo)
        {
            // Mark the page as dirty, so that the cached fzpage object
            // and display list are reloaded.
            h.page.displayListDirty = YES;
            h.page.textDirty = YES;

            if (h.page.update)
            {
                for (NSValue *v in rects)
                    h.page.update(v.CGRectValue);
            }
        }
    }
}

- (void)updatePageNumbered:(NSInteger)pageNo
{
    self.hasBeenModified = YES;
    if (self.onSelectionChanged)
        self.onSelectionChanged();
    for (MuPDFDKWeakEventTarget *weakTarget in _eventTargets)
        if ([weakTarget.target respondsToSelector:@selector(selectionHasChanged)])
            [weakTarget.target selectionHasChanged];

    for (MuPDFDKPageHolder *h in self->_pages)
    {
        if (h.pageNo == pageNo)
        {
            // Mark the page as dirty, so that the cached fzpage object
            // and display list are reloaded.
            h.page.displayListDirty = YES;
            h.page.textDirty = YES;

            if (h.page.update)
            {
                CGRect wholePage = {CGPointZero, h.page.size};
                h.page.update(wholePage);
            }
        }
    }
}

- (void) updatePagesRecalc:(BOOL)recalc
{
    assert(strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), queue_label) == 0);
    fz_context *ctx = self.mulib.ctx;

    for (NSNumber *key in _fzpages)
    {
        FzPageHolder *holder = _fzpages[key];
        pdf_page *page = (pdf_page *)holder.page.fzpage;
        if (page)
        {
            fz_try(ctx)
            {
                pdf_document *pdoc = pdf_document_from_fz_document(ctx, self.fzdoc);
                if (recalc && pdoc->recalculate)
                    pdf_calculate_form(ctx, pdoc);

                NSMutableArray<NSValue *> *updateRects = [NSMutableArray array];
                for (pdf_annot *annot = pdf_first_annot(ctx, page);annot;annot = pdf_next_annot(ctx, annot))
                {
                    if (pdf_update_annot(ctx, annot))
                    {
                        fz_rect rect = pdf_bound_annot(ctx, annot);
                        [updateRects addObject:[NSValue valueWithCGRect:rect_from_fz(rect)]];
                    }
                }

                for (pdf_widget *widget = pdf_first_widget(ctx, page);widget;widget = pdf_next_widget(ctx, widget))
                {
                    if (pdf_update_annot(ctx, widget))
                    {
                        fz_rect rect = pdf_bound_widget(ctx, widget);
                        [updateRects addObject:[NSValue valueWithCGRect:rect_from_fz(rect)]];
                    }
                }

                if (updateRects.count)
                {
                    // Poke the update block for each current instance of this page
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updatePageNumbered:holder.pageNo changedRects:updateRects];
                    });
                }
            }
            fz_catch(ctx)
            {
            }
        }
    }
}

- (void)updatePages
{
    [self updatePagesRecalc:YES];
}

- (MuPDFPrintProfile)printProfile
{
    return _printProfile;
}

- (void)setPrintProfile:(MuPDFPrintProfile)printProfile
{
    _printProfile = printProfile;
    [self updateAllPages];
}

- (ARDKSoftProfile)softProfile
{
    return _softProfile;
}

- (void)setSoftProfile:(ARDKSoftProfile)softProfile
{
    _softProfile = softProfile;
    [self updateAllPages];
}

- (void)abortLoad
{
    self.loadAborted = YES;
    if (self.errorBlock)
        self.errorBlock(ARDKDocErrorType_Aborted);
}

- (void)providePassword:(NSString *)password
{
    assert([NSThread isMainThread]);
    dispatch_async(self.mulib.queue, ^{
        fz_context *ctx = self.mulib.ctx;
        NSInteger count = 0;
        int authenticateResult = 0;
        BOOL failed = NO;
        fz_var(count);
        fz_var(authenticateResult);
        fz_var(failed);
        fz_try(ctx)
        {
            authenticateResult = fz_authenticate_password(self.mulib.ctx, self->_fzdoc, password.UTF8String);
            if (authenticateResult)
            {
                count = fz_count_pages(ctx, self.fzdoc);
            }
        }
        fz_catch(ctx)
        {
            failed = YES;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (failed)
            {
                if (self.errorBlock)
                    self.errorBlock(ARDKDocErrorType_UnableToLoadDocument);
                return;
            }

            if (authenticateResult == 0)
            {
                // incorrect password
                if (self.errorBlock)
                    self.errorBlock(ARDKDocErrorType_PasswordRequest);
            }
            else if (count <= 0)
            {
                if (self.errorBlock)
                    self.errorBlock(ARDKDocErrorType_UnableToLoadDocument);
                // A document may continue to load after an error, but
                // not in this case, so signal loading compelete.
                if (self.progressBlock)
                    self.progressBlock(0, YES);
                for (MuPDFDKWeakEventTarget *weakTarget in self.eventTargets)
                    [weakTarget.target updatePageCount:0 andLoadingComplete:YES];
            }
            else
            {
                self->_reportedPageCount = count;
                [self loadSomePages];
            }
        });
    });
}

- (FzPage *)getFzPage:(NSInteger)pageNumber
{
    assert(strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), queue_label) == 0);
    NSNumber *pn = [NSNumber numberWithInteger:pageNumber];
    FzPageHolder *holder = _fzpages[pn];

    if (holder.page)
        return holder.page;

    // There was no holder for this page number, or the weak page property may have been freed.
    // Overwrite it in either case.
    fz_context *ctx = self.mulib.ctx;
    fz_page *fzpage = NULL;
    fz_try(ctx)
    {
        fzpage = fz_load_page(ctx, self.fzdoc, (int)pageNumber);
    }
    fz_catch(ctx)
    {
    }

    FzPage *page = [FzPage pageFromPage:fzpage ofDoc:self];

    _fzpages[pn] = [FzPageHolder holderForPage:page numbered:pageNumber];

    return page;
}

- (id<ARDKPage>)getPage:(NSInteger)pageNumber update:(void (^)(CGRect))block
{
    MuPDFDKPage *page;
    @synchronized (self.pageSizes) {
        page = [[MuPDFDKPage alloc] initForPage:pageNumber ofDoc:self withSize:self.pageSizes[pageNumber].CGSizeValue update:block];
    }

    @synchronized(_pages)
    {
        // Remove from the pages array any defunct pages and add this new one
        NSMutableArray<MuPDFDKPageHolder *> *pages = [NSMutableArray array];
        for (MuPDFDKPageHolder *holder in _pages)
        {
            if (holder.page)
                [pages addObject:holder];
        }

        [pages addObject:[MuPDFDKPageHolder holderForPage:page numbered:pageNumber]];

        _pages = pages;
    }

    [page findFormFields];

    return page;
}

- (NSString *)fileBasedOn:(NSString *)templatePath
{
    BOOL isSecure = [MuPDFDKLib.secureFS ARDKSecureFS_isSecure:templatePath];
    NSFileManager *fman = [NSFileManager defaultManager];
#if TARGET_OS_OSX
    NSString *filePath = self.mulib.settings.temporaryPath;
#else /* TARGET_OS_OSX */
    NSString *filePath = [templatePath stringByDeletingLastPathComponent];
#endif /* TARGET_OS_OSX */
    NSString *fileNameWithExtension = [templatePath lastPathComponent];
    NSString *fileName = [fileNameWithExtension stringByDeletingPathExtension];
    NSString *extension = [fileNameWithExtension pathExtension];
    NSInteger i = 0;
    NSString *path;
    NSString *fullPath;
    while (YES)
    {
        path = [NSString stringWithFormat:@"%@%ld.%@", fileName, (long)i, extension];
        fullPath = [filePath stringByAppendingPathComponent:path];
        BOOL exists = isSecure ? [MuPDFDKLib.secureFS ARDKSecureFS_fileExists:fullPath] : [fman fileExistsAtPath:fullPath];
        if (!exists)
            break;

        i++;
    }

    return fullPath;
}

- (BOOL)createItemAtPath:(NSString *)path
{
    BOOL isSecure = [MuPDFDKLib.secureFS ARDKSecureFS_isSecure:path];
    if (isSecure)
    {
        [MuPDFDKLib.secureFS ARDKSecureFS_fileDelete:path];
        return [MuPDFDKLib.secureFS ARDKSecureFS_createFileAtPath:path];
    }
    else
    {
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        return [NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];
    }
}

- (BOOL)copyItemAtPath:(NSString *)from toPath:(NSString *)to
{
    BOOL isSecure = [MuPDFDKLib.secureFS ARDKSecureFS_isSecure:from];
    if (isSecure)
    {
        assert ([MuPDFDKLib.secureFS ARDKSecureFS_isSecure:to]);
        return [MuPDFDKLib.secureFS ARDKSecureFS_fileCopy:from to:to];
    }
    else
    {
        return [[NSFileManager defaultManager] copyItemAtPath:from toPath:to error:NULL];
    }
}

- (BOOL)moveItemAtPath:(NSString *)from toPath:(NSString *)to
{
    BOOL isSecure = [MuPDFDKLib.secureFS ARDKSecureFS_isSecure:from];
    if (isSecure)
    {
        id<ARDKSecureFS> secureFs = MuPDFDKLib.secureFS;
        assert ([MuPDFDKLib.secureFS ARDKSecureFS_isSecure:to]);
        if ([secureFs ARDKSecureFS_fileExists:to])
            [secureFs ARDKSecureFS_fileDelete:to];

        return [secureFs ARDKSecureFS_fileRename:from to:to];
    }
    else
    {
        NSFileManager *fman = [NSFileManager defaultManager];
        if ([fman fileExistsAtPath:to])
            [fman removeItemAtPath:to error:NULL];

        return [fman moveItemAtPath:from toPath:to error:NULL];
    }
}

- (void)saveTo:(NSString *)path completion:(void (^)(ARDKSaveResult, ARError))block
{
    BOOL jsEnable = _pdfFormFillingEnabled;
    NSString *tmpPath = [self fileBasedOn:path];
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(self.mulib.queue, ^{
        fz_context *ctx = self.mulib.ctx;
        BOOL written = NO;
        fz_output *ostream = NULL;
        weakSelf.isBeingSaved = YES;
        fz_var(written);
        fz_var(ostream);
        fz_try(ctx)
        {
            pdf_document *idoc = pdf_specifics(ctx, self.fzdoc);
            if (idoc)
            {
                pdf_write_options opts = {0};
                opts.do_incremental = pdf_can_be_saved_incrementally(ctx, idoc);
                if (opts.do_incremental ? [self copyItemAtPath:self.path toPath:tmpPath] : [self createItemAtPath:tmpPath])
                {
                    if ([MuPDFDKLib.secureFS ARDKSecureFS_isSecure:tmpPath])
                    {
                        ostream = secure_output(ctx, [MuPDFDKLib.secureFS ARDKSecureFS_fileHandleForUpdatingAtPath:tmpPath]);
                    }
                    else
                    {
                        // When using a secure FS we need to avoid calling fileSystemRepresentation
                        // which would Unicode Normalize tmpPath
                        if (MuPDFDKLib.secureFS)
                            ostream = fz_new_output_with_path(ctx, [tmpPath UTF8String], 1);
                        else
                            ostream = fz_new_output_with_path(ctx, tmpPath.fileSystemRepresentation, 1);
                    }

                    pdf_write_document(ctx, idoc, ostream, &opts);
                    fz_close_output(ctx, ostream);
                    if ([self moveItemAtPath:tmpPath toPath:path])
                    {
                        // Reopen the document, first removing all references to objects
                        fz_drop_document(ctx, self->_fzdoc);
                        self->_fzdoc = NULL;
                        fz_drop_stream(ctx, self->_stream);
                        self->_stream = NULL;

                        self->_fzpages = [NSMutableDictionary dictionaryWithCapacity:INITIAL_FZPAGE_CACHE_SIZE];

                        @synchronized(self->_pages)
                        {
                            for (MuPDFDKPageHolder *holder in self->_pages)
                            {
                                [holder.page drop_page];
                                [holder.page drop_list];
                                [holder.page forgetSignatures];
                            }
                        }

                        if (MuPDFDKLib.secureFS && [MuPDFDKLib.secureFS ARDKSecureFS_isSecure:@(self.path.UTF8String)])
                            self->_stream = secure_stream(ctx, [MuPDFDKLib.secureFS ARDKSecureFS_fileHandleForReadingAtPath:@(self.path.UTF8String)]);
                        else
                            self->_stream = fz_open_file(ctx, self.path.UTF8String);

                        self->_fzdoc = fz_open_document_with_stream(ctx, "file.pdf", self->_stream);
                        [self enableJS:jsEnable];
                        self->_path = path;
                        self->_hasBeenModified = NO;
                        written = YES;
                    }
                }
            }
        }
        fz_always(ctx)
        {
            fz_drop_output(ctx, ostream);
        }
        fz_catch(ctx)
        {
        }

        weakSelf.isBeingSaved = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            block(written ? ARDKSave_Succeeded : ARDKSave_Error, 0);
        });
    });
}

- (BOOL)docSupportsPageManipulation
{
    return NO;
}

- (void)addBlankPage:(NSInteger)pageNumber
{
    assert("Never called" == NULL);
}

- (void)duplicatePage:(NSInteger)pageNumber
{
    assert("Never called" == NULL);
}

- (void)deletePage:(NSInteger)pageNumber
{
    assert("Never called" == NULL);
}

- (void)movePage:(NSInteger)pageNumber to:(NSInteger)newNumber
{
    assert("Never called" == NULL);
}

@end

@interface MuPDFDKFont : NSObject
@property(readonly) NSString *variant;
@property(readonly) NSString *language;
@property(readonly) BOOL bold;
@property(readonly) BOOL italic;
@property(readonly) NSString *filepath;

- (fz_font *)loadFont:(fz_context *)ctx;

+ (NSArray<MuPDFDKFont *> *)loadFontFile;

@end

@implementation MuPDFDKFont

- (MuPDFDKFont *)initFromMapFileLine:(NSString *)line
{
    self = [super init];
    if (self)
    {
        NSArray<NSString *> *fields = [line componentsSeparatedByString:@","];
        if (fields.count != 7)
            return nil;
        NSArray<NSString *> *names = [fields[0] componentsSeparatedByString:@":"];
        if (![names.lastObject hasPrefix:@"lang-"])
            return nil;

        _variant = names[0];
        _language = names.lastObject;
        _bold = [fields[3] isEqualToString:@"Bold"];
        _italic = [fields[1] isEqualToString:@"Italic"];
#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
        NSString *fontdir = @"/System/Library/Fonts";
        NSArray<NSString *> *fontsubdirs = @[@"Core", @"CoreAddition", @"CoreUI", @"LanguageSupport", @"AppFonts", @"Watch"];
        for (NSString *subdir in fontsubdirs)
        {
            NSString *path = [[fontdir stringByAppendingPathComponent:subdir] stringByAppendingPathComponent:fields[6]];
            if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            {
                _filepath = path;
                break;
            }
        }
#else /* (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR) */
        NSArray<NSString *> *fontdirs = @[@"/System/Library/Fonts/", @"/Library/Fonts/"];
        for (NSString *dir in fontdirs)
        {
            NSString *path = [dir stringByAppendingPathComponent:fields[6]];
            if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            {
                _filepath = path;
                break;
            }
        }
#endif /* (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR) */

        if (!_filepath)
            return nil;
    }

    return self;
}

- (fz_font *)loadFont:(fz_context *)ctx
{
    fz_font *font = NULL;
    fz_var(font);
    fz_try(ctx)
    {
        for (int idx = 0; ; idx++)
        {
            font = fz_new_font_from_file(ctx, NULL, _filepath.UTF8String, idx, 0);
            if (font == NULL || strcmp(fz_font_name(ctx, font), _variant.UTF8String) == 0)
                break;

            fz_drop_font(ctx, font);
            font = NULL;
        }
    }
    fz_catch(ctx)
    {
        font = NULL;
    }

    return font;
}

+ (MuPDFDKFont *)fontFromMapFileLine:(NSString *)line
{
    return [[MuPDFDKFont alloc] initFromMapFileLine:line];
}

+ (NSArray<MuPDFDKFont *> *)loadFontFile
{
    NSMutableArray<MuPDFDKFont *> *result = [NSMutableArray array];
    NSString *mapPath = [[NSBundle bundleForClass:self.class] pathForResource:@"fontmap" ofType:nil];
    NSString *mapFile = [NSString stringWithContentsOfFile:mapPath encoding:NSUTF8StringEncoding error:nil];
    NSArray<NSString *> *lines = [mapFile componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines)
    {
        if (line.length > 0 && [line rangeOfString:@"#"].location != 0)
        {
            MuPDFDKFont *font = [MuPDFDKFont fontFromMapFileLine:line];
            if (font)
                [result addObject:font];
        }
    }

    return result;
}

@end

static NSArray<MuPDFDKFont *> *fonts;

static void ensure_font_file_loaded()
{
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        fonts = [MuPDFDKFont loadFontFile];
    });
}

static fz_font *load_cjk_font(fz_context *ctx, const char *name, int ros, int serif)
{
    ensure_font_file_loaded();
    NSDictionary<NSString *, NSNumber *> *lang2ros = @{@"lang-zh_tw":@(FZ_ADOBE_CNS), @"lang-zh_cn":@(FZ_ADOBE_GB), @"lang-ja_jp":@(FZ_ADOBE_JAPAN), @"lang-ko_kr":@(FZ_ADOBE_KOREA)};

    /* Search for a matching font twice, first trying to match weight */
    BOOL bold = (strstr(name, "Bold") != NULL);
    for (MuPDFDKFont *fontinfo in fonts)
    {
        NSNumber *nros = lang2ros[fontinfo.language];
        if (nros && nros.intValue == ros && fontinfo.bold == bold)
        {
            fz_font *font = [fontinfo loadFont:ctx];
            if (font)
                return font;
        }
    }

    for (MuPDFDKFont *fontinfo in fonts)
    {
        NSNumber *nros = lang2ros[fontinfo.language];
        if (nros && nros.intValue == ros)
        {
            fz_font *font = [fontinfo loadFont:ctx];
            if (font)
                return font;
        }
    }

    return nil;
}

static fz_font *load_font_for_language(fz_context *ctx, NSString *language, BOOL bold, BOOL italic)
{
    int best_score = 0;
    fz_font *best_font = NULL;

    for (MuPDFDKFont *fontinfo in fonts)
    {
        if ([fontinfo.language isEqualToString:language])
        {
            int score = 1;

            if (italic == fontinfo.italic)
                score += 1;

            if (bold == fontinfo.bold)
                score += 2;

            if (score > best_score)
            {
                fz_font *font = [fontinfo loadFont:ctx];
                if (font)
                {
                    fz_drop_font(ctx, best_font);
                    best_font = font;
                    best_score = score;
                }
            }

            if (best_score >= 4)
                break;
        }
    }

    return best_font;
}

static fz_font *load_fallback_font(fz_context *ctx, int script, int language, int serif, int bold, int italic)
{
    ensure_font_file_loaded();
    switch (script)
    {
        default:
        case UCDN_SCRIPT_COMMON:
        case UCDN_SCRIPT_INHERITED:
        case UCDN_SCRIPT_UNKNOWN:
            return NULL;

        case UCDN_SCRIPT_HANGUL:
        case UCDN_SCRIPT_HIRAGANA:
        case UCDN_SCRIPT_KATAKANA:
        case UCDN_SCRIPT_BOPOMOFO:
        case UCDN_SCRIPT_HAN:
            switch (language)
        {
            case FZ_LANG_ja: return load_font_for_language(ctx, @"lang-ja_jp", bold, italic);
            case FZ_LANG_ko: return load_font_for_language(ctx, @"lang-ko_kr", bold, italic);
            case FZ_LANG_zh_Hans: return load_font_for_language(ctx, @"lang-zh_cn", bold, italic);
            default:
            case FZ_LANG_zh_Hant: return load_font_for_language(ctx, @"lang-zh_tw", bold, italic);
        }

        case UCDN_SCRIPT_LATIN:
        case UCDN_SCRIPT_GREEK:
        case UCDN_SCRIPT_CYRILLIC:
        case UCDN_SCRIPT_ARABIC:
            return load_font_for_language(ctx, @"lang-ar_ar", bold, italic);

        case UCDN_SCRIPT_HEBREW:
            return load_font_for_language(ctx, @"lang-he_il", bold, italic);

        case UCDN_SCRIPT_BENGALI:
            return load_font_for_language(ctx, @"lang-bn_in", bold, italic);

        case UCDN_SCRIPT_DEVANAGARI:
            return load_font_for_language(ctx, @"lang-hi_in", bold, italic);

        case UCDN_SCRIPT_GUJARATI:
            return load_font_for_language(ctx, @"lang-gu_in", bold, italic);

        case UCDN_SCRIPT_GURMUKHI:
            return load_font_for_language(ctx, @"lang-pa_in", bold, italic);

        case UCDN_SCRIPT_KANNADA:
            return load_font_for_language(ctx, @"lang-kn_in", bold, italic);

        case UCDN_SCRIPT_TAMIL:
            return load_font_for_language(ctx, @"lang-ta_in", bold, italic);

        case UCDN_SCRIPT_TELUGU:
            return load_font_for_language(ctx, @"lang-te_in", bold, italic);

        case UCDN_SCRIPT_KHMER:
            return load_font_for_language(ctx, @"lang-vi_vn", bold, italic);
    }
}

@implementation MuPDFDKLib

static id<ARDKSecureFS> MuPDFDKLib_secureFS = nil;

@synthesize settings=_settings;

+ (id<ARDKSecureFS>)secureFS
{
    return MuPDFDKLib_secureFS;
}

- (instancetype)initWithSettings:(ARDKSettings *)settings
{
    self = [super init];
    if (self)
    {

#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
#if !defined(SODK_EXCLUDE_OPENSSL_PDF_SIGNING)
        
        // initialize the OpenSLL and Crypto libraries
        SSL_library_init();
        SSL_load_error_strings();
        ERR_load_crypto_strings();

#endif // SODK_EXCLUDE_OPENSSL_PDF_SIGNING
#endif // (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)

        _settings = settings;
        MuPDFDKLib_secureFS = settings.secureFs;
        self.queue = dispatch_queue_create(queue_label, NULL);
        __block fz_context *ctx;
        __block BOOL failed = NO;
        dispatch_sync(self.queue, ^{
            ctx = fz_new_context(NULL, NULL, 64<<20);
            fz_try(ctx)
            {
                fz_register_document_handlers(ctx);
                fz_install_load_system_font_funcs(ctx, NULL, load_cjk_font, load_fallback_font);
            }
            fz_catch(ctx)
            {
                failed = YES;
            }
        });
        if (failed)
            self = nil;
        else
            _ctx = ctx;
    }
    return self;
}

- (void)dealloc
{
    fz_context *ctx = _ctx;
    dispatch_async_if_needed(_queue, ^{
        fz_drop_context(ctx);
    });
}

- (id<ARDKDoc>)docForPath:(NSString *)path ofType:(ARDKDocType)docType
{
    return [[MuPDFDKDoc alloc] initForPath:path ofType:docType lib:self];
}

@end
