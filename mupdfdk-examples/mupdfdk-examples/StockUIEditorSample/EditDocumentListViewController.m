//
//  EditDocumentListViewController.m
//  smart-office-examples
//
//  Created by Joseph Heenan on 12/08/2016.
//  Copyright © 2016 Artifex. All rights reserved.
//

#import <mupdfdk/mupdfdk.h>
#import "SecureFS.h"
#import "FileState.h"
#import "Pasteboard.h"
#import "Settings.h"
#import <objc/runtime.h>

#import "EditDocumentListViewController.h"
#import "SettingsTableViewController.h"


@interface EditDocumentListViewController ()
@property (strong, nonatomic) Settings *docSettings;
@property (strong, nonatomic) MuPDFDKLib *mupdfdkLib;
@end

@implementation EditDocumentListViewController

#ifdef DEBUG
/// This code exists as test code for Artifex use, ensuring that the SDK
/// is not creating any UITextField/UITextView's that have not been secured.
///
/// It should not be copied into your own application.
static IMP __original_TFinitWithFrame_Imp;
UITextField *_replacement_TFinitWithFrame(id self, SEL _cmd, CGRect frame, NSTextContainer *textContainer)
{
    assert([self isMemberOfClass:NSClassFromString(@"ARDKTextField")]);

    return ((UITextField *(*)(id,SEL,CGRect, NSTextContainer *))__original_TFinitWithFrame_Imp)(self, _cmd, frame, textContainer);
}

static IMP __original_TFinitWithCoder_Imp;
UITextField *_replacement_TFinitWithCoder(id self, SEL _cmd, NSCoder *aDecoder)
{
    assert([self isMemberOfClass:NSClassFromString(@"ARDKTextField")]);

    return ((UITextField *(*)(id,SEL, NSCoder *))__original_TFinitWithCoder_Imp)(self, _cmd, aDecoder);
}

static IMP __original_TVinitWithFrame_Imp;
UITextView *_replacement_TVinitWithFrame(id self, SEL _cmd, CGRect frame, NSTextContainer *textContainer)
{
    assert([self isMemberOfClass:NSClassFromString(@"ARDKTextView")]);

    return ((UITextView *(*)(id,SEL,CGRect, NSTextContainer *))__original_TVinitWithFrame_Imp)(self, _cmd, frame, textContainer);
}

static IMP __original_TVinitWithCoder_Imp;
UITextView *_replacement_TVinitWithCoder(id self, SEL _cmd, NSCoder *aDecoder)
{
    assert([self isMemberOfClass:NSClassFromString(@"ARDKTextView")]);

    return ((UITextView *(*)(id,SEL, NSCoder *))__original_TVinitWithCoder_Imp)(self, _cmd, aDecoder);
}



+ (void)load
{
    Method m;

    m = class_getInstanceMethod([UITextField class],
                                @selector(initWithFrame:textContainer:));
    __original_TFinitWithFrame_Imp = method_setImplementation(m,
                                                            (IMP)_replacement_TFinitWithFrame);

    m = class_getInstanceMethod([UITextField class],
                                @selector(initWithCoder:));
    __original_TFinitWithCoder_Imp = method_setImplementation(m,
                                                            (IMP)_replacement_TFinitWithCoder);

    m = class_getInstanceMethod([UITextView class],
                                @selector(initWithFrame:textContainer:));
    __original_TVinitWithFrame_Imp = method_setImplementation(m,
                                                              (IMP)_replacement_TVinitWithFrame);

    m = class_getInstanceMethod([UITextView class],
                                @selector(initWithCoder:));
    __original_TVinitWithCoder_Imp = method_setImplementation(m,
                                                              (IMP)_replacement_TVinitWithCoder);

}

#endif /* DEBUG */

