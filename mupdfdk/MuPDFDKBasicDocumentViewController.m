//
//  MuPDFDKBasicDocumentViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 21/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKGeometry.h"
#import "ARDKPageGeometry.h"
#import "ARDKBasicDocumentViewController.h"
#import "ARDKBasicDocumentViewProtected.h"
#import "ARDKPKCS7.h"
#import "ARDKDefaultFileState.h"
#import "MuPDFDKLib.h"
#import "MuPDFDKPageView.h"
#import "MuPDFDKAnnotInfoViewController.h"
#import "MuPDFDKTextWidgetViewController.h"
#import "MuPDFDKOptionWidgetViewController.h"
#import "MuPDFDKBasicDocumentViewController.h"

@interface SelectionInfo : NSObject
@property(readonly) BOOL isWidgetSelection;
@property(copy,readonly) ARDKPagePoint *start;
@property(copy,readonly) ARDKPagePoint *end;

+ (instancetype)selectionWithStart:(ARDKPagePoint *)start
                            andEnd:(ARDKPagePoint *)end
                 isWidgetSelection:(BOOL)isWidgetSelection;
@end

@implementation SelectionInfo

+ (instancetype)selectionWithStart:(ARDKPagePoint *)start
                            andEnd:(ARDKPagePoint *)end
                 isWidgetSelection:(BOOL)isWidgetSelection
{

    SelectionInfo *sinfo = [[SelectionInfo alloc] init];
    if (sinfo)
    {
        sinfo->_isWidgetSelection = isWidgetSelection;
        sinfo->_start = start;
        sinfo->_end = end;
    }

    return sinfo;
}

@end

#define DEFAULT_INK_ANNOTATION_THICKNESS (6.0)
#define HANDLE_SIZE (40.0)
#define HANDLE_OFFSET (7.0)

#define ANNOT_INFO_WIDTH (200.0)
#define ANNOT_INFO_HEIGHT (150.0)

@interface MuPDFDKBasicDocumentViewController () <UITextViewDelegate,UIPopoverPresentationControllerDelegate>
@property UIView *handleTopLeft;
@property UIView *handleBottomRight;
@property BOOL handleTopLeftIsBeingDragged;
@property BOOL handleBottomRightIsBeingDragged;
@property BOOL selectedHighlightForAdjustment;
@property MuPDFDKAnnotInfoViewController *annotInfo;
@property NSLayoutConstraint *annotInfoX;
@property NSLayoutConstraint *annotInfoY;
@property BOOL annotInfoCommentDidChange;
@property UIView *coverView;
@property BOOL scrollToSelection;
@property BOOL focusSelection;
@property BOOL xfaWarningGiven;
@property void (^onDismissPopover)(void);
@end

@implementation MuPDFDKBasicDocumentViewController
{
    MuPDFDKAnnotatingMode _annotatingMode;
    UIColor *_inkAnnotationColor;
    CGFloat _inkAnnotationThickness;
}

// session is defined in the subclass
@dynamic session;

- (instancetype)initForSession:(ARDKDocSession *)session
{
    self = [super initForSession:session];
    if (self)
    {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        CGFloat thickness = [userDefaults floatForKey:ARDK_InkAnnotationThicknessKey];
        _inkAnnotationThickness = thickness > 0.0 ? thickness : DEFAULT_INK_ANNOTATION_THICKNESS;
        NSData *colorData = [userDefaults objectForKey:ARDK_InkAnnotationColorKey];
        
        NSError *err = nil;
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:colorData
                                                                                    error:nil];
        unarchiver.requiresSecureCoding = NO;
        UIColor *color = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey
                                                          error:&err];
        if (err)
        {
            NSLog(@"Error: colorData could not be loaded due to error: %@", [err localizedDescription]);
        }

        _inkAnnotationColor = color ? color : [UIColor redColor];
        __weak typeof(self) weakSelf = self;
        session.presaveBlock = ^{
            [weakSelf endTextWidgetEditing];
        };
    }
    return self;
}

+ (instancetype)viewControllerForSession:(ARDKDocSession *)session
{
    assert([session.doc isMemberOfClass:MuPDFDKDoc.class]);
    if (![session.doc isMemberOfClass:MuPDFDKDoc.class])
        return nil;

    return [[MuPDFDKBasicDocumentViewController alloc] initForSession:session];
}

+ (instancetype)viewControllerForPath:(NSString *)path
{
    MuPDFDKLib *lib = [[MuPDFDKLib alloc] initWithSettings:nil];
    ARDKDefaultFileState *fileState  = [ARDKDefaultFileState fileStateForPath:path ofType:[MuPDFDKDoc docTypeFromFileExtension:path]];
    ARDKDocumentSettings *settings = [[ARDKDocumentSettings alloc] init];
    [settings enableAll:YES];
    ARDKDocSession *session = [ARDKDocSession sessionForFileState:fileState ardkLib:lib docSettings:settings];
    return [self viewControllerForSession:session];
}

- (MuPDFDKDoc *)mudoc
{
    return (MuPDFDKDoc *)self.doc;
}

