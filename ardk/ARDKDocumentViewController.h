//
//  ARDKDocumentViewController.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 16/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKDocSession.h"
#import "ARDKHandlerInfo.h"
#import "ARDKDocumentSettings.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARDKDocumentViewController : UIViewController


/// Type for block called when 'save as' process is initiated
///
/// This could be the user pressing the 'Save As' button, or attempting to
/// close a newly created document.
///
/// When the new path is known, the document should be saved via the SOSaveDoc interface
///
/// @param presentingVc    View controller to call presentViewController on (if necessary)
/// @param currentFilename Document's current filename, for use as an initial value
/// @param session         The session requesting the save
typedef void (^ARSaveAsHandler)(UIViewController * _Nonnull presentingVc,
                                NSString *currentFilename,
                                ARDKDocSession *session);

/// Type for block called when 'save to' process is initiated
///
/// This could be the user pressing the 'Save To' button, or attempting to
/// close a modified document if no "Save As' handler has been defined
///
/// @param presentingVc    View controller to call presentViewController on (if necessary)
/// @param fromButton      The button pressed to call this handler
/// @param currentFilename Document's current filename, for use as an initial value
/// @param session         The session requesting the save
typedef void (^ARSaveToHandler)(UIViewController *presentingVc,
                                UIView *fromButton,
                                NSString *currentFilename,
                                ARDKDocSession *session);

/// Type for block called when 'print' process is initiated
///
/// This could be the user pressing the 'Print' button, or attempting to
/// close a modified document if no "Print' handler has been defined
///
/// @param presentingVc    View controller to call presentViewController on (if necessary)
/// @param fromButton      The button pressed to call this handler
/// @param currentFilename Document's current filename, for use as an initial value
/// @param session         The session requesting the print
typedef void (^ARPrintHandler)(UIViewController *presentingVc,
                               UIView *fromButton,
                               NSString *currentFilename,
                               ARDKDocSession *session);

/// Type for block called when various user interactions are started
///
/// For example, the user presses the 'Open In' button.
///
/// @param hInfo      Information to allow the handler to run
/// @param completion Block that must be called once the action has be completed
///                   (both on success and on failure)
typedef void (^ARButtonHandler)(ARDKHandlerInfo *hInfo, void (^completion)(void));

/// Type for block called when 'save as pdf' process is initiated
///
/// When the new path is known, the PDF should be exported via the SOSaveDoc interface
///
/// @param presentingVc    View controller to call presentViewController on (if necessary)
/// @param currentFilename Document's current filename, for use to form the initial value
typedef void (^ARSavePdfHandler)(UIViewController *presentingVc,
                                 NSString *currentFilename,
                                 ARDKDocSession *session);

/// Type for block called when user taps an external hyperlink in a document
///
/// See the openUrlHandler property.
typedef void (^AROpenURLHandler)(UIViewController *presentingVc, NSURL *url);

/// Block called when a 'save as' process is required
@property (nullable, copy, nonatomic)ARSaveAsHandler saveAsHandler;

/// Block called when a 'save to' process is required
@property (nullable, copy, nonatomic)ARSaveToHandler saveToHandler;

/// Block called when a 'print' process is required
@property (nullable, copy, nonatomic)ARPrintHandler printHandler;

/// Block called when the 'save as pdf' button is pressed
@property (nullable, copy, nonatomic)ARSavePdfHandler savePdfHandler;

/// Block called when 'Open In' process is initiated
///
/// The caller should offer the user a way to pass the document to another
/// app, applying any applicable security policies.
///
/// If the handler is nil (the default), the 'Open In' button will not be
/// present in the UI.
@property (nullable, copy, nonatomic)ARButtonHandler openInHandler;

/// Block called when 'Share' process is initiated
///
/// The caller should offer the user a way to email/send the document,
/// applying any applicable security policies.
///
/// If the handler is nil (the default), the 'Share' button will not be
/// present in the UI.
@property (nullable, copy, nonatomic)ARButtonHandler shareHandler;

/// Block called when 'Open PDF In' process is initiated
///
/// The caller should offer the user a way to pass the PDF to another
/// app (or email it), applying any applicable security policies.
///
/// If the handler is nil (the default), the 'Open PDF In' button will not be
/// present in the UI.
@property (nullable, copy, nonatomic)ARButtonHandler openPdfInHandler;

/// Handler called when user taps an external link in a document
///
/// For example, a Word document can contain a link to a website.
///
/// The application could pass the URL to the OS, or an internal browser,
/// depending on the security requirements of the app.
///
/// If left unset, nothing will happen when links are tapped.
@property (nullable, copy, nonatomic)AROpenURLHandler openUrlHandler;

/// Pasteboard for the document editor to use
///
/// This is used to prevent data leakage to the OS via the clipboard.
///
/// The app should provide a pasteboard implementation that behaves as it
/// likes (for example, keeping the text internal to the app).
///
/// The default is a clipboard that only allows pasting within the document.
@property (nullable, strong, nonatomic)id<ARDKPasteboard> pasteboard;

@property(readonly) BOOL documentHasBeenModified;

/// Top bar.
///
/// View container controlled by the storyboard.
@property (weak, nonatomic) IBOutlet UIView *topBar;

/// The document file type
@property (readonly) ARDKDocType docType;

// Requests to close document
// Completion handler is executed after process finishes
// Handler returns 'YES' if closed successfully or 'NO' if was canceled
- (void)closeDocument:(void (^)(BOOL))onCompletion;

@end

NS_ASSUME_NONNULL_END
