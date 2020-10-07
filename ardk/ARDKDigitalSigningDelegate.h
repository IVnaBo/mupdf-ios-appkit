//
//  ARDKDigitalSigningDelegate.h
//
//  Created by Stuart MacNeill on 1/04/2020.
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKPKCS7.h"

@protocol ARDKDigitalSigningDelegate <NSObject>

/**
 * A factory method used to create a PKCS7Signer object. This method will typically present
 * a dialog to prompt the user to initialize the returned PKCS7Signer object (e.g. by selecting
 * a certificate to be used by the PKCS7Signer). The PKCS7Signer object created by this
 * method is returned to the caller asynchronously via the onComplete() callback. The caller
 * should be prepared for a nil object to be returned in the case where the user opted to cancel
 * this operation. The presentingViewController argument will be used by this method to act as the
 * parent UIViewController for any dialog UIViewControllers created by this method to allow
 * the user to configure the returned PKCS7Signer object.
 *
 * @param presentingViewController   the parent view controller for any dialog viewcontrollers created
 *                                   by this call
 * @param onComplete                 called when the dialog created by this call has been destroyed
 */
-(void) createSigner:(UIViewController *) presentingViewController
          onComplete:(void (^)(id<PKCS7Signer>))onComplete;

/**
 * A factory method used to create a PKCS7Verifier object. This method will typically present
 * a dialog to prompt the user to initialize the returned PKCS7Verifier object (e.g. by selecting
 * a certificate to be used by the PKCS7Verifier). The PKCS7Verifier object created by this
 * method is returned to the caller asynchronously via the onComplete() callback. The caller
 * should be prepared for a nil object to be returned in the case where the user opted to cancel
 * this operation. The presentingViewController argument will be used by this method to act as the
 * parent UIViewController for any dialog UIViewControllers created by this method to allow
 * the user to configure the returned PKCS7Verifier object.
 *
 * @param presentingViewController   the parent view controller for any dialog viewcontrollers created
 *                                   by this call
 * @param onComplete                 called when the dialog created by this call has been destroyed
 */
-(void) createVerifier:(UIViewController *) presentingViewController
            onComplete:(void (^)(id<PKCS7Verifier>))onComplete;

/**
 * Display the result if a verify operation to the user, this will typically be implemented
 * as a dialog that presents the succees/failure of the call to verify an allow the user
 * to view the details of the certificate being verified. The presentingViewController argument
 * will be used by this method to act as the parent UIViewController for any dialog UIViewControllers
 * created by this method.
 *
 * @param presentingViewController   the parent view controller for any dialog viewcontrollers created
 *                                   by this call
 * @param verifyResult               the result code from the verify operation
 * @param invalidChangePoint         YES if this document has been modified since it was signed
 * @param designatedName             the designated name info from the signature being verified
 * @param description                the description info from the signature being verified
 * @param onComplete                 called when the dialog created by this call has been destroyed
 */

-(void) presentVerifyResult:(UIViewController *) presentingViewController
               verifyResult:(PKCS7VerifyResult) verifyResult
         invalidChangePoint:(int) invalidChangePoint
             designatedName:(id<PKCS7DesignatedName>) designatedName
                description:(id<PKCS7Description>) description
                 onComplete:(void (^)(void)) onComplete;
@end