- (UIImageView *)loadHandle:(NSString *)imageName atSize:(CGFloat)size
{
    UIImageView *handle = [[UIImageView alloc] initWithImage:[UIImage imageNamed:imageName inBundle:[NSBundle bundleForClass:self.class] compatibleWithTraitCollection:nil]];
    handle.frame = CGRectMake(0, 0, size, size);
    handle.contentMode = UIViewContentModeCenter;
    return handle;
}

- (void)addAnnotInfo
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"mupdfcallouts" bundle:[NSBundle bundleForClass:self.class]];
    self.annotInfo = [sb instantiateViewControllerWithIdentifier:@"annotInfo"];
    [self addChildViewController:self.annotInfo];
    [self.view addSubview:self.annotInfo.view];
    [self.annotInfo didMoveToParentViewController:self];
    self.annotInfo.view.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray *width = [NSLayoutConstraint constraintsWithVisualFormat:@"[info(v)]" options:0 metrics:@{@"v":@ANNOT_INFO_WIDTH} views:@{@"info":self.annotInfo.view}];
    NSArray *height = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[info(v)]" options:0 metrics:@{@"v":@ANNOT_INFO_HEIGHT} views:@{@"info":self.annotInfo.view}];
    self.annotInfoX = [NSLayoutConstraint constraintWithItem:self.annotInfo.view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0];
    self.annotInfoY = [NSLayoutConstraint constraintWithItem:self.annotInfo.view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
    [self.annotInfo.view addConstraints:width];
    [self.annotInfo.view addConstraints:height];
    [self.view addConstraint:self.annotInfoX];
    [self.view addConstraint:self.annotInfoY];
    self.annotInfo.view.hidden = YES;
}

- (void)onAlert:(MuPDFAlert *)alert
{
    NSString *okayString = NSLocalizedString(@"Okay", @"Label on Okay button");
#ifdef NUI_FORMS_ALERT_RESPONSE
    NSString *cancelString = NSLocalizedString(@"Cancel", @"Label on Cancel button");
    NSString *yesString = NSLocalizedString(@"Yes", @"Label on Yes button");
    NSString *noString = NSLocalizedString(@"No", @"Label on No button");
#endif
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:alert.title message:alert.message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:okayString style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        alert.reply(MuPDFAlertButton_Ok);
    }];
#ifdef NUI_FORMS_ALERT_RESPONSE
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:cancelString style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        alert.reply(MuPDFAlertButton_Cancel);
    }];
    UIAlertAction *yes = [UIAlertAction actionWithTitle:yesString style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        alert.reply(MuPDFAlertButton_Yes);
    }];
    UIAlertAction *no = [UIAlertAction actionWithTitle:noString style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        alert.reply(MuPDFAlertButton_No);
    }];

    switch (alert.buttonGroup)
    {
        case MuPDFAlertButtonGroup_Ok:
            [ac addAction:ok];
            break;

        case MuPDFAlertButtonGroup_OkCancel:
            [ac addAction:ok];
            [ac addAction:cancel];
            break;

        case MuPDFAlertButtonGroup_YesNo:
            [ac addAction:yes];
            [ac addAction:no];
            break;

        case MuPDFAlertButtonGroup_YesNoCancel:
            [ac addAction:yes];
            [ac addAction:no];
            [ac addAction:cancel];
            break;
    }
#else
    [ac addAction:ok];
#endif

    [self presentViewController:ac animated:YES completion:nil];
}

- (void)loadView
{
    [super loadView];
    __weak typeof(self) weakSelf = self;
    self.mudoc.onSelectionChanged = ^{
        [weakSelf onSelectionChanged];
    };
    self.mudoc.onAlert = ^(MuPDFAlert *alert) {
        [weakSelf onAlert:alert];
    };
    self.handleTopLeft = [self loadHandle:@"selection-top-left" atSize:HANDLE_SIZE];
    self.handleBottomRight = [self loadHandle:@"selection-bottom-right" atSize:HANDLE_SIZE];
    self.handleTopLeft.userInteractionEnabled = YES;
    self.handleBottomRight.userInteractionEnabled = YES;
    self.handleTopLeft.hidden = YES;
    self.handleBottomRight.hidden = YES;
    [self.view addSubview:self.handleTopLeft];
    [self.view addSubview:self.handleBottomRight];
    [self addAnnotInfo];
    UIPanGestureRecognizer *topLeftPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(topLeftPanned:)];
    [self.handleTopLeft addGestureRecognizer:topLeftPan];
    UIPanGestureRecognizer *bottomRightPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(bottomRightPanned:)];
    [self.handleBottomRight addGestureRecognizer:bottomRightPan];
}

- (void)topLeftPanned:(UIPanGestureRecognizer *)gesture;
{
    self.handleTopLeft.center = [gesture locationInView:self.view];

    BOOL startDrag = (gesture.state == UIGestureRecognizerStateBegan);
    BOOL endDrag =  (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled);
    CGPoint pt = ARCGPointOffset(self.handleTopLeft.center, HANDLE_OFFSET, HANDLE_OFFSET);
    [self forCellAtPoint:pt do:^(NSInteger index, UIView *cell, CGPoint pt) {
        MuPDFDKPageView *pageView = (MuPDFDKPageView *)cell;
        if (startDrag)
            pageView.selectionIsBeingAdjusted = YES;
        [pageView updateTextSelectionStart:pt];
        if (endDrag)
            pageView.selectionIsBeingAdjusted = NO;
    }];

    self.handleTopLeftIsBeingDragged = !endDrag;
}

