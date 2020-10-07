//
//  ARDKOpenSSLKeychain.m
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#import "ARDKOpenSSLKeychain.h"

@interface ARDKOpenSSLKeychain ()
@end

@implementation ARDKOpenSSLKeychain

+(NSString * _Nonnull) SecAPI_errorToString:(OSStatus) value
{
    NSString *nsValue = @(value).stringValue;
    if ( @available(iOS 11.3, *) )
    {
        CFStringRef cfValue = SecCopyErrorMessageString(value, NULL);
        nsValue = (__bridge_transfer NSString *) cfValue;
    }
    return nsValue;
}

-(NSArray * _Nonnull) select:(NSString * _Nonnull) key
                   fromClass:(NSString * _Nonnull) fromClass
                    whereKey:(NSString * _Nullable) whereKey
                 equalsValue:(NSString * _Nullable) equalsValue
{
    NSMutableArray *retArray = [[NSMutableArray alloc] init];
    
    NSDictionary *query = @{
        (__bridge id) kSecClass:            fromClass,
        
        (__bridge id) kSecReturnData:       (__bridge id) kCFBooleanTrue,
        (__bridge id) kSecReturnAttributes: (__bridge id) kCFBooleanTrue,
        (__bridge id) kSecReturnRef:        (__bridge id) kCFBooleanTrue,
        (__bridge id) kSecMatchLimit:       (__bridge id) kSecMatchLimitAll
    };
    
    CFTypeRef queryResults = NULL;
    OSStatus copyResult = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                              &queryResults);
    if (copyResult == errSecSuccess)
    {
        if (queryResults)
        {
            NSArray *array = (__bridge NSArray *) queryResults;
            if (array)
            {
                for(int i = 0; i < [array count]; i++)
                {
                    NSDictionary *dict = (NSDictionary *) array[i];
                    
                    bool objectMatch = NO;
                    if (whereKey && equalsValue)
                    {
                        // we're narrowing the search with (whereKey, equalsValue)
                        // test to see if this object is a match for (whereKey, equalsValue)
                        NSObject *objectValue = [dict valueForKey:whereKey];
                        if (objectValue)
                        {
                            objectMatch = [objectValue isEqual:equalsValue];
                        }
                    }
                    else
                    {
                        // we're not narrowing the search with (whereKey,equalsValue)
                        // so consider all objects as a "match" for this query
                        objectMatch = YES;
                    }

                    if (objectMatch)
                    {
                        id attrValue = [dict valueForKey:key];
                        if (attrValue)
                        {
                            // append a copy of value to the retArray, only works for
                            // attribute values that are kinds of NSString and NSData
                            if ([attrValue isKindOfClass:[NSString class]])
                            {
                                [retArray addObject:[NSString stringWithString:(NSString *)attrValue]];
                            }
                            else if ([attrValue isKindOfClass:[NSData class]])
                            {
                                [retArray addObject:[NSData dataWithData:(NSData *)attrValue]];
                            }
                            else
                            {
                                NSLog(@"Error: %s - unexpected value class '%@' for attribute key '%@'",
                                      __PRETTY_FUNCTION__,
                                      [attrValue class],
                                      key);
                            }
                        }
                    }
                }
            }
        }
    }
    else
    {
        NSLog(@"Error: %s SetItemCopyMatching() returns error '%@'",
              __PRETTY_FUNCTION__,
              [ARDKOpenSSLKeychain SecAPI_errorToString:copyResult]);
    }
    
    if (queryResults)
    {
        CFRelease(queryResults);
    }
    
    return retArray;
}

