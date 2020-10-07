// Copyright © 2019 Paul Gardiner. All rights reserved.

#import <mupdfdk/mupdfdk.h>
#import "CustomUIDocumentViewController.h"
#import "CustomUITopBarViewController.h"
#import "CustomUITOCViewController.h"


// This is part of the Custom-UI sample. It is the main view, containing
// the document view and the UI views.
//
// Navigation controllers are used at two levels. Firstly, there is an
// assumption that this view controller is embedded within a navigation
// controller, so we can refer to the navigation bar and place the
// document's name on it, plus some action buttons. Secondly, we use
// another set of view controllers embedded within a navigation
// controller to provide a second bar, just below the other, which acts
// as a hierarchical menu system. These menu view controllers have height
// matching the navigation bar height, so that is all you see of them.
// This style is not a necessary part of using this SDK. It's just an
// example of how UI can be implemented.
//
// Communication is needed to and from this main view controller and the
// ones that implement the menu system. See the class
// CustonUITopBarViewController for an understanding of how this
// communication is achieved. That class is the base class of all the
// menu view controllers.


// We implement three protocols
//
// ARDKBasicDocViewDelegate - this allows the document view to inform us
//                            of events and request information, regarding
//                            scrolling, user taps, etc.
//
// ARDKDocumentEventTarget - this allows the document itself to inform us
//                           of events, regarding for example: the loading
//                           of the document and selection changes.
//
// CustomUIMainViewControllerAPI - this allows other UI items to communicate
//                                 with this main class. The interface is
//                                 spefific to this specific sample. The details
//                                 of this interface and the fact of using such
//                                 an interface at all is specific to this sample
//                                 app. It is defined in CustomUITopBarViewController.h
//
@interface CustomUIDocumentViewController () <ARDKBasicDocViewDelegate,ARDKDocumentEventTarget,CustomUIMainViewControllerAPI>

@property NSString *path;
@property UIViewController<MuPDFDKBasicDocumentViewAPI> *docViewController;
@property (weak, nonatomic) IBOutlet UIView *documentArea;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *menuVisible;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *tocButton;
@property NSInteger pageCount;
@property NSInteger currentPage;
@property CustomUITopBarViewController *topBar;
@end

@implementation CustomUIDocumentViewController

+ (instancetype)viewControllerForPath:(NSString *)path
{
    UIStoryboard *sb =[UIStoryboard storyboardWithName:@"CustomUI" bundle:[NSBundle bundleForClass:self.class]];
    CustomUIDocumentViewController *vc = [sb instantiateInitialViewController];
    vc.path = path;
    return vc;
}

- (ARDKDocSession *)session
{
    return self.docViewController.session;
}

- (MuPDFDKDoc *)doc
{
    return (MuPDFDKDoc *)self.session.doc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.docViewController = [MuPDFDKBasicDocumentViewController viewControllerForPath:self.path];
    self.docViewController.delegate = self;
    [self.docViewController.session.doc addTarget:self];
    [self addChildViewController:self.docViewController];
    CGRect frame = {CGPointZero, self.documentArea.frame.size};
    self.docViewController.view.frame = frame;
    [self.documentArea addSubview:self.docViewController.view];
    [self.docViewController didMoveToParentViewController:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"embedTopBar"])
    {
        // Give the root of top-bar menu view controllers a reference to this main view controller
        self.topBar = (CustomUITopBarViewController *)segue.destinationViewController.childViewControllers[0];
        self.topBar.mainViewController = self;
    }
    else if ([segue.identifier isEqualToString:@"showTOC"])
    {
        ((CustomUITOCViewController *)segue.destinationViewController).docView = self.docViewController;
    }
}

- (IBAction)backWasTapped:(id)sender
{
    // Dismissing the menu will complete any in-process user actions
    [self dismissMenu];

    if (self.session.documentHasBeenModified)
    {
        UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"The document has been changed" message:@"Would you like to save the changes, discard them, or carry on editing" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self.session saveDocumentAndOnCompletion:^(ARDKSaveResult res, ARError err) {
                [self.navigationController popViewControllerAnimated:YES];
            }];
        }];
        UIAlertAction *discardAction = [UIAlertAction actionWithTitle:@"Discard" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self.navigationController popViewControllerAnimated:YES];
        }];
        UIAlertAction *carryOnAction = [UIAlertAction actionWithTitle:@"Carry on" style:UIAlertActionStyleCancel handler:nil];
        [alertVc addAction:saveAction];
        [alertVc addAction:discardAction];
        [alertVc addAction:carryOnAction];
        [self presentViewController:alertVc animated:YES completion:nil];
    }
    else
    {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)updateTitle
{
    self.navigationItem.title = [NSString stringWithFormat:@"%@ (%ld of %ld)",
                                 self.session.fileState.displayPath.lastPathComponent,
                                 self.currentPage + 1,
                                 self.pageCount];
}