- (void)bottomRightPanned:(UIPanGestureRecognizer *)gesture
{
    self.handleBottomRight.center = [gesture locationInView:self.view];

    BOOL startDrag = (gesture.state == UIGestureRecognizerStateBegan);
    BOOL endDrag =  (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled);
    CGPoint pt = ARCGPointOffset(self.handleBottomRight.center, -HANDLE_OFFSET, -HANDLE_OFFSET);
    [self forCellAtPoint:pt do:^(NSInteger index, UIView *cell, CGPoint pt) {
        MuPDFDKPageView *pageView = (MuPDFDKPageView *)cell;
        if (startDrag)
            pageView.selectionIsBeingAdjusted = YES;
        [pageView updateTextSelectionEnd:pt];
        if (endDrag)
            pageView.selectionIsBeingAdjusted = NO;
    }];

    self.handleBottomRightIsBeingDragged = !endDrag;
}

/// Override: perform further set up of MuPDFDKPageView
- (void)setupPageCell:(id<ARDKPageCell>)cell forPage:(NSInteger)page
{
    MuPDFDKPageView *pageView = (MuPDFDKPageView *)cell.pageView;
    if (pageView == nil)
    {
        pageView = [[MuPDFDKPageView alloc] initWithDoc:self.doc];
        cell.pageView = pageView;
    }

    [pageView useForPageNumber:page withSize:cell.pageViewFrame.size];
    pageView.annotatingMode = _annotatingMode;
    pageView.inkAnnotationColor = _inkAnnotationColor;
    pageView.inkAnnotationThickness = _inkAnnotationThickness;
    [pageView prepareForSelection];
}

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController
{
    if (self.onDismissPopover)
        self.onDismissPopover();
}

- (void)invokeListViewController:(MuPDFDKWidgetList *)listWidget ofView:(MuPDFDKPageView *)view;
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"mupdfcallouts" bundle:[NSBundle bundleForClass:self.class]];
    MuPDFDKOptionWidgetViewController *vc = [sb instantiateViewControllerWithIdentifier:@"option-widget"];
    __weak typeof(vc) weakVc = vc;
    __weak typeof(self) weakSelf = self;
    __weak typeof(view) weakView = view;
    vc.options = listWidget.optionText;
    vc.onUpdate = ^(void) {
        self.disableScrollOnKeyboardHidden = NO;
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
        listWidget.setOption(weakVc.currentOption, ^(BOOL accepted) {
            if (accepted)
            {
                [weakSelf moveToNextField:weakView];
                [weakSelf.delegate updateUI];
            }
            else
            {
                [weakSelf invokeListViewController:listWidget ofView:view];
            }
        });
    };
    vc.onCancel = ^{
        [((MuPDFDKDoc *)weakSelf.doc) clearFocus];
        self.disableScrollOnKeyboardHidden = NO;
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };
    self.onDismissPopover = ^{
        if (weakVc)
            listWidget.setOption(weakVc.currentOption, ^(BOOL accepted) {
                if (accepted)
                {
                    [((MuPDFDKDoc *)weakSelf.doc) clearFocus];
                    [weakSelf.delegate updateUI];
                }
            });
    };
    vc.preferredContentSize = [vc.view systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    vc.modalPresentationStyle = UIModalPresentationPopover;
    [self presentViewController:vc animated:YES completion:nil];
    UIPopoverPresentationController *pop = vc.popoverPresentationController;
    pop.delegate = self;
    pop.sourceView = view;
    pop.sourceRect = ARCGRectScale(listWidget.rect, view.baseZoom);
    pop.backgroundColor = vc.view.backgroundColor;
    self.disableScrollOnKeyboardHidden = YES;
}

- (void)invokeSignatureVerifyViewController:(MuPDFDKWidgetSignedSignature *)signatureWidget
{
    __weak typeof(self) weakSelf = self;
    if (self.session.signingDelegate)
    {
        [self.session.signingDelegate createVerifier:self
                                          onComplete:^(id<PKCS7Verifier> verifier)
             {
                 if (verifier)
                 {
                     signatureWidget.verify(verifier,
                                            ^(PKCS7VerifyResult verifyResult,
                                              int invalidChangePoint,
                                              id<PKCS7DesignatedName> designatedName,
                                              id<PKCS7Description> description)
                                            {
                                                [self.session.signingDelegate presentVerifyResult:self
                                                                                     verifyResult:verifyResult
                                                                               invalidChangePoint:invalidChangePoint
                                                                                   designatedName:designatedName
                                                                                      description:description
                                                                                       onComplete:^(void) {
                                                    [weakSelf.mudoc clearFocus];
                                                }];
                                            });
                 }
                 else
                 {
                     [weakSelf.mudoc clearFocus];
                 }
             }];
    }
    else
    {
        [self.mudoc clearFocus];
    }
}

