//
//  ARDKOpenSSLVerifier.m
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#import "ARDKOpenSSLVerifier.h"
#import "ARDKOpenSSLCert.h"
#import "ARDKOpenSSLKeychain.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import <openssl/x509v3.h>
#import <openssl/pkcs7.h>
#import <openssl/err.h>
#pragma clang diagnostic pop

@implementation ARDKOpenSSLVerifier
{
    ARDKOpenSSLKeychain           *_keychain;
    NSMutableData                 *_verifyData;
    ARDKOpenSSLCertDesignatedName *_designatedName;
    ARDKOpenSSLCertDescription    *_description;
}

- (instancetype)init
{
    if (self = [super init])
    {
        _keychain = [[ARDKOpenSSLKeychain alloc] init];

        _verifyData = nil;
        _designatedName = nil;
        _description = nil;
    }
    return self;
}

// Announce the start of a verification request before sending the data
- (void)begin
{
    _verifyData = [[NSMutableData alloc] init];
    
    _designatedName = [[ARDKOpenSSLCertDesignatedName alloc] initWithDefaults];
    _description = [[ARDKOpenSSLCertDescription alloc] initWithDefaults];
}

// Send a chunk of the data on which a signature is to be verified
- (void)data:(NSData *)data
{
    if (_verifyData)
    {
        [_verifyData appendData:data];
    }
}

// Announce the end of the data and request verification of the signature
- (PKCS7VerifyResult)verify:(NSData *)signature
{
    PKCS7VerifyResult res = PKCS7VerifyResult_Unknown;

    BIO *dataToVerify = NULL;
    BIO *sigStream = NULL;
    PKCS7 *sigP7 = NULL;
    X509_STORE *trustedCertsFromAppKeychain = NULL;

    dataToVerify = BIO_new_mem_buf((void *)[_verifyData bytes], (int)[_verifyData length]);
    sigStream = BIO_new_mem_buf((void *)[signature bytes], (int)[signature length]);
    sigP7 = d2i_PKCS7_bio(sigStream, NULL);
    
    if (sigP7 &&
        PKCS7_type_is_signed(sigP7))
    {
        // Verify document has not been edited since signing.
        int verifyResult = PKCS7_verify(sigP7, NULL, NULL, dataToVerify, NULL, PKCS7_NOVERIFY);
        if (verifyResult != 1)
        {
            NSLog(@"Document digest verification failure. This document has been changed after it was signed. Error:%s",
                  ERR_error_string(ERR_get_error(), NULL));
            res = PKCS7VerifyResult_DigestFailure;
            goto CLEANUP;
        }

        // get the current set of trusted certificates
        trustedCertsFromAppKeychain = [_keychain getTrustedCertificates];
        
        // get the certs who signed this signature
        STACK_OF(X509) *signers = PKCS7_get0_signers(sigP7, NULL, 0);
        
        // get the cert used to sign this object
        X509 *signerCert = NULL;
        if (signers &&
            (sk_X509_num(signers) > 0))
        {
            signerCert = sk_X509_value(signers, 0);
            [self updateName:signerCert];
            [self updateDescription:signerCert];
        }

        NSString *subjectNameOneLine = NULL;
        if (signerCert)
        {
            X509_NAME *x509Name = X509_get_subject_name(signerCert);
            if (x509Name)
            {
                char *tempName = X509_NAME_oneline(x509Name, NULL, 0);
                if (tempName)
                {
                    subjectNameOneLine = [NSString stringWithUTF8String:tempName];
                    OPENSSL_free(tempName);
                    tempName = NULL;
                }
            }
        }
        
        // Try to verify that "signerCert" is trusted by the certificates currently
        // installed in the iOS profiles on this device
        BOOL trustedByProfiles = [self isTrustedBySystemProfiles:signerCert];
        NSLog(@"This document was signed by '%@', the signature is %@ by the currently installed iOS profiles",
              subjectNameOneLine ? subjectNameOneLine : @"<unknown>",
              trustedByProfiles ? @"TRUSTED" : @"NOT TRUSTED");
        
        // Try to verify that "signerCert" is trusted by the certificates currently
        // installed in the iOS app keychain for this app
        verifyResult = PKCS7_verify(sigP7, signers, trustedCertsFromAppKeychain, dataToVerify, NULL, 0);
        BOOL trustedByKeychain = (verifyResult == 1);
        NSLog(@"This document was signed by '%@', the signature is %@ by the current keychain for this app",
              subjectNameOneLine ? subjectNameOneLine : @"<unknown>",
              trustedByKeychain ? @"TRUSTED" : @"NOT TRUSTED");
        
        BOOL signerCertIsTrusted = (trustedByProfiles || trustedByKeychain);
        if (signerCertIsTrusted)
        {
            NSLog(@"Document signature verified. The document was signed by the trusted certificate '%@'", 
                  subjectNameOneLine ? subjectNameOneLine : @"<unknown>");
            
            res = PKCS7VerifyResult_Okay;
        }
        else
        {
            NSLog(@"Document signature verify failed. The document was signed by the untrusted certificate '%@'. (Error: %s)", 
                  subjectNameOneLine ? subjectNameOneLine : @"<unknown>",
                  ERR_error_string(ERR_get_error(), NULL));
            
            res = PKCS7VerifyResult_NotTrusted;
        }
    }
    else
    {
        res = PKCS7VerifyResult_No_Signature;
        NSLog(@"Error: %s - Input is not a PKCS7 signature.",
              __PRETTY_FUNCTION__ );
        goto CLEANUP;
    }

CLEANUP:
    PKCS7_free(sigP7);
    BIO_free(sigStream);
    BIO_free(dataToVerify);

    if (trustedCertsFromAppKeychain)
    {
        X509_STORE_free(trustedCertsFromAppKeychain);
        trustedCertsFromAppKeychain = NULL;
    }
    
    return res;;
}

