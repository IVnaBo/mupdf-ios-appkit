//
//  ARDKOpenSSLSigner.m
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#import "ARDKOpenSSLSigner.h"
#import "ARDKOpenSSLCert.h"
#import "ARDKOpenSSLKeychain.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import <openssl/x509v3.h>
#import <openssl/pkcs7.h>
#import <openssl/err.h>
#pragma clang diagnostic pop

@implementation ARDKOpenSSLSigner
{
    ARDKOpenSSLKeychain *_keychain;
    NSArray             *_identityLabels;
    NSInteger            _selectedIdentityIndex;
    X509                *_certificate;
    EVP_PKEY            *_signingKey;
    NSMutableData       *_signerSourceData;
}

- (instancetype)init
{
    if (self = [super init])
    {
        _keychain = [[ARDKOpenSSLKeychain alloc] init];

        _identityLabels = nil;
        _certificate = NULL;
        _signingKey = NULL;
        
        _selectedIdentityIndex = NSNotFound;
        _signerSourceData = nil;
    }
    return self;
}

// Get the signer's selected certificate's designated name
- (id<PKCS7DesignatedName>)name
{
    [self ensureCertificate];

    if (_certificate)
    {    
        // get the designated name from the signing cert
        return [ARDKOpenSSLCertDesignatedName designatedNameFromX509:_certificate];
    }
    else
    {
        return nil;
    }
}

// Get the signer's selected certificate's description info
- (id<PKCS7Description>)description
{
    [self ensureCertificate];

    if (_certificate)
    {    
        // get the description from the signing cert
        return [ARDKOpenSSLCertDescription descriptionFromX509:_certificate];
    }
    else
    {
        return nil;
    }
}

// Announce the start of a signing request before sending the data to sign
- (void)begin
{
    _signerSourceData = [[NSMutableData alloc] init];
}

// Send a chunk of the data to be signed (may be called repeatedly)
- (void)data:(NSData *)data
{
    if (_signerSourceData)
    {
        [_signerSourceData appendData:data];
    }
}

- (void)freeCertificate
{
    // delete the current certficate if there is one
    if (_certificate)
    {
        X509_free(_certificate);
    }
    _certificate = NULL;
}

- (void)freeSigningKey
{
    if (_signingKey)
    {
        // delete the current signing key if there is one
        EVP_PKEY_free(_signingKey);
    }
    _signingKey = NULL;
}

- (void)ensureCertificate
{
    if (_identityLabels == nil)
    {
        _identityLabels = [_keychain select:(__bridge NSString *)kSecAttrLabel
                                  fromClass:(__bridge NSString *)kSecClassIdentity
                                   whereKey:nil
                                equalsValue:nil];
    }

    // free up old certificate and signing key we currently have
    [self freeCertificate];
    [self freeSigningKey];

    // update the selected certificate
    if (_identityLabels &&
        (_selectedIdentityIndex != NSNotFound) )
    {
        NSString *selectedLabel = (NSString *)_identityLabels[ (int)_selectedIdentityIndex ];
        if (selectedLabel)
        {
            // get the certificate from the identity whose "label" == "selectedLabel" from the keychain
            _certificate = [_keychain getX509CertificateFromIdentity:selectedLabel];

            // get the private key from the identity whose "label" == "selectedLabel" from the keychain
            _signingKey = [_keychain getPrivateKeyFromIdentity:selectedLabel];
        }
    }
}

// Announce the end of the data and request the signature
- (NSData *)sign
{
    NSMutableData     *returnValue = NULL;
    PKCS7             *p7Sign = NULL;
    PKCS7_SIGNER_INFO *p7SignerInfo = NULL;
    BIO               *inBio = NULL;
    BIO               *outBio = NULL;
    STACK_OF(X509)    *auxCerts = NULL;
    int               pkcs7Flags = PKCS7_STREAM | PKCS7_BINARY | PKCS7_DETACHED;

    if (!_keychain)
    {
        goto CLEANUP;
    }

    returnValue = [[NSMutableData alloc] init];
    if (!returnValue)
    {
        goto CLEANUP;
    }
    
    [self ensureCertificate];
    
    if ( _certificate == NULL )
    {
        goto CLEANUP;
    }

    inBio = BIO_new(BIO_s_mem());
    if (!inBio)
    {
        goto CLEANUP;
    }
    
    // write the data we're signing into inBio
    BIO_write(inBio,
              [_signerSourceData bytes],
              (int)[_signerSourceData length]);
    
    // TODO: If the signer has intermediate certificates include them in the PKCS7 signature,
    // so only the root CA need be in the trusted cert store for verification purposes.
    //auxCerts = ??? TODO ???

    // Create the PKCS7 signature object
    p7Sign = PKCS7_sign(NULL,
                        NULL,
                        auxCerts,
                        inBio,
                        pkcs7Flags );
    if (!p7Sign)
    {
        goto CLEANUP;
    }
    
    // Add the certificate, private key, aux keys and digest to the PKCS7 signature object
    p7SignerInfo = PKCS7_sign_add_signer(p7Sign,
                                         _certificate,
                                         _signingKey,
                                         EVP_get_digestbyname("sha256"),
                                         pkcs7Flags );
   
    if (!p7SignerInfo)
    {
        goto CLEANUP;
    }
        
    outBio = BIO_new(BIO_s_mem());
    if (!outBio)
    {
        goto CLEANUP;
    }
    
    // Finalize the PKCS7 signature object
    if (PKCS7_final(p7Sign,
                    inBio,
                    pkcs7Flags) != 1)
    {
        goto CLEANUP;
    }

    // Convert the PKCS7 signature object to DER encoding
    if (i2d_PKCS7_bio(outBio,
                      p7Sign) == 0)
    {
        goto CLEANUP;
    }
    
    // Copy the DER encoded PKCS7 signature to returnValue
    BUF_MEM *bufMem = NULL;
    BIO_get_mem_ptr(outBio, &bufMem);
    if (bufMem)
    {
        [returnValue appendBytes:bufMem->data
                          length:bufMem->length];
    }
    else
    {
        goto CLEANUP;
    }
        
CLEANUP:
    BIO_free(outBio);
    PKCS7_free(p7Sign);
    BIO_free(inBio);

    if (auxCerts)
    {
        sk_X509_free(auxCerts);
        auxCerts = NULL;
    }
    
    return returnValue;
}

-(NSInteger) numCertificates
{
    NSInteger ret = 0;

    NSArray *certsToCount = [_keychain select:(__bridge NSString *)kSecAttrLabel
                                    fromClass:(__bridge NSString *)kSecClassIdentity
                                     whereKey:nil
                                  equalsValue:nil];
    if (certsToCount)
    {
        ret = [certsToCount count];
    }

    return ret;
}

-(void) setSelectedCertificateIndex:(NSInteger) index
{
    _selectedIdentityIndex = index;
    [self ensureCertificate];
}

-(NSInteger) selectedCertificateIndex
{
    return _selectedIdentityIndex;
}
@end