- (void)invokeSigningAlert:(MuPDFDKWidgetUnsignedSignature *)signatureWidget forPage:(MuPDFDKPage *)page
{
    __weak typeof(self) weakSelf = self;
    if (self.session.signingDelegate)
    {
        BOOL editable = signatureWidget.wasCreatedInThisSession;
        NSString *titleString = NSLocalizedString(@"Signature", @"Title of alert box");
        NSString *signString = NSLocalizedString(@"Would you like to sign the document", @"Message of alert box");
        NSString *signOrEditString = NSLocalizedString(@"Would you like to sign the document, reposition the field or delete the field", @"Message on alert box");
        NSString *signButtonTitle = NSLocalizedString(@"Sign", @"Button title for action of signing a document");
        NSString *repositionTitle = NSLocalizedString(@"Reposition", @"Button title for action of repositioning a form field");
        NSString *deleteTitle = NSLocalizedString(@"Delete", @"Button title for action of deleting a form field");
        NSString *cancelTitle = NSLocalizedString(@"Cancel", @"Button title for cancelling action");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:titleString message:(editable ? signOrEditString : signString) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *signAction = [UIAlertAction actionWithTitle:signButtonTitle style: UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if (self.session.signingDelegate)
                {
                    [self.session.signingDelegate createSigner:self
                                                    onComplete:^(id<PKCS7Signer> signer)
                         {
                             if (signer)
                             {
                                 // sign the widget
                                 signatureWidget.sign(signer, ^(BOOL accepted) {
                                     [weakSelf.mudoc clearFocus];
                                 });
                             }
                             else
                             {
                                 [weakSelf.mudoc clearFocus];
                             }
                         }];
                }
                else
                {
                    [weakSelf.mudoc clearFocus];
                }
            }];
        [alert addAction:signAction];
        if (editable)
        {
            UIAlertAction *repositionAction = [UIAlertAction actionWithTitle:repositionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [page selectAnnotation:signatureWidget.annot];
            }];
            [alert addAction:repositionAction];

            UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:deleteTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [page selectAnnotation:signatureWidget.annot];
                [((MuPDFDKDoc *)self.doc) deleteSelectedAnnotation];
            }];
            [alert addAction:deleteAction];
        }
        UIAlertAction *noAction = [UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf.mudoc clearFocus];
        }];
        [alert addAction:noAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
    else
    {
        [self.mudoc clearFocus];
    }
}

- (MuPDFDKPageView *)findPageViewWithWidget
{
    __block MuPDFDKPageView *widgetView = nil;

    [self iteratePages:^(NSInteger i, UIView<ARDKPageCellDelegate> *pageView, CGRect screenRect) {
        MuPDFDKPageView *mView = (MuPDFDKPageView *)pageView;
        if ([mView hasWidgetView])
            widgetView = mView;
    }];

    return widgetView;
}

- (void)endTextWidgetEditing
{
    MuPDFDKPageView *widgetPage = [self findPageViewWithWidget];
    if (widgetPage)
    {
        if (![widgetPage finalizeWidgetView])
        {
            [widgetPage resetWidgetView];
        }

        [widgetPage removeWidgetView];
        [(MuPDFDKDoc *)self.doc clearFocus];
    }
}

- (BOOL)tapConsumedByWidgetOnPageView:(MuPDFDKPageView *)pageView at:(CGPoint)pt isDoubleTap:(BOOL)isDouble
{
    // A tap can be consumed by the current widget view (if present) in one of two ways. If the tap
    // is over the widget then it is sent to the widget, with the purpose of changing the selection.
    // If the tap is elsewhere then we must try to finalize the widget (i.e., request that the PDF
    // field accepts the current text as the final form). The request may be rejected, in which case we need
    // to keep the widget focussed and the tap is, in that sense, consumed.
    if ([pageView hasWidgetView])
    {
        BOOL hit = isDouble ? [pageView doubleTapWithinWidgetView:pt] : [pageView tapWithinWidgetView:pt];
        if (hit)
        {
            [pageView setWidgetMenuVisible:YES];
            return YES;
        }
        else
        {
            if ([pageView finalizeWidgetView])
            {
                // Don't remove the widget view because it may be reused. We remove it
                // elsewhere if need be.
                return NO;
            }
            else
            {
                [pageView showWidget];
                return YES;
            }
        }
    }
    else
    {
        MuPDFDKPageView *widgetView = [self findPageViewWithWidget];

        if (widgetView == nil)
            return NO;

        if ([widgetView finalizeWidgetView])
        {
            [widgetView removeWidgetView];
            [(MuPDFDKDoc *)self.doc clearFocus];
            return NO;
        }
        else
        {
            [widgetView showWidget];
            return YES;
        }
    }
}

