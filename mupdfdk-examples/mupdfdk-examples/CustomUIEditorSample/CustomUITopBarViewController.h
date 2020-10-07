// Copyright © 2019 Paul Gardiner. All rights reserved.

#import <UIKit/UIKit.h>
#import <mupdfdk/mupdfdk.h>

// This is part of the Custom-UI sample. It contains the base class
// used by the view controllers that form the hierarchical menu
// within the top bar of the app and the protocol via which those
// classes comminicate to the main view controller. This structuring
// isn't a nessary part of using this SDK. It is just a specific
// mechanism we have chosen. It may be useful to copy to some degree
// since most apps will distribute the UI across several classes and
// need a way for them to communicate.

// The CustomUIMainViewControllerAPI prototcol contains the methods
// and properties via which the menu view controllers access details
// of the main view, in particular the document view itself
//
@protocol CustomUIMainViewControllerAPI <NSObject>
@property(readonly) id<MuPDFDKBasicDocumentViewAPI> docViewController;

- (void)dismissMenu;
@end

// The CustomUITopBarViewController class is the base class for
// each of the view controllers used in the top bar menu. The main
// view passes itself to the root of these view controllers by setting
// the mainViewController property, the root passes it on to its
// children and they pass it on to theirs.
//
// The main view controller will also call updateUI on any state
// change that may require changes in the UI, and will call
// barWillClose just before the document is closed. Again these
// calls pass down the menu hierarchy.
//
// docViewController, session and doc, are just convenience properties
// for accessing objects within the stucture of mainViewController.
//
@interface CustomUITopBarViewController : UIViewController
@property UIViewController<CustomUIMainViewControllerAPI> *mainViewController;
// docViewController: the view on the open document, and can be used
// to control and detect the user's interaction with the view. e.g.,
// request an area of a specific page be displayed.
@property(readonly) id<MuPDFDKBasicDocumentViewAPI> docViewController;
// session: auxiliary properties of the open document, such as its
// name, file path, change status.
@property(readonly) ARDKDocSession *session;
// The open document itself. All interrogation of and operations on the
// document are possible via this object, although the most common are
// performed internally to the document view and don't require explcit
// calling from the app.
@property(readonly) MuPDFDKDoc *doc;

// Overridable, called after each document or document view state
// change that may require a corresponding change in the UI
- (void)updateUI;


// Overridable, called when the menu is about to be close, so that
// in-progress user operations can be completed.
- (void)barWillClose;

// Override called when the menu opens (and not on return from a child menu)
- (void)onIn;

// Override called when the menu closes (and not when moving to a child menu)
- (void)onOut;

@end
