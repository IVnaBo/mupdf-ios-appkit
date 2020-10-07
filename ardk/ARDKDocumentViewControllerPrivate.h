//
//  ARDKDocumentViewControllerPrivate.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 17/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKDocumentViewController.h"
#import "ARDKUI.h"
#import "ARDKBasicDocViewDelegate.h"
#import "ARDKDocViewInternal.h"
#import "ARDKPagesViewController.h"
#import "ARDKBasicDocumentViewController.h"
#import "ARDKEditTabsViewController.h"
#import "ARDKDocErrorHandler.h"

@interface ARDKDocumentViewController () <ARDKPageSelectorDelegate,ARDKDocViewInternal,ARDKBasicDocViewDelegate,ARDKUI>
@property id<ARDKDoc> doc;
@property (weak, nonatomic) IBOutlet UIView *bottomBar;
@property (weak) ARDKEditTabsViewController *editTabsViewController;
@property UIViewController<ARDKBasicDocViewAPI> *docViewController;
@property ARDKPagesViewController *pagesViewController;
@property ARDKDocSession *docSession;
@property int openOnPage;
@property ARDKDocErrorHandler *errorHandler;

- (UIViewController<ARDKBasicDocViewAPI> *)createBasicDocumentViewForSession:(ARDKDocSession *)session;

- (void)pageArangementWillBeAltered;

- (CGFloat)amountOfTopBarAlwaysVisible;

- (BOOL)viewShouldIncludePagesView;

- (void)loadDocAndViews;

/// Set the date and time after which the document may no longer be viewed or
/// edited. promptBlock can be nil, if it is nil then it is not called and
/// the document is closed when the time expires but if promptBlock is not nil
/// then it is called instead of closing the document when the time expires
/// and closeDocBlock should be called for closing the document
- (void)setExpiresDate:(NSDate *)expiresDate
       withPromptBlock:(void (^)(UIViewController *presentVc, BOOL docHasBeenModified, void(^closeDocBlock)(void)))promptBlock;

@end
