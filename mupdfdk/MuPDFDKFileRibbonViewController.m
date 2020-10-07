//
//  MuPDFDKFileRibbonViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 21/08/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKUIDimensions.h"
#import "ARDKRibbonItemStackedButton.h"
#import "ARDKRibbonItemSplitter.h"
#import "MuPDFDKFileRibbonViewController.h"
#import "ARDKDocTypeDetail.h"

#define VIEWCONTROLLER_BG_COLOR 0xc0c0c0
#define MENU_BUTTON_COLOR   0x000000
#define MENU_RIBBON_COLOR   0xEBEBEB

// All localized string in this file should be obtained from the sodk framework
#undef NSLocalizedString
#define NSLocalizedString(key, comment) NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:self.class], comment)

@interface MuPDFDKFileRibbonViewController () <UIDocumentInteractionControllerDelegate>
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property NSMutableArray<ARDKRibbonItem *> *buttons;
@end

@implementation MuPDFDKFileRibbonViewController

@synthesize activityIndicator, docWithUI;

+ (BOOL)hasContentForUiDelegate:(ARDKDocumentViewController<ARDKDocViewInternal> *)docWithUI
{
    return [self ribbonContentForUiDelegate:docWithUI actionTarget:nil forceNotEmpty:FALSE].count > 0;
}

+ (NSArray<ARDKRibbonItem *>*)ribbonContentForUiDelegate:(ARDKDocumentViewController<ARDKDocViewInternal> *)docWithUI actionTarget:(id)target forceNotEmpty:(BOOL)forceNotEmpty
{
    ARDKRibbonItemStackedButton *button;
    ARDKDocType docType = docWithUI.doc.docType;
    ARDKRibbonItemSplitter *splitter;
    __weak ARDKDocumentViewController<ARDKDocViewInternal> *weakUiDelegate = docWithUI;
    CGFloat width = [ARDKUIDimensions defaultRibbonButtonWidth];
    NSMutableArray<ARDKRibbonItem *> *buttons = [[NSMutableArray alloc] init];
    
    NSBundle *bundle    = [NSBundle bundleForClass:[self class]];
    UIColor  *tintColor = [UIColor colorNamed:@"so.ui.menu.ribbon.icontint" inBundle:bundle compatibleWithTraitCollection:nil];
    UIColor  *splitterColor = [UIColor colorNamed:@"lightGrey" inBundle:bundle compatibleWithTraitCollection:nil];

    if (docType == ARDKDocType_PDF)
    {
        if (docWithUI.saveToHandler)
        {
            button = [ARDKRibbonItemStackedButton itemWithText:NSLocalizedString(@"SAVE TO", @"Text displayed within button for saving the document back to an external app")
                                                     imageName:@"oem-icon-save-to" width:width target:target action:@selector(saveToButtonWasTapped:)];
            button.view.tintColor = tintColor;
            [buttons addObject:button];
        }

        if (docWithUI.session.docSettings.editingEnabled || forceNotEmpty)
        {
            button = [ARDKRibbonItemStackedButton itemWithText:NSLocalizedString(@"SAVE", @"Text displayed within button for saving the document")
                                                     imageName:@"icon-save" width:width target:target action:@selector(saveButtonWasTapped:)];
            button.enableCondition = ^BOOL ()
            {
                return (weakUiDelegate.session.documentHasBeenModified && !weakUiDelegate.session.fileState.isReadonly);
            };
            button.view.tintColor = tintColor;
            [buttons addObject:button];
        }
    }

    if (docWithUI.saveAsHandler)
    {
        button = [ARDKRibbonItemStackedButton itemWithText:NSLocalizedString(@"SAVE AS", @"Text displayed within button for saving the document to a newly named file")
                                                 imageName:@"icon-save-as" width:width target:target action:@selector(saveAsButtonWasTapped:)];
        button.view.tintColor = tintColor;
        [buttons addObject:button];
    }

    if (buttons.count > 0 && ![buttons.lastObject isKindOfClass:ARDKRibbonItemSplitter.class])
    {
        splitter = [ARDKRibbonItemSplitter item];
        splitter.view.tintColor = splitterColor;
        [buttons addObject:splitter];
    }

    if (docWithUI.printHandler)
    {
        button = [ARDKRibbonItemStackedButton itemWithText:NSLocalizedString(@"PRINT", @"Text displayed within button for printing the document")
                                                 imageName:@"icon-print" width:width target:target action:@selector(printButtonWasTapped:)];
        button.view.tintColor = tintColor;
        [buttons addObject:button];
    }

    if (docWithUI.shareHandler)
    {
        button = [ARDKRibbonItemStackedButton itemWithText:NSLocalizedString(@"SHARE", @"Text displayed within button for sharing the document")
                                                 imageName:@"icon-share" width:width target:target action:@selector(shareButtonWasTapped:)];
        button.view.tintColor = tintColor;
        [buttons addObject:button];
    }

    if (docWithUI.openInHandler)
    {
        button = [ARDKRibbonItemStackedButton itemWithText:NSLocalizedString(@"OPEN IN", @"Text displayed within button for opening the document in another app")
                                                 imageName:@"share-doc" width:width target:target action:@selector(openInButtonWasTapped:)];
        button.view.tintColor = tintColor;
        [buttons addObject:button];
    }

#if 0
    button = [ARDKRibbonItemStackedButton itemWithText:NSLocalizedString(@"PROTECT", @"Text displayed within button for adding password protection to a document")
                                             imageName:@"drm" width:width target:target action:@selector(protectButtonWasTapped:)];
    button.view.tintColor = tintColor;
    [buttons addObject:button];
#endif

    if (buttons.count > 0 && ![buttons.lastObject isKindOfClass:ARDKRibbonItemSplitter.class])
    {
        splitter = [ARDKRibbonItemSplitter item];
        splitter.view.tintColor = splitterColor;
        [buttons addObject:splitter];
    }

    if (buttons.count > 0 && [buttons.lastObject isKindOfClass:ARDKRibbonItemSplitter.class])
    {
        [buttons removeLastObject];
    }

    return buttons;
}


