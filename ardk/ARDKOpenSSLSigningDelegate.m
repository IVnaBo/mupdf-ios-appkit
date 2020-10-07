//
//  ARDKOpenSSLSigningDelegate.m
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#if !defined(SODK_EXCLUDE_OPENSSL_PDF_SIGNING)

#import "ARDKOpenSSLSigningDelegate.h"
#import "ARDKOpenSSLSigner.h"
#import "ARDKOpenSSLVerifier.h"
#import "ARDKCertPickerDialogViewController.h"
#import "ARDKCertVerifyDialogViewController.h"

@implementation ARDKOpenSSLSigningDelegate

-(void) createSigner:(UIViewController *) presentingViewController
          onComplete:(void (^)(id<PKCS7Signer>))onComplete;
{
    ARDKMutableSigner *signer = [[ARDKOpenSSLSigner alloc] init];
    if (signer)
    {
        ARDKCertPickerDialogViewController *certPicker =
            [[ARDKCertPickerDialogViewController alloc] initWithSigner:signer
                                                             onDismiss:^(void) {
                    NSInteger certIndex = signer.selectedCertificateIndex;
                    
                    if (certIndex == NSNotFound)
                    {
                        // signer has no certifcate selected, return nil to the caller
                        onComplete(nil);
                    }
                    else
                    {
                        // signer has a certifcate selected, return signer to the caller
                        onComplete(signer);
                    }
                }];
        
        [presentingViewController presentViewController:certPicker
                                               animated:YES
                                             completion:nil];
    }
}

-(void) createVerifier:(UIViewController *) presentingViewController
            onComplete:(void (^)(id<PKCS7Verifier>))onComplete;
{
    id<PKCS7Verifier> verifier = [[ARDKOpenSSLVerifier alloc] init];
    
    dispatch_async(dispatch_get_main_queue(), ^{
            onComplete(verifier);
        });
}

-(void) presentVerifyResult:(UIViewController *) presentingViewController
               verifyResult:(PKCS7VerifyResult) verifyResult
         invalidChangePoint:(int) invalidChangePoint
             designatedName:(id<PKCS7DesignatedName>) designatedName
                description:(id<PKCS7Description>) description
                 onComplete:(void (^)(void))onComplete
{
    ARDKCertVerifyDialogViewController *certVerify = [ARDKCertVerifyDialogViewController alloc];
    certVerify = [certVerify initWithVerifyResult:(PKCS7VerifyResult) verifyResult
                               invalidChangePoint:invalidChangePoint
                                   designatedName:designatedName
                                      description:description
                                        onDismiss:^(void) {
            onComplete();
        }];
    
    [presentingViewController presentViewController:certVerify
                                           animated:YES
                                         completion:nil];
}

@end

#endif // SODK_EXCLUDE_OPENSSL_PDF_SIGNING
