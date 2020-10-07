//
//  ARDKCertVerifyDialogViewController.h
//  smart-office-nui
//
//  Created by Stuart MacNeill on 19/7/2019
//  Copyright (c) 2019 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKPKCS7.h"

@interface ARDKCertVerifyDialogViewController : UIViewController

/**
 * Initialise this control
 *
 * @param verifyResult        The result of the verify operation this dialog is repoting on
 * @param invalidChangePoint  YES if the document being verified has been saved since it was
 *                            signed, NO it it has not been saved since it was signed
 * @param designatedName      The designamed name information from the signature being verified
 * @param description         The description of the signature being verified
 * @param onDismiss           A callback block called when the dialog is dismissed.
 *
 */
- (id)initWithVerifyResult:(PKCS7VerifyResult) verifyResult
        invalidChangePoint:(int) invalidChangePoint
            designatedName:(id<PKCS7DesignatedName>) designatedName
               description:(id<PKCS7Description>) description
                 onDismiss:(void (^)(void))onDismiss;

@end

