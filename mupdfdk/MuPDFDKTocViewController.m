//
//  MuPDFDKTocViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 17/03/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "MuPDFDKTocCell.h"
#import "MuPDFDKTocViewController.h"

@interface MuPDFDKTocViewController () <UITableViewDataSource>
@property NSMutableArray<id<ARDKTocEntry>> *toc;
@property (weak, nonatomic) IBOutlet UIButton *closeButton;
@property BOOL presentedAsPopover;
@end

@implementation MuPDFDKTocViewController
{
    CGFloat _viewWidth;
}

@synthesize activityIndicator, docWithUI;

- (void)updateUI
{
}

- (void)addEntries:(NSArray<id<ARDKTocEntry>> *)entries
{
    for (id<ARDKTocEntry> entry in entries)
    {
        [self.toc addObject:entry];
        if (entry.children)
            [self addEntries:entry.children];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.toc = [NSMutableArray array];
    [self addEntries:self.docWithUI.doc.toc];
}

- (IBAction)closeButtonWasTapped:(id)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    _viewWidth = self.view.frame.size.width;
    // We don't need a close button when presenting as a popover
    if (self.presentedAsPopover)
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.closeButton removeFromSuperview];
        });
}

- (void)prepareForPopoverPresentation:(UIPopoverPresentationController *)popoverPresentationController
{
    self.presentedAsPopover = YES;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if ( @available(iOS 13.0, *) )
    {
        BOOL hasUserInterfaceStyleChanged = [previousTraitCollection hasDifferentColorAppearanceComparedToTraitCollection:self.traitCollection];
        
        if ( hasUserInterfaceStyleChanged )
        {
            if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
            {
                if ( self.closeButton.enabled && !self.closeButton.hidden )
                {
                    /* If the system appearance is changed then the close button
                     * can be installed and shown on iPad. So, hide the close button.
                     */
                    self.closeButton.hidden = YES;
                }
            }
        }
    }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 */
}

#pragma mark - UITableViewDelegate

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    id<ARDKTocEntry> entry = self.toc[indexPath.item];
    MuPDFDKTocCell *cell = (MuPDFDKTocCell *)[tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.label = entry.label;
    cell.depth = entry.depth;

    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.toc.count;
}

- (void)tableView:(nonnull UITableView *)tableView didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    id<ARDKTocEntry> entry = self.toc[indexPath.item];

    // Handle the link
    [entry handleCaseInternal:^(NSInteger page, CGRect box) {
        [self.docWithUI.docView pushViewingState:page withOffset:box.origin];
        [self.docWithUI.docView showPage:page withOffset:box.origin];
    } orCaseExternal:^(NSURL *url) {
        if (self.docWithUI.openUrlHandler)
        {
            [self.docWithUI callOpenUrlHandler:url fromVC:self];
        }
    }];

    // If not presented as a popover then this view controlled is
    // full screen and needs to be dismissed on each item selection.
    if (!self.presentedAsPopover)
    {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
