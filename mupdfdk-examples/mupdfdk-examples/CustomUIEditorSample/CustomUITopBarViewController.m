// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "CustomUITopBarViewController.h"

// This is part of the Custom-UI sample. It contains the base class
// used by the view controllers that form the hierarchical menu
// within the top bar of the app.

@interface CustomUITopBarViewController ()
@property CustomUITopBarViewController *childViewController;
@end

@implementation CustomUITopBarViewController

- (id<MuPDFDKBasicDocumentViewAPI>)docViewController
{
    return self.mainViewController.docViewController;
}

- (ARDKDocSession *)session
{
    return self.docViewController.session;
}

- (MuPDFDKDoc *)doc
{
    return (MuPDFDKDoc *)self.session.doc;
}

- (void)onIn
{
}

- (void)onOut
{
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.childViewController = nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound)
        [self onOut];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController isKindOfClass:CustomUITopBarViewController.class])
    {
        // Within the UINavigationController hierarchy, a child view controller is
        // about to replace us. Keep a reference to it, so that we can pass on updateUI
        // and barWillClose calls to it.
        self.childViewController = (CustomUITopBarViewController *)segue.destinationViewController;
        // Pass to it a reference to the main view controller.
        self.childViewController.mainViewController = self.mainViewController;
        // Tell the child that it has been opened.
        [self.childViewController onIn];
        [self.childViewController updateUI];
    }
}

- (void)updateUI
{
    // We've been told to update, but we may have been replaced by a child in
    // the menu hierarchy. If so, pass on the call.
    if (self.childViewController
        && [self.navigationController.viewControllers indexOfObject:self.childViewController] != NSNotFound)
        [self.childViewController updateUI];
}

- (void)barWillClose
{
    // We've been informed of the menu closing, but we may have been replaced
    // by a child in the menu hierarchy. If so, pass on the call.
    [self.childViewController barWillClose];
}

@end
