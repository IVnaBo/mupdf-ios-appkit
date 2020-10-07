//  Copyright © 2017 Artifex. All rights reserved.

#import <Foundation/Foundation.h>
#import <mupdfdk/mupdfdk.h>

/// Settings we want to apply to the document we're about to open
///
/// Only used in full document editor
///
/// These are here to allow us to have a 'Settings' UI that allows the user
/// to easily see the effect of the various settings
@interface Settings : ARDKDocumentSettings

@property (nonatomic) BOOL openUrlEnabled;

/// Whether the user is allowed to cut/copy/paste data to/from other apps
/// via the system pasteboard
@property (nonatomic) BOOL systemPasteboardEnabled;

/// Whether the 'Save As" button is available in the File Ribbon
@property (nonatomic) BOOL saveAsEnabled;

/// Whether the 'Share" button is available in the File Ribbon
@property (nonatomic) BOOL shareEnabled;

/// Whether the 'Open In" button is available in the File Ribbon
@property (nonatomic) BOOL openInEnabled;

@end