- (IBAction)menuWasTapped:(id)sender
{
    [UIView animateWithDuration:0.3 animations:^{
        self.menuVisible.active = YES;
        [self.view layoutIfNeeded];
    }];
}


// CustomUIViewControllerAPI methods

- (void)dismissMenu
{
    [self.topBar barWillClose];
    [self.topBar.navigationController popToRootViewControllerAnimated:YES];

    [UIView animateWithDuration:0.3 animations:^{
        self.menuVisible.active = NO;
        [self.view layoutIfNeeded];
    }];
}


#pragma mark ARDKBasicDocViewDelegate methods

/// Inform the UI that both the loading of the document
/// and the initial rendering have completed. An app might
/// display a busy indicator while a document is initially
/// loading, and use this delegate method to dismiss the
/// indicator.
- (void)loadingAndFirstRenderComplete
{
}

/// Tell the UI to update according to changes in the
/// selection state of the document. This allows an app
/// to refresh any currently displayed state information.
/// E.g., a button used to toggle whether the currently
/// selected text is bold, may show a highlight to indicate
/// bold or not. This call would be the appropriate place to
/// ensure that highlight reflects the current state.
- (void)updateUI
{
    [self.topBar updateUI];
    self.tocButton.enabled = self.doc.toc.count > 0;
}

/// Tell the UI that the document has scrolled to a new page.
/// An app may use this to update a label showing the current
/// displayed page number or to scroll a view of thumbnails
/// to the correct page.
- (void)viewDidScrollToPage:(NSInteger)page
{
    self.currentPage = page;
    [self updateTitle];
}

/// Tell the delegate when a scrolling animation concludes.
/// This can be used like viewDidScrollToPage, but for more
/// intensive tasks that one wouldn't want to run repeatedly
/// during scrolling.
- (void)scrollViewDidEndScrollingAnimation
{
}

/// Offer the UI the opportunity to swallow a tap that
/// may have otherwise caused selection. Return YES
/// to swallow the event. This is not called for taps
/// over links or form fields. An app might use this to
/// provide a way out of a special mode (full-screen for
/// example). In that case, if the app is using the tap to
/// provoke exit from full-screen mode, then it would return
/// YES from this method to avoid the tap being interpreted
/// also by the main document view.
- (BOOL)swallowSelectionDoubleTap
{
    return NO;
}

/// Offer the UI the opportunity to swallow a double tap that
/// may have otherwise caused selection. Return YES to swallow
/// the event. This is not called for double taps over links
/// or form fields. An app might use this in a way similar to
/// that appropriate to swallowSelectionTap.
- (BOOL)swallowSelectionTap
{
    return NO;
}

/// Called to allow the delegate to inhibit the keyboard. An app
/// might use this in special modes where there is limited
/// vertical space, so as to avoid the keyboard appearing.
- (BOOL)inhibitKeyboard
{
    return NO;
}

/// Called to open a url. The document view calls this when
/// a link to an external document is tapped.
- (void)callOpenUrlHandler:(NSURL *)url fromVC:(UIViewController *)presentingView
{
}


#pragma mark ARDKDocumentEventTarget methods

/// Called as pages are loaded from the document. complete will be YES if when
/// there are no more pages to load. There may be further calls, e.g., if pages
/// are added or deleted from the document.
- (void)updatePageCount:(NSInteger)pageCount andLoadingComplete:(BOOL)complete
{
    self.pageCount = pageCount;
    [self updateTitle];
}

/// Called when pages have altered in size. This is not currently called by MuPDF
- (void)pageSizeHasChanged
{
}

/// Called when a selection is made within the document, moved or removed. An
/// app will likely on need react to this method. It is applicable to other
/// internal uses of the ARDKDocumentEventTarget protocol.
- (void)selectionHasChanged
{
}

/// Called each time a document layout operation completes. This is not currently
/// called by MuPDF.
- (void)layoutHasCompleted
{
}

@end
