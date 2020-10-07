// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import "ARDKPrintPageRenderer.h"
#import "ARDKDocumentViewController.h"
#import "ARDKActivityViewController.h"
#import "ARDKDefaultFileState.h"
#import "ARDKDocumentViewDefaultHandlers.h"

@interface ARDKOpenInHelper : NSObject <UIDocumentInteractionControllerDelegate>
@property (strong,nonatomic) UIDocumentInteractionController *interactionController;
@property (copy,nonatomic) void (^completion)(void);

/** True when document is being sent to another application.
 *
 * This is necessary because 'didDismiss' is called before the file has
 * finished sending, so we must ignore 'didDismiss' in that case.
 */
@property (nonatomic) BOOL sending;
@end

/** Reference to the current OpenInHelper
 *
 * UIDocumentInteractionController only keeps a weak reference to it's delegate,
 * so we need this strong reference to the OpenInHelper ensure that it says
 * alive till the UIDocumentInteractionController is done.
 */
static ARDKOpenInHelper *openInHelper;

@implementation ARDKOpenInHelper

- (void)completed
{
    assert(self.interactionController);

    self.interactionController = nil;
    openInHelper = nil;
    if (_completion)
    {
        _completion();
        _completion = nil;
    }
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller
{
    if (!self.sending)
    {
        [self completed];
    }
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application
{
    self.sending = YES;
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application
{
    [self completed];
}

@end

// All localized string in this file should be obtained from the sodk framework
#undef NSLocalizedString
#define NSLocalizedString(key, comment) NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:self], comment)

@implementation ARDKDocumentViewDefaultHandlers

+ (UIViewController *)fileNameEditor:(NSString *)fileName onComplete:(void (^)(NSString *fileName))block
{
    NSString *titleText = NSLocalizedString(@"Choose filename", @"Title of alert controller");
    NSString *okayText = NSLocalizedString(@"Okay", @"Button text");
    NSString *cancelText = NSLocalizedString(@"Comment", @"Button text");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:titleText message:nil preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text= fileName;
    }];

    UIAlertAction *okay = [UIAlertAction actionWithTitle:okayText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        block(alert.textFields[0].text);
    }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:cancelText style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:okay];
    [alert addAction:cancel];

    return alert;
}

+ (UIViewController *)fileExistsWarning:(void (^)(BOOL))block
{
    NSString *titleText = NSLocalizedString(@"File already exists", @"Title of alert controller");
    NSString *messageText = NSLocalizedString(@"Do you wish to overwrite the existing file?", @"Message of alert controller");
    NSString *okayText = NSLocalizedString(@"Overwrite", @"Button text");
    NSString *cancelText = NSLocalizedString(@"Cancel", @"Button text");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:titleText message:messageText preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *okay = [UIAlertAction actionWithTitle:okayText style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        block(YES);
    }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:cancelText style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        block(NO);
    }];

    [alert addAction:okay];
    [alert addAction:cancel];

    return alert;
}

+ (void)showError:(ARError)err from:(UIViewController *)vc
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
    [vc presentViewController:alert animated:YES completion:nil];
}

+ (void)set:(ARDKDocumentViewController *) vc;
{
    __weak typeof(vc) weakVc = vc;
    vc.saveAsHandler = ^(UIViewController *presentingVc, NSString *currentFilename, ARDKDocSession *session) {
        ARDKDefaultFileState *fileState = session.fileState;
        void (^save)(NSString *) = ^(NSString *newPath){
            fileState.docsRelativePath = newPath;
            ARDKActivityViewController *activityIndicator = [ARDKActivityViewController activityIndicatorWithin:weakVc.view];
            [session saveTo:fileState.absoluteInternalPath completion:^(ARDKSaveResult res, ARError error) {
                [activityIndicator remove];
                if (res != ARDKSave_Succeeded)
                    [ARDKDocumentViewDefaultHandlers showError:error from:presentingVc];
            }];
        };
        UIViewController *fileVc = [ARDKDocumentViewDefaultHandlers fileNameEditor:currentFilename onComplete:^(NSString *fileName) {
            NSString *newPath = [[fileState.docsRelativePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:fileName];
            if ([fileState pathExists:newPath])
            {
                UIViewController *checkVc = [ARDKDocumentViewDefaultHandlers fileExistsWarning:^(BOOL affirmed) {
                    if (affirmed)
                        save(newPath);
                }];
                [presentingVc presentViewController:checkVc animated:YES completion:nil];
            }
            else
            {
                save(newPath);
            }
        }];
        [presentingVc presentViewController:fileVc animated:YES completion:nil];
    };

    vc.printHandler = ^(UIViewController *presentingVc, UIView *fromButton, NSString *currentFilename, ARDKDocSession *session) {
        UIPrintInteractionController *printController = [UIPrintInteractionController sharedPrintController];
        ARDKPrintPageRenderer *pageRenderer = [[ARDKPrintPageRenderer alloc] initWithDocument:session.doc];
        printController.printPageRenderer = pageRenderer;
        [printController presentAnimated:YES
                       completionHandler:^(UIPrintInteractionController *pic, BOOL completed, NSError *error){
            if (error)
            {
                NSLog(@"Print failed due to error %@", error);
            }
        }];
    };

    vc.openInHandler = ^(ARDKHandlerInfo *hInfo, void (^completion)(void)) {
        NSURL *fileURL = [NSURL fileURLWithPath:hInfo.path];
        if (fileURL == nil)
            return;

        ARDKOpenInHelper *helper = [[ARDKOpenInHelper alloc] init];
        openInHelper = helper;
        helper.completion = completion;

        UIDocumentInteractionController *interactionController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
        interactionController.delegate = helper;
        helper.interactionController = interactionController;
        interactionController.name = hInfo.filename;
        [interactionController presentOpenInMenuFromRect:hInfo.button.bounds inView:hInfo.button animated:YES];
    };

    vc.shareHandler = ^(ARDKHandlerInfo *hInfo, void (^completion)(void)) {
        NSURL *fileURL = [NSURL fileURLWithPath:hInfo.path];
        if (fileURL == nil)
            return;

        NSArray *items = @[fileURL];
        UIActivityViewController *act = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
        act.modalPresentationStyle = UIModalPresentationPopover;
        act.completionWithItemsHandler =  ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
            completion();
        };
        [hInfo.presentingVc presentViewController:act animated:YES completion:nil];
        UIPopoverPresentationController *pop = act.popoverPresentationController;
        pop.sourceView = hInfo.button;
        pop.sourceRect = hInfo.button.bounds;
    };

    vc.openUrlHandler = ^(UIViewController *presentingVc, NSURL *url) {

        [[UIApplication sharedApplication] openURL:url
                                           options:[[NSDictionary alloc] init]
                                 completionHandler:nil];

    };
}

@end
