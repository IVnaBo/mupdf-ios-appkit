//
//  ARDKCertPickerDialogViewController.h
//  smart-office-nui
//
//  Created by Stuart MacNeill on 2/7/2019
//  Copyright (c) 2019 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKMutableSigner.h"

@interface ARDKCertPickerDialogViewController : UIViewController

/**
 * Initialise this control
 *
 * @param signer            The signer object we'll use to access certificates
 * @param onDismiss         A callback block called when the dialog is dismissed.
 *                          The receiver callback should examine the signer object
 *                          to determine which (if any) certificate has been selected
 *                          for in the signer. If the dialog is dismissed by the user
 *                          pressing "Cancel" the signer with have no certificate
 *                          selected.
 */
- (id)initWithSigner:(ARDKMutableSigner *) signer
           onDismiss:(void (^)(void))onDismiss;

+ (BOOL) certificateFilterEnabled;
+ (void) setCertificateFilterEnabled:(BOOL) enable;

@end
