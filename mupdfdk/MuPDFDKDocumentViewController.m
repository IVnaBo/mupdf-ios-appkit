//
//  MuPDFDKDocumentViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 21/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKDefaultFileState.h"
#import "ARDKViewingState.h"
#import "ARDKInternalPasteboard.h"
#import "ARDKDocumentViewDefaultHandlers.h"
#import "ARDKDocumentViewControllerPrivate.h"
#import "ARDKBasicDocViewDelegate.h"
#import "MuPDFDKDocViewInternal.h"
#import "MuPDFDKBasicDocumentViewController.h"
#import "MuPDFDKDocumentViewController.h"

@interface MuPDFDKDocumentViewController () <MuPDFDKDocViewInternal, ARDKBasicDocViewDelegate>
@end

@implementation MuPDFDKDocumentViewController

@synthesize session = _session, docView = _docView;

+ (ARDKDocumentViewController *)viewControllerForFilePath:(NSString *)filePath openOnPage:(int)page
{
    MuPDFDKLib *lib = [[MuPDFDKLib alloc] initWithSettings:nil];
    ARDKDefaultFileState *fileState = [ARDKDefaultFileState fileStateForPath:filePath ofType:[MuPDFDKDoc docTypeFromFileExtension:filePath]];
    ARDKDocumentSettings *settings = [[ARDKDocumentSettings alloc] init];
    [settings enableAll:YES];
    ARDKDocSession *session = [ARDKDocSession sessionForFileState:fileState ardkLib:lib docSettings:settings];
    ARDKDocumentViewController *vc = [MuPDFDKDocumentViewController viewControllerForSession:session openOnPage:page];
    [ARDKDocumentViewDefaultHandlers set:vc];
    return vc;
}

+ (ARDKDocumentViewController *)viewControllerForSession:(ARDKDocSession *)docSession openOnPage:(int)page
{
    ARDKViewingStateStack *vstate = [ARDKViewingStateStack viewingStateStack];
    vstate.viewingState = [ARDKViewingState stateWithPage:page offset:CGPointZero scale:1.0];
    docSession.fileState.viewingStateInfo = vstate;
    return [MuPDFDKDocumentViewController viewControllerForSessionRestoreLastViewingState:docSession];
}

+ (ARDKDocumentViewController *)viewControllerForSessionRestoreLastViewingState:(ARDKDocSession *)docSession
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"mupdf" bundle:[NSBundle bundleForClass:self.class]];
    ARDKDocumentViewController *vc = [sb instantiateInitialViewController];
    vc.docSession = docSession;
    vc.doc = docSession.doc;
    [vc loadDocAndViews];

    // Create a default pasteboard; most apps will replace this
    vc.pasteboard = [[ARDKInternalPasteboard alloc] init];

    return vc;
}

- (UIViewController<ARDKBasicDocViewAPI> *)createBasicDocumentViewForSession:(ARDKDocSession *)session
{
    UIViewController<MuPDFDKBasicDocumentViewAPI> *basicDocView = [MuPDFDKBasicDocumentViewController viewControllerForSession:session];
    basicDocView.delegate = self;
    _session = session;
    _docView = basicDocView;
    self.docWithUI = self;

    if (session.docSettings.pdfFormFillingEnabled)
        self.doc.pdfFormFillingEnabled = YES;
    if (session.docSettings.pdfFormSigningEnabled)
        self.doc.pdfFormSigningEnabled = YES;

    return basicDocView;
}

- (MuPDFDKDoc *)doc
{
    return (MuPDFDKDoc *)self.session.doc;
}

- (void)presaveCheckFrom:(UIViewController *)vc onSuccess:(void (^)(void))successBlock
{
    [super presaveCheckFrom:vc onSuccess:^{
        if (((MuPDFDKDoc *)self.doc).hasRedactions)
        {
            NSString *msg = NSLocalizedString(@"This document contains redaction marks that have not yet been applied. Any content associated with these marks will still be present until they are applied. Are you sure you want to continue?",
                                              @"Warning message about redactions being marked but not applied");
            NSString *continueLabel = NSLocalizedString(@"Continue", @"Button label");
            NSString *cancelLabel = NSLocalizedString(@"Cancel", @"Button label");
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *continueAction = [UIAlertAction actionWithTitle:continueLabel style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                successBlock();
            }];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelLabel style:UIAlertActionStyleCancel handler:nil];
            [alert addAction:continueAction];
            [alert addAction:cancelAction];
            [vc presentViewController:alert animated:YES completion:nil];
        }
        else
        {
            successBlock();
        }
    }];
}

@end
