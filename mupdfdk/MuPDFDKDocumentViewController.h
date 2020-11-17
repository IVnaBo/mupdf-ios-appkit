//
//  MuPDFDKDocumentViewController.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 21/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKDocumentViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface MuPDFDKDocumentViewController : ARDKDocumentViewController

/// Create a view on a document, based on its file path.
///
/// The view will delay showing any pages until the openOnPage
/// has been reached in the loading process, whereupon the
/// view will set its scroll position to that page. While
/// waiting for the page to load, a logo with an activity
/// indicator is displayed
+ (ARDKDocumentViewController *)viewControllerForFilePath:(NSString *)filePath openOnPage:(int)page;

/// Creates a view on a document, based on an open session.
///
/// The view will delay showing any pages until the openOnPage
/// has been reached in the loading process, whereupon the
/// view will set its scroll position to that page. While
/// waiting for the page to load, a logo with an activity
/// indicator is displayed
+ (ARDKDocumentViewController *)viewControllerForSession:(ARDKDocSession *)session openOnPage:(int)page;

/// Creates a view on a document, based on an open session.
///
/// Similar to viewControllerForSession:openOnPage, but
/// uses information stored in the ARDKFileState's
/// viewingStateInfo object to restore the view.
+ (ARDKDocumentViewController *)viewControllerForSessionRestoreLastViewingState:(ARDKDocSession *)session;

@end

NS_ASSUME_NONNULL_END
