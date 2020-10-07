//
//  ARDKDocErrorHandler.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 02/05/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "ARDKDocErrorHandler.h"

// All localized string in this file should be obtained from the sodk framework
#undef NSLocalizedString
#define NSLocalizedString(key, comment) NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:self.class], comment)

@interface ARDKDocErrorHandler ()
@property(weak) UIViewController *vc;
@property(weak) id<ARDKDoc> doc;
@end

@implementation ARDKDocErrorHandler


- (instancetype)initForViewController:(UIViewController *)vc showingDoc:(id<ARDKDoc>)doc
{
    self = [super init];
    self.vc = vc;
    self.doc = doc;
    return self;
}

+ (ARDKDocErrorHandler *)errorHandlerForViewController:(UIViewController *)vc showingDoc:(id<ARDKDoc>)doc
{
    return [[ARDKDocErrorHandler alloc] initForViewController:vc showingDoc:doc];
}

- (void)requestDocumentPassword
{
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"Password required",
                                                                           @"Title for alert dialog when warning that a password is required")
                                message:NSLocalizedString(@"Please enter the password for this document",
                                                          @"Message for alert dialog when warning that a password is required")
                                preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(alert) weakAlert = alert;

    // When DLP is enabled, the BB SDK prevents us adding an "Open" button to this dialog so for all
    // BB and non-BB targets we'll just label the button that opens the document with "OK"
    NSString *okButtonString = NSLocalizedString(@"OK",
                                                 @"Label for button to accept password and open the document");
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:okButtonString
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action)
                         {
                             [self.doc providePassword:weakAlert.textFields[0].text];
                         }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",
                                                                             @"Label for cancel operation button")
                                                                             style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction * action)
                             {
                                 [self.doc abortLoad];
                             }];

    [alert addAction:ok];
    [alert addAction:cancel];
    if ([alert respondsToSelector:@selector(setPreferredAction:)])
    {
        /* only available >= iOS 9 */
        alert.preferredAction = ok;
    }

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"Password",
                                                  @"Placeholder in textfield that accepts a password");
        textField.secureTextEntry = YES;
    }];

    [self.vc presentViewController:alert animated:YES completion:nil];
}

- (void)showMessage:(NSString *)msg withTitle:(NSString *)title
{
    UIAlertController *alert;

    alert = [UIAlertController alertControllerWithTitle:title
                                                message:msg
                                         preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *alertAction = [UIAlertAction
                                  actionWithTitle:NSLocalizedString(@"Dismiss",
                                                                    @"Label for button to remove dialog without action")
                                  style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction *action) {
                                  }];

    [alert addAction:alertAction];

    [self.vc presentViewController:alert animated:YES completion:nil];
}

- (void)handlerError:(ARDKDocErrorType)error
{
    NSString *msg = nil;

    switch (error) {
        case ARDKDocErrorType_NoError:
            assert("ARDKDocErrorType_NoError should never be reported" == NULL);
            msg = @"No error";
            break;

        case ARDKDocErrorType_UnsupportedDocumentType:
            msg = NSLocalizedString(@"Unsupported document type",
                                    @"Warning of problem loading document");
            break;

        case ARDKDocErrorType_EmptyDocument:
            msg = NSLocalizedString(@"Document is empty",
                                    @"Warning of problem loading document");
            break;

        case ARDKDocErrorType_UnsupportedEncryption:
            msg = NSLocalizedString(@"Document uses unsupported encryption",
                                    @"Warning of problem loading document");
            break;

        case ARDKDocErrorType_PasswordRequest:
            [self requestDocumentPassword];
            break;

        case ARDKDocErrorType_Aborted:
            /* nothing necessary here, presumably it was the user that aborted it */
            break;

        case ARDKDocErrorType_OutOfMemory:
            msg = NSLocalizedString(@"Document is too large",
                                    @"Warning of problem loading document");
            break;

        case ARDKDocErrorType_XFAForm:
            msg = @"This document contains an XML Forms Architecture (XFA) form and is not supported by SmartOffice. XFA was deprecated when the PDF 2.0 specification was released in 2015. The creator of the PDF can convert it to use AcroForms, which are supported. If appropriate, please contact your IT administrator for assistance.";
            break;

        case ARDKDocErrorType_UnableToLoadDocument:
        default:
            msg = NSLocalizedString(@"Document could not be loaded",
                                    @"Warning of problem loading document");
            break;
    }
    NSLog(@"Error loading document: %d [%@]", error, msg);

    if (msg)
    {
        [self showMessage:msg
                withTitle:NSLocalizedString(@"Unable to load document",
                                            @"Title of dialog for document loading error")];
    }
}

@end
