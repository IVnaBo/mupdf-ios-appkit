//  Copyright © 2017-2020 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>
#import "ARDKDocSession.h"
#import "ARDKBasicDocViewAPI.h"

/// View controller for an interactive view on the document.
///
/// Instances of this class provide for a view of a document with mininal
/// UI (for features such as selection and text input) but unadorned with
/// the menus and buttons required for a full UI. Operations on the viewe
/// and the document can be performed via the ARDKBasicDocView protocol.
///
/// This is a base class, independent of any particular underlying document
/// rendering/editing engine
@interface ARDKBasicDocumentViewController : UIViewController<ARDKBasicDocViewAPI>

/// An open document session on which the view is based
@property(nonnull,readonly) ARDKDocSession *session;

/// Initializer. Takes an open document session.
- (_Nullable instancetype)initForSession:(ARDKDocSession * _Nonnull)session;

@end