- (void)updateUI
{
    for (ARDKRibbonItemStackedButton *button in self.buttons)
        [button updateUI];
}

- (void)populate
{
    BOOL forceNotEmpty = NO;

    if (![self.class hasContentForUiDelegate:self.docWithUI])
    {
        /* Annoyingly, in a minimal configuration PDF files can end up
         * with an empty file ribbon. In the tablet UI this would force
         * us to default to either 'Pages' or 'Find' and make it hard to
         * exit 'Pages' mode. Instead, we force an (always disabled)
         * 'Save' button to be present in the File ribbon.
         */
        forceNotEmpty = YES;
    }
    NSArray *buttons = [self.class ribbonContentForUiDelegate:self.docWithUI actionTarget:self forceNotEmpty:forceNotEmpty];
    ARDKRibbonItem *lastItem = nil;
    assert(buttons.count > 0);

    self.buttons = [NSMutableArray array];
    for (ARDKRibbonItem *item in buttons)
    {
        if ([item isKindOfClass:ARDKRibbonItemStackedButton.class])
        {
            [self.buttons addObject:item];
        }
        else
        {
            assert([item isKindOfClass:ARDKRibbonItemSplitter.class]);
        }
        [item addToSuperView:self.scrollView nextTo:lastItem];
        lastItem = item;
    }

    [lastItem markAsLast];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self populate];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self updateUI];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.scrollView layoutIfNeeded];
    [self.docWithUI setRibbonHeight:self.scrollView.contentSize.height];
}

// For activities provoked by the UI add a delay before
// hiding the activity indicator to provide feedback to the user
- (void)hideActivityIndicatorWithDelay
{
    __weak typeof (self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf.activityIndicator hideActivityIndicator];
    });
}

- (IBAction)saveButtonWasTapped:(id)sender
{
    __weak typeof (self) weakSelf = self;
    [self.docWithUI presaveCheckFrom:self onSuccess:^{
        [weakSelf.activityIndicator showActivityIndicator];
        [weakSelf.docWithUI.session saveDocumentAndOnCompletion:^(ARDKSaveResult result, ARError err){
            [weakSelf updateUI];
            [weakSelf hideActivityIndicatorWithDelay];
            switch (result)
            {
                case ARDKSave_Succeeded:
                    break;

                case ARDKSave_Cancelled:
                case ARDKSave_Error:
                {
                    NSString *msg = NSLocalizedString(@"Saving the file failed.\nError code SO%@",
                                                      @"Message for dialog warning the user the document could not be saved");
                    msg = [NSString stringWithFormat:msg, [NSNumber numberWithInt:err]];
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"File could not be saved",
                                                                                                             @"Title for dialog warning the user the document could not be saved")
                                                                                   message:msg
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil) style:UIAlertActionStyleDefault handler:nil];
                    [alert addAction:defaultAction];
                    [weakSelf presentViewController:alert animated:YES completion:nil];
                    break;
                }
            }
        }];
    }];
}

