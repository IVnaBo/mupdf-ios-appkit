//
//  ARDKDocViewInternal.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 07/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ARDKActivityIndicator.h"
#import "ARDKBasicDocViewAPI.h"

@protocol ARDKDocViewInternal <ARDKActivityIndicator>

@property(weak, readonly)ARDKDocSession *session;

@property(weak, readonly)id<ARDKDoc> doc;

@property(weak, readonly) id<ARDKBasicDocViewAPI> docView;

@property BOOL fullScreenMode;

/// Controls the appearance of the pages view
@property BOOL pagesViewIsVisible;

/// Record viewed pages
@property BOOL recordViewedPageTrack;

/// Controls hiding of the top bar menu
@property BOOL topBarMenuIsHidden;

/// Set the height of the container view that contains the ribbons
/// This is needed so as to accommodate the variation in translated
/// string length, for the text-below-icon buttons. Some need to
/// flow onto a second line which requires a greater ribbon height.
- (void)setRibbonHeight:(CGFloat)height;

/// Call the document's "Save As" handler
///
/// Called when the 'Save As' button is pressed to run the handler set
/// by the application, which the application would usually use to
/// display it's 'save as' dialogue.
- (void)callSaveAsHandler:(UIViewController *)presentingVc;

/// Call the document's "Save To" handler
///
/// Called when the 'Save To' button is pressed to run the handler set
/// by the application
- (void)callSaveToHandler:(UIViewController *)presentingVc
               fromButton:(UIView *)fromButton;

/// Call the document's "Print" handler
///
/// Called when the 'Print' button is pressed to run the handler set
/// by the application
- (void)callPrintHandler:(UIViewController *)presentingVc
              fromButton:(UIView *)fromButton;

/// Call the document's "Save as PDF" handler
///
/// Called when the 'Save PDF' button is pressed to run the handler set
/// by the application, which the application would usually use to
/// display it's 'save as' dialogue.
- (void)callSavePdfHandler:(UIViewController *)presentingVc;

/// Call the document's "Open In" handler
///
/// Called when the 'Open In' button is pressed to run the handler set
/// by the application, which the application would usually use to
/// display it's (or the system's) 'Open In' dialogue.
- (void)callOpenInHandlerPath:(NSString *)path
                     filename:(NSString *)filename
                   fromButton:(UIView *)button
                       fromVC:(UIViewController *)presentingVc
                   completion:(void (^)(void))completion;

/// Call the document's "Open PDF In" handler
///
/// Called when the 'Open PDF In' button is pressed to run the handler set
/// by the application, which the application would usually use to
/// display it's (or the system's) 'Open In' dialogue.
- (void)callOpenPdfInHandlerPath:(NSString *)path
                      fromButton:(UIView *)button
                          fromVC:(UIViewController *)presentingVc
                      completion:(void (^)(void))completion;

/// Call the document's "Share" handler
///
/// Called when the 'Share' button is pressed to run the handler set
/// by the application, which the application would usually use to
/// display it's (or the system's) 'Send'/'Email' dialogue.
- (void)callShareHandlerPath:(NSString *)path
                    filename:(NSString *)filename
                  fromButton:(UIView *)button
                      fromVC:(UIViewController *)presentingVc
                  completion:(void (^)(void))completion;

/// Call the document's "Open Url" handler
///
/// Called on tapping either an external link or a table of conatents
/// item that refers to an external link
///
/// Returns whether the request was handled
- (void)callOpenUrlHandler:(NSURL *)url
                    fromVC:(UIViewController *)presentingView;

/// Perform presave checks, calling a block conditionally on the outcome
///
/// A UIViewController is passed in case the user needs alerting
- (void)presaveCheckFrom:(UIViewController *)vc onSuccess:(void (^)(void))successBlock;


@end