- (void)commonInit
{
    // A normal app would just setup SODKDocumentSettings (and the related
    // handler blocks) based on your data leakage prevention rules.
    // For the purposes of this sample, we default to enabling everything,
    // but provide a UI you can easily see the effect of different settings.
    _docSettings = [[Settings alloc] init];
    [_docSettings enableAll:YES];
    
    // To set features individually, use setter functions explicitly,
    // rather than [_docSettings enableAll:YES], for example:
    //    [_docSettings setTrackChangesFeatureEnabled:YES];
    //    [_docSettings setShareEnabled:YES];
    //    [_docSettings setSavePdfEnabled:NO];
    // etc..
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
        [self commonInit];
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
        [self commonInit];
    return self;
}

- (void)showMessage:(NSString *)msg withTitle:(NSString *)title fromVC:(UIViewController *)vc completion:(void (^ __nullable)(void))completion
{
    UIAlertController *alert;

    alert = [UIAlertController alertControllerWithTitle:title
                                                message:msg
                                         preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *alertAction = [UIAlertAction
                                  actionWithTitle:@"Dismiss"
                                  style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction *action) {
                                      if ( completion )
                                          completion();
                                  }];

    [alert addAction:alertAction];

    [vc presentViewController:alert animated:YES completion:nil];
}

- (UIAlertController *)alertControllerGetFilename:(NSString *)filename action: (void (^)(NSString *filename))saveAction
{
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:@"New filename"
                                message:@"Please enter the new filename"
                                preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(alert) weakAlert = alert;

    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action)
                         {
                             saveAction(weakAlert.textFields[0].text);
                         }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction * action)
                             {
                             }];

    [alert addAction:ok];
    [alert addAction:cancel];
    if ([alert respondsToSelector:@selector(setPreferredAction:)])
    {
        /* only available >= iOS 9 */
        alert.preferredAction = ok;
    }

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Filename";
        textField.text = filename;
    }];

    return alert;
}

/**
 * Setup various handlers for the MuPDF app
 *
 * If a handler does not make any sense if your application, you may leave
 * the handler unset and MuPDF will not show the corresponding icon.
 */
- (void)setHandlers:(ARDKDocumentViewController *)docVc;
{
    __weak typeof (self) weakSelf = self;

    if (_docSettings.saveAsEnabled)
    {
        docVc.saveAsHandler = ^(UIViewController *presentingVc, NSString *filename, ARDKDocSession *session)
        {
            // Create a save as dialog
            // This is very basic; you may want to allow the user a choice of
            // folders, or check that the new filename won't overwrite an existing
            // file, showing activity indicators during save process, etc.
            __weak typeof (session) weakSession = session;
            UIAlertController *alert = [weakSelf alertControllerGetFilename:filename action:^(NSString *filename) {
                // Update the file state to reflect the new location of the file
                FileState *fileState = weakSession.fileState;
                [fileState setPath:filename];
                // Save the document to the new location
                [weakSession saveTo:fileState.absoluteInternalPath completion:^(ARDKSaveResult res, SOError err) {
                    if (res != ARDKSave_Succeeded)
                    {
                        NSLog(@"Saving document failed: %d", err);
                        [weakSelf showMessage:@"Saving document failed" withTitle:@"Unable to save document" fromVC:presentingVc completion:nil];
                    }
                }];
            }];
            [presentingVc presentViewController:alert animated:YES completion:nil];
        };
    }

    if (_docSettings.openInEnabled)
    {
        docVc.openInHandler = ^(ARDKHandlerInfo *hInfo, void (^completion)(void))
        {
            /* Here you could pass the file to a 'secure' OpenIn handler if
             * desired. Note that if SecureFS is being used, the path here will be
             * within SecureFS and hence cannot be directly used with the OS's built
             * in 'Open In' functionality. */
            [weakSelf showMessage:@"User pressed 'Open In' button" withTitle:nil fromVC:hInfo.presentingVc completion:nil];
            NSLog(@"File to share is: %@ (filename %@)", hInfo.path, hInfo.filename);
            completion();
        };
    }

    if (_docSettings.shareEnabled)
    {
        docVc.shareHandler = ^(ARDKHandlerInfo *hInfo, void (^completion)(void))
        {
            [weakSelf showMessage:@"User pressed 'Share' button" withTitle:nil fromVC:hInfo.presentingVc completion:nil];
            NSLog(@"File to share is: %@ (filename %@)", hInfo.path, hInfo.filename);
            completion();
        };
    }

    if (_docSettings.openUrlEnabled)
    {
        docVc.openUrlHandler = ^(UIViewController *presentingVc, NSURL *url)
        {
            NSString *msg = [NSString stringWithFormat:@"User tapped URL:%@", url.absoluteString];
            [weakSelf showMessage:msg withTitle:nil fromVC:presentingVc completion:nil];
        };
    }
}