-(X509 * _Nullable) getX509CertificateFromIdentity:(NSString * _Nonnull) identityLabel
{
    X509 *ret = NULL;
    
    NSDictionary *query = @{
        (__bridge id) kSecClass:            (__bridge id) kSecClassIdentity,
        
        (__bridge id) kSecReturnRef:        (__bridge id) kCFBooleanTrue,
        (__bridge id) kSecReturnAttributes: (__bridge id) kCFBooleanTrue,
        (__bridge id) kSecMatchLimit:       (__bridge id) kSecMatchLimitAll
    };
    
    CFTypeRef queryResults = NULL;
    OSStatus copyResult = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                              &queryResults);
    if (copyResult == errSecSuccess)
    {
        if (queryResults)
        {
            NSArray *array = (__bridge NSArray *) queryResults;
            if (array)
            {
                for(int i = 0; i < [array count]; i++)
                {
                    NSDictionary *dict = (NSDictionary *) array[i];
                    SecIdentityRef identityRef = (__bridge SecIdentityRef)[dict valueForKey:(__bridge id)kSecValueRef];
                    NSObject *labelValue = [dict valueForKey:(__bridge NSString *)kSecAttrLabel];

                    if (identityRef &&
                        labelValue &&
                        [labelValue isEqual:identityLabel])
                    {
                        SecCertificateRef certificateRef = NULL;
                        OSStatus certCopyResult = SecIdentityCopyCertificate(identityRef,
                                                                             &certificateRef);
                        if (certCopyResult == errSecSuccess)
                        {
                            CFDataRef certDataRef = SecCertificateCopyData(certificateRef);
                            if (certDataRef)
                            {
                                const unsigned char *certBytes = (const unsigned char *) CFDataGetBytePtr(certDataRef);
                                long certBytesLen = (long) CFDataGetLength(certDataRef);
                                
                                // decode the DER encoded X509 data
                                ret = d2i_X509(NULL, &certBytes, certBytesLen);
                            }
                            
                            // we're done with the copy of the certificate, release it
                            if (certificateRef)
                            {
                                CFRelease(certificateRef);
                            }
                        }
                    }                    
                }
            }
        }
    }
    else
    {
        NSLog(@"Error: %s SetItemCopyMatching() returns error '%@'",
              __PRETTY_FUNCTION__,
              [ARDKOpenSSLKeychain SecAPI_errorToString:copyResult]);
    }
    
    if (queryResults)
    {
        CFRelease(queryResults);
    }
    
    return ret;
}

-(EVP_PKEY * _Nullable) getPrivateKeyFromIdentity:(NSString * _Nonnull) identityLabel
{
    EVP_PKEY *ret = NULL;
    
    // get the "application label" from the identity who's "label" matches "identityLabel" 
    NSArray *identityAppLabels = [self select:(__bridge NSString *)kSecAttrApplicationLabel
                                    fromClass:(__bridge NSString *)kSecClassIdentity
                                     whereKey:(__bridge NSString *)kSecAttrLabel
                                  equalsValue:identityLabel];

    if (identityAppLabels &&
        identityAppLabels.count > 0)
    {
        NSData *privateKeyAppLabel = identityAppLabels[ 0 ];
        
        // get the private key who's "application label" matches the first value in identityAppLabels
        // there should be only one item in this array as we assune that "label" is unique for identity
        // objects in the key chain
        NSDictionary *query = @{
            (__bridge id) kSecClass:                (__bridge id) kSecClassKey,
            (__bridge id) kSecAttrApplicationLabel: privateKeyAppLabel,
            
            (__bridge id) kSecReturnRef:            (__bridge id) kCFBooleanTrue,
            (__bridge id) kSecReturnAttributes:     (__bridge id) kCFBooleanTrue,
            (__bridge id) kSecMatchLimit:           (__bridge id) kSecMatchLimitAll
        };
        
        CFTypeRef queryResults = NULL;
        OSStatus copyResult = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                                  &queryResults);
        if (copyResult == errSecSuccess)
        {
            if (queryResults)
            {
                NSArray *array = (__bridge NSArray *) queryResults;
                if (array &&
                    array.count > 0)
                {
                    NSDictionary *dict = (NSDictionary *) array[0];
                    SecKeyRef privateKeyRef = (__bridge SecKeyRef)[dict valueForKey:(__bridge id)kSecValueRef];

                    if (privateKeyRef)
                    {
                        CFErrorRef copyError;
                        CFDataRef privateKeyDataRef = SecKeyCopyExternalRepresentation(privateKeyRef, &copyError);
                        if (privateKeyDataRef)
                        {
                            const unsigned char *privateKeyBytes = (const unsigned char *) CFDataGetBytePtr(privateKeyDataRef);
                            long privateKeyBytesLen = (long) CFDataGetLength(privateKeyDataRef);
                            
                            // decode the DER encoded EVP_PKEY data
                            ret = d2i_PrivateKey(EVP_PKEY_RSA, NULL, &privateKeyBytes,  privateKeyBytesLen);

                            CFRelease(privateKeyDataRef);
                        }
                        else
                        {
                            NSString *errorNSString = @"unknown";
                            CFStringRef errorString = CFErrorCopyDescription(copyError);
                            if (errorString)
                            {
                                errorNSString = [NSString stringWithString:(__bridge NSString *)errorString];
                                CFRelease(errorString);
                            }
                            
                            NSLog(@"Error: SecKeyCopyExternalRepresentation() failed with error: '%@'",
                                  errorNSString);
                        }
                    }
                }
            }
        }
        else
        {
            NSLog(@"Error: %s SetItemCopyMatching() returns error '%@'",
                  __PRETTY_FUNCTION__,
                  [ARDKOpenSSLKeychain SecAPI_errorToString:copyResult]);
        }
        
        if (queryResults)
        {
            CFRelease(queryResults);
        }
    }
    return ret;
}