- (void)warnOfUnsavedSignature
{
    NSString *title = NSLocalizedString(@"Cannot verify signature", @"Title of unsaved-signature warning");
    NSString *message = NSLocalizedString(@"Signature cannot be verified until after the document has been saved", @"Message of unsaved_signature warning");
    NSString *ok = NSLocalizedString(@"OK", @"Button text");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:ok style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)focusWidgetView:(MuPDFDKWidget *)widget onPage:(MuPDFDKPageView *)pageView at:(CGPoint)point andSelect:(BOOL)select
{
    __weak typeof(self) weakSelf = self;
    __weak typeof(pageView) weakPageView = pageView;
    [widget switchCaseText:^(MuPDFDKWidgetText *widget) {
        // Try to repurpose the current widget view
        if (![weakPageView focusOnField:widget])
        {
            // Otherwise create an appropriate one
            [weakPageView removeWidgetView];
            [weakPageView addTextWidgetView:widget withPasteboard:weakSelf.pasteboard showRect:^(CGRect srect) {
                [weakSelf showArea:srect onPage:weakPageView.pageNumber];
            } whenDone:^{
                [weakSelf moveToNextField:weakPageView];
            } whenSelectionChanged:^{
                [weakSelf onSelectionChanged];
            }];
        }
        if (select)
            [weakPageView tapWithinWidgetView:point];
    } caseList:^(MuPDFDKWidgetList *widget) {
        [weakSelf showArea:widget.rect onPage:weakPageView.pageNumber];
        [weakPageView removeWidgetView];
        [self invokeListViewController:widget ofView:weakPageView];
    } caseRadio:^(MuPDFDKWidgetRadio *widget) {
        // Try to repurpose the current widget view
        if (![weakPageView focusOnField:widget])
        {
            // Otherwise create an appropriate one
            [weakPageView removeWidgetView];
            [weakPageView addRadioWidgetView:widget showRect:^(CGRect rect) {
                [weakSelf showArea:rect onPage:weakPageView.pageNumber];
            } whenDone:^{
                [weakSelf moveToNextField:weakPageView];
            }];
        }
        if (select)
            [weakPageView tapWithinWidgetView:point];
    } caseSignedSignature:^(MuPDFDKWidgetSignedSignature *widget) {
        if (self.session.docSettings.pdfFormSigningEnabled)
        {
            [weakSelf showArea:widget.rect onPage:weakPageView.pageNumber];
            [weakPageView removeWidgetView];
            if (widget.unsaved)
            {
                [weakSelf warnOfUnsavedSignature];
            }
            else
            {
                [weakSelf invokeSignatureVerifyViewController:widget];
            }
        }
    } caseUnsignedSignature:^(MuPDFDKWidgetUnsignedSignature *widget){
        if (self.session.docSettings.pdfFormSigningEnabled)
        {
            [weakSelf showArea:widget.rect onPage:weakPageView.pageNumber];
            [weakPageView removeWidgetView];
            [weakSelf invokeSigningAlert:widget forPage:weakPageView.page];
        }
    }];
}

