//
//  ARDKOpenSSLCert.m
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#import "ARDKOpenSSLCert.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import <openssl/pem.h>
#pragma clang pop diagnostic

@implementation ARDKOpenSSLCert

+ (NSData *) convertX509ToDER:(X509 *)cert
{
    BIO *bio = NULL;
    unsigned char *derCert = NULL;
    
    if (cert == NULL)
    {
        return NULL;
    }
    
    bio = BIO_new( BIO_s_mem() );
    if (bio == NULL)
    {
        return NULL;
    }

    if (i2d_X509_bio(bio, cert) == 0)
    {
        BIO_free(bio);
        return NULL;
    }

    int derCertLength = (int) bio->num_write;
    derCert = (unsigned char *) OPENSSL_malloc(derCertLength);
    if (derCert == NULL)
    {
        BIO_free(bio);
        return NULL;    
    }

    memset(derCert, 0, derCertLength);
    BIO_read(bio, derCert, derCertLength);
    
    NSData *ret = [[NSData alloc] initWithBytes:derCert
                                         length:derCertLength];
    BIO_free(bio);
    OPENSSL_free(derCert);
    
    return ret;
}

@end

@implementation ARDKOpenSSLCertDesignatedName
@synthesize cn;
@synthesize o;
@synthesize ou;
@synthesize email;
@synthesize c;

- (ARDKOpenSSLCertDesignatedName *) initWithDefaults
{
    self.cn =    @"unknown";
    self.o =     @"unknown";
    self.ou =    @"unknown";
    self.email = @"unknown";
    self.c =     @"unknown";
    
    return self;
}

+ (NSMutableDictionary *)parseX509field:(NSString *)subject
                              separator:(NSString *)sep
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSArray *pairs = [subject componentsSeparatedByString:@"/"];
    
    for (NSString *entry in pairs) {
        NSString *pair = [entry stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([pair length] != 0)
        {
            NSArray *elements = [pair componentsSeparatedByString:sep];
            NSString *key = [[elements objectAtIndex:0] stringByRemovingPercentEncoding];
            NSString *val = [[elements objectAtIndex:1] stringByRemovingPercentEncoding];
            
            [dict setObject:val forKey:key];
        }
    }
    return dict;
}

// Get the certificate's designated name
+ (ARDKOpenSSLCertDesignatedName *)designatedNameFromX509:(X509 *)cert
{
    // get the designated name from the signing cert
    ARDKOpenSSLCertDesignatedName *designatedName = [[ARDKOpenSSLCertDesignatedName alloc] initWithDefaults];
    if (cert)
    {
        STACK_OF(OPENSSL_STRING) *emailStack = X509_get1_email(cert);
        if (emailStack)
        {
            for(int idx = 0; idx < sk_OPENSSL_STRING_num(emailStack); idx++)
            {
                OPENSSL_STRING currName = sk_OPENSSL_STRING_value(emailStack, idx);
                if (currName)
                {
                    designatedName.email = [NSString stringWithUTF8String:currName];
                }
            }
        }
        
        X509_NAME *subjectName = X509_get_subject_name(cert);
        if (subjectName)
        {
            char *subjectNameOneLine = X509_NAME_oneline(subjectName, NULL, 0);
            if (subjectNameOneLine)
            {
                NSMutableDictionary *subjDict = [ARDKOpenSSLCertDesignatedName parseX509field:[NSString stringWithUTF8String:subjectNameOneLine]
                                                                                    separator:@"="];
                if(subjDict)
                {
                    NSString *value;
                    
                    value = [subjDict valueForKey:@"CN"];
                    if (value)
                    {
                        designatedName.cn = value;
                    }
                    
                    value = [subjDict valueForKey:@"O"];
                    if (value)
                    {
                        designatedName.o = value;
                    }
                    
                    value = [subjDict valueForKey:@"OU"];
                    if (value)
                    {
                        designatedName.ou = value;
                    }
                        
                    value = [subjDict valueForKey:@"C"];
                    if (value)
                    {
                        designatedName.c = value;
                    }
                    
                    value = [subjDict valueForKey:@"emailAddress"];
                    if (value)
                    {
                        designatedName.email = value;
                    }
                }
            }
            OPENSSL_free(subjectNameOneLine);
        }
    }
        
    return designatedName;
}

@end

@implementation ARDKOpenSSLCertDescription
@synthesize issuer;
@synthesize subject;
@synthesize subjectAlt;
@synthesize serial;
@synthesize notValidBefore;
@synthesize notValidAfter;
@synthesize keyUsage;
@synthesize extKeyUsage;

- (ARDKOpenSSLCertDescription *) initWithDefaults
{
    self.issuer =          @"unknown";
    self.subject =         @"unknown";
    self.subjectAlt =      @"unknown";
    self.serial =          @"unknown";
    self.notValidBefore =  @"0";
    self.notValidAfter =   @"0";

    self.keyUsage =        [[NSSet alloc] init];
    self.extKeyUsage =     [[NSSet alloc] init];
    
    return self;
}