-(X509_STORE * _Nullable) getTrustedCertificates
{
    X509_STORE *returnValue = X509_STORE_new();
    
    // get all the certificates currently in the keychain
    NSDictionary *query = @{
        (__bridge id) kSecClass:                (__bridge id) kSecClassCertificate,
        
        (__bridge id) kSecReturnRef:            (__bridge id) kCFBooleanTrue,
        (__bridge id) kSecReturnAttributes:     (__bridge id) kCFBooleanTrue,
        (__bridge id) kSecMatchLimit:           (__bridge id) kSecMatchLimitAll
    };
    
    CFTypeRef queryResults = NULL;
    OSStatus copyResult = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                              &queryResults);
    if (copyResult == errSecSuccess)
    {
        if (queryResults)
        {
            NSArray *array = (__bridge NSArray *) queryResults;
            if (array)
            {
                for(int i = 0; i < array.count; i++)
                {
                    NSDictionary *dict = (NSDictionary *) array[i];
                    SecCertificateRef certRef = (__bridge SecCertificateRef)[dict valueForKey:(__bridge id)kSecValueRef];
                    if (certRef)
                    {
                        CFDataRef certDataRef = SecCertificateCopyData(certRef);
                        if (certDataRef)
                        {
                            const unsigned char *certBytes = (const unsigned char *) CFDataGetBytePtr(certDataRef);
                            long certBytesLen = (long) CFDataGetLength(certDataRef);
                            
                            // decode the DER encoded X509 data
                            X509 *certX509 = d2i_X509(NULL, &certBytes, certBytesLen);
                            if (certX509)
                            {
                                // add this certificate to the returned X509_STORE
                                X509_STORE_add_cert(returnValue, certX509);
                            }
                        }
                    }
                }
            }
        }
    }
    else
    {
        NSLog(@"Error: %s SetItemCopyMatching() returns error '%@'",
              __PRETTY_FUNCTION__,
              [ARDKOpenSSLKeychain SecAPI_errorToString:copyResult]);
    }
    
    if (queryResults)
    {
        CFRelease(queryResults);
    }

    return returnValue;
}

-(void) deleteItems:(NSString * _Nonnull) ofClass
{
    NSDictionary *deleteQuery = @{
        (__bridge id) kSecClass: ofClass
    };
    
    OSStatus deleteResult = SecItemDelete((__bridge CFDictionaryRef) deleteQuery);
    if (deleteResult != errSecSuccess)
    {
        NSLog(@"Error: %s SecItemDelete() returns error (%d) '%@'",
              __PRETTY_FUNCTION__,
              deleteResult,
              [ARDKOpenSSLKeychain SecAPI_errorToString:deleteResult]);
    }
}

-(void) dumpItems:(NSString * _Nonnull) ofClass
{
    NSLog(@"Keychain dump of all '%@' instances follows :", ofClass);
    
    NSDictionary *query = @{
        (__bridge id) kSecClass:            ofClass,
        
        (__bridge id) kSecReturnData:       (__bridge id) kCFBooleanTrue,
        (__bridge id) kSecReturnAttributes: (__bridge id) kCFBooleanTrue,
        (__bridge id) kSecReturnRef:        (__bridge id) kCFBooleanTrue,
        (__bridge id) kSecMatchLimit:       (__bridge id) kSecMatchLimitAll
    };
    
    CFTypeRef queryResults = NULL;
    OSStatus copyResult = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                              &queryResults);
    if (copyResult == errSecSuccess)
    {
        // we found a keychain entry, set the passcode
        if (queryResults)
        {
            CFShow(queryResults);
        }
    }
    else
    {
        NSLog(@"Error: %s SetItemCopyMatching() returns error '%@'",
              __PRETTY_FUNCTION__,
              [ARDKOpenSSLKeychain SecAPI_errorToString:copyResult]);
    }
    
    if (queryResults)
    {
        CFRelease(queryResults);
    }
}

@end