// Update the signer's designated name from the signing certificate in the signature
- (void)updateName:(X509 *) cert
{
    _designatedName = [ARDKOpenSSLCertDesignatedName designatedNameFromX509:cert];
}

// Update the signer's description from the signing certificate in the signature
- (void)updateDescription:(X509 *) cert
{
    _description = [ARDKOpenSSLCertDescription descriptionFromX509:cert];
}

// Get the signer's designated name from the signature
- (id<PKCS7DesignatedName>)name:(NSData *)signature
{
    return _designatedName;
}

// Get the signer's certificate description name from the signature
- (id<PKCS7Description>)description:(NSData *)signature
{
   return _description;
}

// Returns YES if "certToCheck" is trusted by the certificates currently installed
// in the iOS system profiles for this device, returns NO if not trusted
- (BOOL) isTrustedBySystemProfiles:(X509 *)certToCheck
{
    BOOL certIsTrusted = NO;
    
    if (certToCheck)
    {
        NSData *certDER = [ARDKOpenSSLCert convertX509ToDER:certToCheck];
        if (certDER &&
            ([certDER length] > 0))
        {
            SecCertificateRef certRef = SecCertificateCreateWithData(NULL,
                                                                     (__bridge CFDataRef) certDER);
            if (certRef)
            {
                SecPolicyRef policyRef = SecPolicyCreateBasicX509();
                if (policyRef)
                {
                    SecTrustRef trustRef;
                    OSStatus err = SecTrustCreateWithCertificates((__bridge CFArrayRef) @[(__bridge id)certRef],
                                                                  policyRef,
                                                                  &trustRef);
                    if (err == errSecSuccess)
                    {
                        SecTrustResultType trustResult = (SecTrustResultType) -1;
                        err = SecTrustEvaluate(trustRef, &trustResult);
                        certIsTrusted = (trustResult == kSecTrustResultProceed);
                    }
                    CFRelease(trustRef);
                }
                CFRelease(policyRef);
            }
            CFRelease(certRef);
        }
    }
    return certIsTrusted;
}

@end