+ (ARDKOpenSSLCertDescription *)descriptionFromX509:(X509 *)cert
{
    ARDKOpenSSLCertDescription *description = [[ARDKOpenSSLCertDescription alloc] initWithDefaults];
    if (cert)
    {
        X509_NAME *tempName = nil;

        // get the issuer name
        tempName = X509_get_issuer_name(cert);
        if (tempName)
        {
            char *tempNameString = X509_NAME_oneline(tempName, NULL, 0);
            description.issuer = tempNameString ? [NSString stringWithUTF8String:tempNameString] : @"";
        }

        // get the subject
        tempName = X509_get_subject_name(cert);
        if (tempName)
        {
            char *tempNameString = X509_NAME_oneline(tempName, NULL, 0);
            description.subject = tempNameString ? [NSString stringWithUTF8String:tempNameString] : @"";
        }
        
        // get the subject alt name
        description.subjectAlt = @"";

        // get the certificate serial number
        ASN1_INTEGER *serial = X509_get_serialNumber(cert);
        long serialLong = serial ? ASN1_INTEGER_get(serial) : 0;
        description.serial = [NSString stringWithFormat: @"%ld", serialLong];
        
        // get the "not valid before" (defaults to "0")
        description.notValidBefore = @"0";
        if (cert &&
            cert->cert_info &&
            cert->cert_info->validity)
        {
            ASN1_TIME epoch = {};
            ASN1_TIME_set(&epoch, 0);

            int days = 0;
            int seconds = 0;
            if (ASN1_TIME_diff(&days,
                               &seconds,
                               &epoch,
                               cert->cert_info->validity->notBefore))
            {
                time_t secondsSinceEpoch = ((time_t)days * 60 * 60 * 24) + (time_t)seconds;
                description.notValidBefore = [NSString stringWithFormat: @"%ld", secondsSinceEpoch];
            }
        }

        // get the "not valid after" (defaults to "0")
        description.notValidAfter = @"0";
        if (cert &&
            cert->cert_info &&
            cert->cert_info->validity)
        {
            ASN1_TIME epoch = {};
            ASN1_TIME_set(&epoch, 0);

            int days = 0;
            int seconds = 0;
            if (ASN1_TIME_diff(&days,
                               &seconds,
                               &epoch,
                               cert->cert_info->validity->notAfter))
            {
                time_t secondsSinceEpoch = ((time_t)days * 60 * 60 * 24) + (time_t)seconds;
                description.notValidAfter = [NSString stringWithFormat: @"%ld", secondsSinceEpoch];  
            }
        }

        // get the key usage flags
        NSMutableSet *keyUsageSet = [[NSMutableSet alloc] init];
        if (cert &&
            cert->cert_info &&
            cert->cert_info->extensions)
        {
            NSString *keyUsageStr = nil;
            BIO *memBio = BIO_new(BIO_s_mem());
            
            int loc = X509v3_get_ext_by_NID(cert->cert_info->extensions,
                                            NID_key_usage,
                                            -1);
            if (loc >= 0)
            {
                X509_EXTENSION *keyUsageExt = X509v3_get_ext(cert->cert_info->extensions, loc);
                if (keyUsageExt)
                {
                    X509V3_EXT_print(memBio, keyUsageExt, 0, 0);

                    BUF_MEM *bufMem = NULL;
                    BIO_get_mem_ptr(memBio, &bufMem);
                    if (bufMem)
                    {
                        keyUsageStr = [[NSString alloc] initWithBytes:bufMem->data
                                                               length:bufMem->length
                                                             encoding:NSASCIIStringEncoding];
                    }
                }
            }
            BIO_free(memBio);

            NSArray *items = [keyUsageStr componentsSeparatedByString:@","];
            for (NSString *item in items)
            {
                NSString *trimmedItem = [item stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                [keyUsageSet addObject:trimmedItem];
            }
        }
        description.keyUsage = keyUsageSet;

        // get the ext key usage flags
        NSMutableSet *extKeyUsageSet = [[NSMutableSet alloc] init];
        if (cert &&
            cert->cert_info &&
            cert->cert_info->extensions)
        {
            NSString *extKeyUsageStr = nil;
            BIO *memBio = BIO_new(BIO_s_mem());
            
            int loc = X509v3_get_ext_by_NID(cert->cert_info->extensions,
                                            NID_ext_key_usage,
                                            -1);
            if (loc >= 0)
            {
                X509_EXTENSION *extKeyUsageExt = X509v3_get_ext(cert->cert_info->extensions, loc);
                if (extKeyUsageExt)
                {
                    X509V3_EXT_print(memBio, extKeyUsageExt, 0, 0);

                    BUF_MEM *bufMem = NULL;
                    BIO_get_mem_ptr(memBio, &bufMem);
                    if (bufMem)
                    {
                        extKeyUsageStr = [[NSString alloc] initWithBytes:bufMem->data
                                                                  length:bufMem->length
                                                                encoding:NSASCIIStringEncoding];
                    }
                }
            }
            BIO_free(memBio);

            NSArray *items = [extKeyUsageStr componentsSeparatedByString:@","];
            for (NSString *item in items)
            {
                NSString *trimmedItem = [item stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                [extKeyUsageSet addObject:trimmedItem];
            }
        }
        description.extKeyUsage = extKeyUsageSet;
    }
    return description;
}
@end
