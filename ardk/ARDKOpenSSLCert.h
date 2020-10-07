//
//  ARDKOpenSSLCert.h
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#ifndef ARDKOpenSSLCert_h
#define ARDKOpenSSLCert_h

#import "ARDKPKCS7.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import <openssl/x509v3.h>
#import <openssl/pkcs7.h>
#import <openssl/err.h>
#pragma clang diagnostic pop

@interface ARDKOpenSSLCert : NSObject
+(NSData *) convertX509ToDER:(X509 *)cert;
@end

@interface ARDKOpenSSLCertDesignatedName : NSObject<PKCS7DesignatedName>
-(ARDKOpenSSLCertDesignatedName *) initWithDefaults;
+ (ARDKOpenSSLCertDesignatedName *)designatedNameFromX509:(X509 *)cert;
@end

@interface ARDKOpenSSLCertDescription : NSObject<PKCS7Description>
-(ARDKOpenSSLCertDescription *) initWithDefaults;
+ (ARDKOpenSSLCertDescription *)descriptionFromX509:(X509 *)cert;
@end

#endif /* ARDKOpenSSLCert_h */
