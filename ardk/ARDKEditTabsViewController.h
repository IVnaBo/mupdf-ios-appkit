//
//  ARDKEditTabsViewController.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 11/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKUI.h"
#import "ARDKSelectButton.h"
#import "ARDKContainerViewController.h"

// Class for storing the descriptions of tabs. When configuring the tab bar,
// we build a list of these objects and then run through the list creating
// the actual tabs
@interface ARDKTabDesc : NSObject
@property NSString *text;
@property SEL action;
+ (ARDKTabDesc *)tabDescText:(NSString *)text doing:(SEL)action;
@end

@interface ARDKEditTabsViewController : UIViewController<ARDKUI>
@property(weak)UIViewController *docWithUIViewContoller;
@property (weak, nonatomic) IBOutlet UIButton *undoButton;
@property (weak, nonatomic) IBOutlet UIButton *redoButton;
@property (weak, nonatomic) IBOutlet UIView *phoneMenuPopup;
@property (weak, nonatomic) IBOutlet UIButton *phoneMenuIcon;
@property ARDKContainerViewController<ARDKUI> *container;

// Requests to close document
// Completion handler is executed after process finishes
// Handler returns 'YES' if closed successfully or 'NO' if was canceled
- (void)closeDocument:(void (^)(BOOL))onCompletion;

- (void)setRibbonHeight:(CGFloat)height;

// Override in subclasses to call createTabsForTablet and createTabsForPhone
// with appropriate tab descriptor arrays
- (void)createTabs;

// Override in subclasses to react to a change of which tab is selected
- (void)selectedTabDidChange;

// Override in subclasses to clean up before closing the document
- (void)documentWillClose;

- (UIView*)createTabsForTablet:(NSArray<ARDKTabDesc *> *)tabs;
- (UIView*)createTabsForPhone:(NSArray<ARDKTabDesc *> *)tabs;

- (void)updateSelection:(NSInteger)senderTag;

- (void)selectDefaultRibbon;

@end
