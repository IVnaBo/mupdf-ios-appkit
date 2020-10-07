// Copyright © 2019 Artifex Software Inc. All rights reserved.

#import <Foundation/Foundation.h>

@protocol ARDKBasicDocViewDelegate <NSObject>

/// Inform the UI that both the loading of the document
/// and the initial rendering have completed. An app might
/// display a busy indicator while a document is initially
/// loading, and use this delegate method to dismiss the
/// indicator.
- (void)loadingAndFirstRenderComplete;

/// Tell the UI to update according to changes in the
/// selection state of the document. This allows an app
/// to refresh any currently displayed state information.
/// E.g., a button used to toggle whether the currently
/// selected text is bold, may show a highlight to indicate
/// bold or not. This call would be the appropriate place to
/// ensure that highlight reflects the current state.
- (void)updateUI;

/// Tell the UI that the document has scrolled to a new page.
/// An app may use this to update a label showing the current
/// displayed page number or to scroll a view of thumbnails
/// to the correct page.
- (void)viewDidScrollToPage:(NSInteger)page;

/// Tell the delegate when a scrolling animation concludes.
/// This can be used like viewDidScrollToPage, but for more
/// intensive tasks that one wouldn't want to run repeatedly
/// during scrolling.
- (void)scrollViewDidEndScrollingAnimation;

/// Offer the UI the opportunity to swallow a tap that
/// may have otherwise caused selection. Return YES
/// to swallow the event. This is not called for taps
/// over links or form fields. An app might use this to
/// provide a way out of a special mode (full-screen for
/// example). In that case, if the app is using the tap to
/// provoke exit from full-screen mode, then it would return
/// YES from this method to avoid the tap being interpreted
/// also by the main document view.
- (BOOL)swallowSelectionTap;

/// Offer the UI the opportunity to swallow a double tap that
/// may have otherwise caused selection. Return YES to swallow
/// the event. This is not called for double taps over links
/// or form fields. An app might use this in a way similar to
/// that appropriate to swallowSelectionTap.
- (BOOL)swallowSelectionDoubleTap;

/// Called to allow the delegate to inhibit the keyboard. An app
/// might use this in special modes where there is limited
/// vertical space, so as to avoid the keyboard appearing.
- (BOOL)inhibitKeyboard;

/// Called to open a url. The document view calls this when
/// a link to an external document is tapped.
- (void)callOpenUrlHandler:(NSURL *)url
                    fromVC:(UIViewController *)presentingView;

@end