- (void)documentSelected:(NSString *)documentPath
{
    /* In a normal application, MuPDFDKLib would be retained and reused multiple
     * times, only being released if a low memory notification is received
     * whilst no documents are loaded.
     * Note that only one MuPDFDKLib instance can exist at any one time.
     */
    if (!self.mupdfdkLib)
    {
        ARDKSettings *settings = [[ARDKSettings alloc] init];
        settings.temporaryPath = [SecureFS temporaryPath];
        settings.secureFs = [[SecureFS alloc] init];
        self.mupdfdkLib = [[MuPDFDKLib alloc] initWithSettings:settings];
    }
    assert(_docSettings);
    FileState *fileState = [FileState fileStateForPath:documentPath];
    ARDKDocSession *docSession = [ARDKDocSession sessionForFileState:fileState ardkLib:self.mupdfdkLib docSettings:_docSettings];
    ARDKDocumentViewController *vc = [MuPDFDKDocumentViewController viewControllerForSession:docSession openOnPage:0];

    if (!vc)
    {
        [self showMessage:@"Unsupported filetype" withTitle:nil fromVC:self completion:nil];
        return;
    }

#if 0 /* Example about custom error handle */
    /**
     * Set the custom errorBlock, it wll be called instead of the MuPDFDK default
     * errorBlock when an error occurs.
     * Note that the error message strings are localized in the MuPDFDK default
     * errorBlock.
     */
    [docSession setErrorBlock:^(ARDKDocErrorType error){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handlerError:error];
        });
    } withDocumentViewController:vc];
#endif

    [self setHandlers:vc];
    if (_docSettings.systemPasteboardEnabled)
        vc.pasteboard = [[Pasteboard alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"settings"])
    {
        SettingsTableViewController *stvc = (SettingsTableViewController *)segue.destinationViewController;

        stvc.settings = _docSettings;
    }
}

/// Triggered by the user pressing the 'back' button in the smartoffice UI.
///
/// The implementation can be left empty, but this function MUST be present
/// in the view controller that should be unwound back to - otherwise nothing
/// will happen when the user clicks the back button.
- (IBAction)sodk_unwindAction:(UIStoryboardSegue *)sender
{
}

- (void)dismiss
{
    // Back to the previous view controller
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Error Handler

- (void)handlerError:(ARDKDocErrorType)error
{
    NSString *msg = nil;
    
    switch ( error )
    {
        case ARDKDocErrorType_NoError:
            assert("ARDKDocErrorType_NoError should never be reported" == NULL);
            msg = @"No error";
            break;
            
        case ARDKDocErrorType_UnsupportedDocumentType:
            msg = @"Unsupported document type";
            break;
            
        case ARDKDocErrorType_EmptyDocument:
            msg = @"Document is empty";
            break;
            
        case ARDKDocErrorType_UnsupportedEncryption:
            msg = @"Document uses unsupported encryption";
            break;
            
        case ARDKDocErrorType_Aborted:
            /* nothing necessary here, presumably it was the user that aborted it */
            break;
            
        case ARDKDocErrorType_OutOfMemory:
            msg = @"Document is too large";
            break;
            
        case ARDKDocErrorType_UnableToLoadDocument:
        default:
            msg = @"Document could not be loaded";
            break;
    }
    
    if ( msg )
    {
        NSLog(@"Error loading document: %d [%@]", error, msg);
        [self showMessage:msg withTitle:@"Unable to load document" fromVC:self completion:^(){
            [self dismiss];
        }];
    }
    else
    {
        NSLog(@"Error loading document: %d", error);
        [self dismiss];
    }
}

@end