- (NSString *)pathToTemplateFormat:(NSString *)path
{
    NSString *pathWithoutExt = [path stringByDeletingPathExtension];
    NSString *ext = [path pathExtension];
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"\\(\\d*\\)$" options:0 error:nil];
    NSRange range = [regexp rangeOfFirstMatchInString:pathWithoutExt options:0 range:NSMakeRange(0, pathWithoutExt.length)];
    return [(range.location == NSNotFound
                        ? [pathWithoutExt stringByAppendingString:@"(%d)"]
                        : [pathWithoutExt stringByReplacingCharactersInRange:range withString:@"(%d)"]) stringByAppendingPathExtension:ext];
}

- (IBAction)saveAsButtonWasTapped:(id)sender
{
    __weak typeof(self) weakSelf = self;
    [self.docWithUI presaveCheckFrom:self onSuccess:^{
        [weakSelf.docWithUI callSaveAsHandler:self];
    }];
}

- (IBAction)saveToButtonWasTapped:(id)sender
{
    __weak typeof(self) weakSelf = self;
    [self.docWithUI presaveCheckFrom:self onSuccess:^{
        [weakSelf.docWithUI callSaveToHandler:self fromButton:(UIView *)sender];
    }];
}

- (IBAction)savePDFButtonWasTapped:(id)sender
{
    [self.docWithUI callSavePdfHandler:self];
}

- (IBAction)printButtonWasTapped:(id)sender
{
    [self.docWithUI callPrintHandler:self
                           fromButton:(UIView *)sender];
}

- (IBAction)shareButtonWasTapped:(id)sender
{
    [self.activityIndicator showActivityIndicator];
    __weak typeof(self) weakSelf = self;
    [self.docWithUI.session prepareToShare:^(NSString *path, NSString *name, ARDKSaveResult result, ARError err) {
        [weakSelf.activityIndicator hideActivityIndicator];

        switch (result)
        {
            case ARDKSave_Succeeded:
                [weakSelf.docWithUI callShareHandlerPath:path filename:name fromButton:(UIView *)sender fromVC:weakSelf completion:^void()
                 {
                 }];
                break;

            case ARDKSave_Cancelled:
            case ARDKSave_Error:
            {
                NSString *msg = NSLocalizedString(@"Saving the file failed.\nError code SO%@",
                                                  @"Message for dialog warning the user the document could not be saved");
                msg = [NSString stringWithFormat:msg, [NSNumber numberWithInt:err]];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"File could not be saved",
                                                                                                         @"Title for dialog warning the user the document could not be saved")
                                                                               message:msg
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil) style:UIAlertActionStyleDefault handler:nil];
                [alert addAction:defaultAction];
                [weakSelf presentViewController:alert animated:YES completion:nil];
                break;
            }
        }

    }];
}

- (IBAction)openInButtonWasTapped:(id)sender
{
    [self.activityIndicator showActivityIndicator];
    __weak typeof(self) weakSelf = self;
    [self.docWithUI.session prepareToShare:^(NSString *path, NSString *name, ARDKSaveResult result, ARError err) {
        [weakSelf.activityIndicator hideActivityIndicator];

        switch (result)
        {
            case ARDKSave_Succeeded:
                [weakSelf.docWithUI callOpenInHandlerPath:path filename:name fromButton:(UIView *)sender fromVC:weakSelf completion:^void()
                 {
                 }];
                break;

            case ARDKSave_Cancelled:
            case ARDKSave_Error:
            {
                NSString *msg = NSLocalizedString(@"Saving the file failed.\nError code SO%@",
                                                  @"Message for dialog warning the user the document could not be saved");
                msg = [NSString stringWithFormat:msg, [NSNumber numberWithInt:err]];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"File could not be saved",
                                                                                                         @"Title for dialog warning the user the document could not be saved")
                                                                               message:msg
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil) style:UIAlertActionStyleDefault handler:nil];
                [alert addAction:defaultAction];
                [weakSelf presentViewController:alert animated:YES completion:nil];
                break;
            }
        }
    }];
}

@end