- (void)showXFAWarning
{
    NSString *okButtonString = NSLocalizedStringFromTableInBundle(@"OK", nil, [NSBundle bundleForClass:self.class], @"Label for button to accept password and open the document");
    NSString *title = NSLocalizedStringFromTableInBundle(@"Warning", nil, [NSBundle bundleForClass:self.class], @"Title of alert view presenting a warning");
    NSString *msgFmt = NSLocalizedStringFromTableInBundle(@"This document uses dual forms, Acroform and XFA. %@ will use the Acroform. Adobe products preferentially use XFA. Form edits may not be shown in Adobe products. Other PDF viewers should work correctly.", nil, [NSBundle bundleForClass:self.class], @"Warning message concerning potential form-filling problems");
    NSString *productName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    NSString *msg = [NSString stringWithFormat:msgFmt, productName];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:okButtonString style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tapForm:(MuPDFDKPageView *)pageView At:(CGPoint)point
{
    __weak typeof(self) weakSelf = self;
    __weak typeof(pageView) weakPageView = pageView;
    [pageView tapAt:point onFocus:^(MuPDFDKWidget *widget) {
        if (widget)
        {
            if (((MuPDFDKDoc *)weakSelf.doc).hasXFAForm && !weakSelf.xfaWarningGiven)
            {
                [self showXFAWarning];
                weakSelf.xfaWarningGiven = YES;
            }
            else if (self.session.docSettings.pdfFormFillingEnabled)
            {
                [weakSelf focusWidgetView:widget onPage:weakPageView at:point andSelect:YES];
            }
            else if (self.session.docSettings.featureDelegate)
            {
                // We can't get to this point in the code unless form-filling is at least available.
                [self.session.docSettings.featureDelegate ardkDocumentSettings:self.session.docSettings pressedDisabledFeature:pageView atPosition:point];
            }
        }
        else
        {
            [weakPageView removeWidgetView];
            [(MuPDFDKDoc *)self.doc clearFocus];
            if (![self.delegate swallowSelectionTap])
                [weakPageView selectAnnotationAt:point];
        }
    }];
}

- (void)moveToNextField:(MuPDFDKPageView *)pageView
{
    __weak typeof(pageView) weakPageView = pageView;
    __weak typeof(self) weakSelf = self;
    if ([pageView finalizeWidgetView])
    {
        [pageView focusNextField:^(MuPDFDKWidget *widget) {
            if (widget)
            {
                [weakSelf focusWidgetView:widget onPage:weakPageView at:CGPointZero andSelect:NO];
            }
            else
            {
                [weakPageView removeWidgetView];
                [(MuPDFDKDoc *)self.doc clearFocus];
            }
        }];
    }
}

/// Override: react to a single tap on cells
- (void)didTapCell:(UIView *)cell at:(CGPoint)point
{
    self.selectedHighlightForAdjustment = NO;

    MuPDFDKPageView *pageView = (MuPDFDKPageView *)cell;
    if ([self tapConsumedByWidgetOnPageView:pageView at:point isDoubleTap:NO])
        return;

    [self.mudoc clearSelection];

    if (self.annotatingMode == MuPDFDKAnnotatingMode_Note
        || self.annotatingMode == MuPDFDKAnnotatingMode_DigitalSignature)
    {
        [pageView removeWidgetView]; // Perhaps not necessary, but just in case
        BOOL success = self.annotatingMode == MuPDFDKAnnotatingMode_Note
                                            ? [pageView addTextAnnotationAt:point]
                                            : [pageView addSignatureFieldAt:point];
        if (success)
        {
            self.annotatingMode = MuPDFDKAnnotatingMode_None;
            self.scrollToSelection = YES;
            self.focusSelection = YES;
            [self.delegate updateUI];
        }
    }
    else
    {
        [pageView testAt:point forHyperlink:^(id<ARDKHyperlink> link) {
            if (link)
            {
                [pageView removeWidgetView];
                [(MuPDFDKDoc *)self.doc clearFocus];
                [link handleCaseInternal:^(NSInteger page, CGRect box) {
                    [self pushViewingState:page withOffset:box.origin];
                    [self showPage:page withOffset:box.origin];
                } orCaseExternal:^(NSURL *url) {
                    [self.delegate callOpenUrlHandler:url fromVC:self];
                }];
            }
            else
            {
                if (self.session.docSettings.pdfFormFillingAvailable) {
                    // Form-filling available. It may not be enabled, but even if not, we need to check for a
                    // form field, so that if we hit one, we can offer pro features.
                    [self tapForm:pageView At:point];
                } else if (![self.delegate swallowSelectionTap])
                    [pageView selectAnnotationAt:point];
            }
        }];
    }
}

/// Override: react to double taps on cells
- (void)didDoubleTapCell:(UIView *)cell at:(CGPoint)point
{
    self.selectedHighlightForAdjustment = NO;

    MuPDFDKPageView *pageView = (MuPDFDKPageView *)cell;
    if ([self tapConsumedByWidgetOnPageView:pageView at:point isDoubleTap:YES])
        return;

    [self.mudoc clearSelection];

    [pageView removeWidgetView];
    [(MuPDFDKDoc *)self.doc clearFocus];
    if (![self.delegate swallowSelectionDoubleTap])
    {
        [pageView forAnnotationAtPt:point onPage:^(MuPDFDKAnnotation *annot) {
            if (annot)
            {

                if (annot.type == MuPDFAnnotType_Highlight)
                    self.selectedHighlightForAdjustment = YES;
                [((MuPDFDKPage *)pageView.page) selectAnnotation:annot];
            }
            else
            {
                [pageView selectWordAt:point];
            }
        }];
    }
}

- (void)didDragDocument
{
    // The user scrolled the document, so forget the area that we
    // are keeping on screen
    [self forgetShowArea];
    // Also try to end in-place form filling. This is a slight hack necessary because of
    // strange behaviour from UICollectionViewController: a page that scrolls off
    // screen while including the first responder does not reappear when scrolled
    // back. If the attempt fails, the widget is scolled back on screen.
    MuPDFDKPageView *pageWithWidget = [self findPageViewWithWidget];
    if (pageWithWidget)
    {
        if ([pageWithWidget finalizeWidgetView])
        {
            [pageWithWidget removeWidgetView];
            [(MuPDFDKDoc *)self.doc clearFocus];
        }
        else
        {
            [pageWithWidget showWidget];
        }
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    self.annotInfoCommentDidChange = YES;
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    if (!   (self.session.docSettings.editingEnabled
          && self.session.docSettings.pdfAnnotationsEnabled ) )
        return NO;
    // The user has started editing the comment within the annotation popup
    // Cover the whole screen to prevent user interaction other than allowing
    // the keyboard to be dismissed with a tap
    self.annotInfoCommentDidChange = NO;
    self.coverView = [[UIView alloc] init];
    self.coverView.backgroundColor = [UIColor clearColor];
    UIView *mainView = [[UIApplication sharedApplication] keyWindow];
    [mainView addSubview:self.coverView];
    self.coverView.frame = mainView.frame;
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapOnCoverView)];
    [self.coverView addGestureRecognizer:gesture];
    return YES;
}

- (void)didTapOnCoverView
{
    [self.annotInfo.commentText resignFirstResponder];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    // The user has stopped editing the comment within the annotation popup
    // Write the updated text back to the document
    if (self.annotInfoCommentDidChange)
        self.mudoc.selectedAnnotationsText = self.annotInfo.commentText.text;

    // remove cover view.
    [self.coverView removeFromSuperview];
    self.coverView = nil;
}

- (SelectionInfo *)findSelection
{
    MuPDFDKPageView *widgetView = [self findPageViewWithWidget];
    if (widgetView)
    {
        CGPoint firstPoint = ARCGPointScale(widgetView.widgetSelectionStart, 1/widgetView.baseZoom);
        CGPoint lastPoint = ARCGPointScale(widgetView.widgetSelectionEnd, 1/widgetView.baseZoom);
        if (!CGPointEqualToPoint(firstPoint, lastPoint))
        {
            return [SelectionInfo selectionWithStart:[ARDKPagePoint point:firstPoint onPage:widgetView.pageNumber]
                                              andEnd:[ARDKPagePoint point:lastPoint onPage:widgetView.pageNumber]
                                   isWidgetSelection:YES];
        }
        else
        {
            return nil;
        }
    }
    else
    {
        __block BOOL found = NO;
        __block NSInteger startPage, endPage;
        __block CGPoint startPt, endPt;
        [self.mudoc forSelectedPages:^(NSInteger pageNo, NSArray<MuPDFDKQuad *> *quads) {
            if (quads.count > 0)
            {
                 if (!found)
                {
                    startPage = pageNo;
                    startPt = quads.firstObject.ul;
                }

                endPage = pageNo;
                endPt = quads.lastObject.lr;
                found = YES;
            }
        }];

        return  found
                    ? [SelectionInfo selectionWithStart:[ARDKPagePoint point:startPt onPage:startPage]
                                                 andEnd:[ARDKPagePoint point:endPt onPage:endPage]
                                      isWidgetSelection:NO]

                    : nil;
    }
}

- (CGRect)pageScreenArea:(NSInteger)pageNumber
{
    CGSize size = [self.doc getPage:pageNumber update:nil].size;
    CGAffineTransform trans = [self pageToScreen:pageNumber];
    return CGRectApplyAffineTransform(CGRectMake(0, 0, size.width, size.height), trans);
}

- (CGPoint)pagePointToScreen:(ARDKPagePoint *)ppt
{
    return CGPointApplyAffineTransform(ppt.pt, [self pageToScreen:ppt.pageNumber]);
}

- (void)repositionFurniture
{
    SelectionInfo *sinfo = [self findSelection];

    if (sinfo)
    {
        CGPoint screenPtStart = [self pagePointToScreen:sinfo.start];
        CGPoint screenPtEnd = [self pagePointToScreen:sinfo.end];
        if (!self.handleTopLeftIsBeingDragged)
            self.handleTopLeft.center = ARCGPointOffset(screenPtStart, -HANDLE_OFFSET, -HANDLE_OFFSET);

        if (!self.handleBottomRightIsBeingDragged)
            self.handleBottomRight.center = ARCGPointOffset(screenPtEnd, HANDLE_OFFSET, HANDLE_OFFSET);

        BOOL enableAnnotInfo = sinfo && self.mudoc.selectionIsAnnotationWithText && !sinfo.isWidgetSelection;
        if (enableAnnotInfo)
        {
            assert(sinfo.start.pageNumber == sinfo.end.pageNumber);
            CGRect annotInfoScreenRect = CGRectMake(screenPtStart.x, screenPtEnd.y, ANNOT_INFO_WIDTH, ANNOT_INFO_HEIGHT);
            CGRect pageScreenRect = [self pageScreenArea:sinfo.start.pageNumber];
            // Stop the info page hanging off the page if page size is sufficient. Pushing it on
            // from the bottom right may push it off to the top and/or left.
            CGFloat xHang = fmax(CGRectGetMaxX(annotInfoScreenRect) - CGRectGetMaxX(pageScreenRect), 0);
            CGFloat yHang = fmax(CGRectGetMaxY(annotInfoScreenRect) - CGRectGetMaxY(pageScreenRect), 0);
            annotInfoScreenRect = CGRectOffset(annotInfoScreenRect, -xHang, -yHang);
            xHang = fmax(CGRectGetMinX(pageScreenRect) - CGRectGetMinX(annotInfoScreenRect), 0);
            yHang = fmax(CGRectGetMinY(pageScreenRect) - CGRectGetMinY(annotInfoScreenRect), 0);
            annotInfoScreenRect = CGRectOffset(annotInfoScreenRect, xHang, yHang);
            self.annotInfoX.constant = annotInfoScreenRect.origin.x;
            self.annotInfoY.constant = annotInfoScreenRect.origin.y;
        }
    }
}

- (void)viewHasAltered:(BOOL)forceRender
{
    [super viewHasAltered:forceRender];
    [self repositionFurniture];
}


- (void)onSelectionChanged
{
    if ((self.annotatingMode == MuPDFDKAnnotatingMode_RedactionAreaSelect
         || self.annotatingMode == MuPDFDKAnnotatingMode_RedactionTextSelect)
        && self.mudoc.selectionIsRedaction)
    {
        // Sort of nasty trick: we want creation of redaction annotations via area selection to
        // be a one-shot operation. We spot it having been done here by noticing the mode and the
        // freshly-created annotaiton having been selected, in which case we change back to edit-
        // redaction mode. This trick saves giving each page view a reference to this document view.
        self.annotatingMode = MuPDFDKAnnotatingMode_EditRedaction;
    }

    if (self.annotatingMode == MuPDFDKAnnotatingMode_HighlightTextSelect
        && self.mudoc.selectionIsTextHighlight)
    {
        self.annotatingMode = MuPDFDKAnnotatingMode_None;
        self.selectedHighlightForAdjustment = YES;
    }

    SelectionInfo *sinfo = [self findSelection];

    BOOL enableAnnotInfo = sinfo && self.mudoc.selectionIsAnnotationWithText && !sinfo.isWidgetSelection && !self.selectedHighlightForAdjustment;
    BOOL enableHandles = sinfo && (self.mudoc.haveTextSelection
                                   || self.mudoc.selectionIsRedaction
                                   || self.mudoc.selectionIsTextHighlight
                                   || self.mudoc.selectionIsWidget
                                   || sinfo.isWidgetSelection) && !enableAnnotInfo;

    self.handleTopLeft.hidden = !enableHandles;
    self.handleBottomRight.hidden = !enableHandles;

    self.annotInfo.view.hidden = !enableAnnotInfo;

    [self repositionFurniture];

    if (enableAnnotInfo)
    {
        self.annotInfo.commentText.delegate = self;
        self.annotInfo.commentText.pasteboard = self.pasteboard;
        self.annotInfo.commentText.userInteractionEnabled = YES;
        self.annotInfo.view.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:0.0 alpha:0.75];
        self.annotInfo.commentText.text = self.mudoc.selectedAnnotationsText;
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        f.locale = [NSLocale currentLocale];
        f.dateStyle = NSDateFormatterMediumStyle;
        f.timeStyle = NSDateFormatterShortStyle;
        f.timeZone = [NSTimeZone defaultTimeZone];
        self.annotInfo.dateLabel.text = [f stringFromDate:self.mudoc.selectedAnnotationsDate];
        self.annotInfo.authorLabel.text = self.mudoc.selectedAnnotationsAuthor;

        if (self.scrollToSelection)
        {
            self.scrollToSelection = NO;
            assert(sinfo.start.pageNumber == sinfo.end.pageNumber);
            CGRect screenRect = CGRectMake(self.annotInfoX.constant, self.annotInfoY.constant, ANNOT_INFO_WIDTH, ANNOT_INFO_HEIGHT);
            CGAffineTransform screenToPage = CGAffineTransformInvert([self pageToScreen:sinfo.start.pageNumber]);
            [self showArea:CGRectApplyAffineTransform(screenRect, screenToPage) onPage:sinfo.start.pageNumber];
        }

        if (self.focusSelection)
        {
            self.focusSelection = NO;
            [self.annotInfo.commentText becomeFirstResponder];
        }
    }

    [self.delegate updateUI];
}

- (void)adjustToReducedScreenArea
{
    // If we have previously auto-scrolled to show an area of the document, the user
    // hasn't scrolled since and the keyboard restricts the screen area then auto-scroll
    // again.
    [self reshowArea];
}

- (MuPDFDKAnnotatingMode)annotatingMode
{
    return _annotatingMode;
}

- (void)setAnnotatingMode:(MuPDFDKAnnotatingMode)annotatingMode
{
    _annotatingMode = annotatingMode;
    [self iteratePages:^(NSInteger i, UIView<ARDKPageCellDelegate> *cell, CGRect screenRect) {
        MuPDFDKPageView *pageView = (MuPDFDKPageView *)cell;
        pageView.annotatingMode = annotatingMode;
    }];

    if (self.mudoc.haveAnnotationSelection
        && self.mudoc.selectionIsRedaction != (annotatingMode == MuPDFDKAnnotatingMode_EditRedaction))
    {
        self.selectedHighlightForAdjustment = NO;
        [self.mudoc clearSelection];
    }

    self.drawingMode = (annotatingMode == MuPDFDKAnnotatingMode_Draw
                        || annotatingMode == MuPDFDKAnnotatingMode_RedactionAreaSelect
                        || annotatingMode == MuPDFDKAnnotatingMode_RedactionTextSelect
                        || annotatingMode == MuPDFDKAnnotatingMode_HighlightTextSelect);
}

- (UIColor *)inkAnnotationColor
{
    return _inkAnnotationColor;
}

- (void)setInkAnnotationColor:(UIColor *)inkAnnotationColor
{
    _inkAnnotationColor = inkAnnotationColor;
    [self iteratePages:^(NSInteger i, UIView<ARDKPageCellDelegate> *cell, CGRect screenRect) {
        MuPDFDKPageView *pageView = (MuPDFDKPageView *)cell;
        pageView.inkAnnotationColor = inkAnnotationColor;
    }];
}

- (CGFloat)inkAnnotationThickness
{
    return _inkAnnotationThickness;
}

- (void)setInkAnnotationThickness:(CGFloat)inkAnnotationThickness
{
    _inkAnnotationThickness = inkAnnotationThickness;
    [self iteratePages:^(NSInteger i, UIView<ARDKPageCellDelegate> *cell, CGRect screenRect) {
        MuPDFDKPageView *pageView = (MuPDFDKPageView *)cell;
        pageView.inkAnnotationThickness = inkAnnotationThickness;
    }];
}

- (void)clearInkAnnotation
{
    [self iteratePages:^(NSInteger i, UIView<ARDKPageCellDelegate> *cell, CGRect screenRect) {
        MuPDFDKPageView *pageView = (MuPDFDKPageView *)cell;
        [pageView clearInkAnnotation];
    }];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    // Call onSelectionChanged to ensure selection handle positions are updated if needs be
    [self onSelectionChanged];
}

@end
