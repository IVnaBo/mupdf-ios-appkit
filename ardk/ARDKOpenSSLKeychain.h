//
//  ARDKOpenSSLKeychain.h
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#ifndef ARDK_OPENSSL_KEY_CHAIN_H
#define ARDK_OPENSSL_KEY_CHAIN_H

#import <UIKit/UIKit.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import <openssl/x509v3.h>
#pragma clang diagnostic pop

@interface ARDKOpenSSLKeychain : NSObject

// Converts the error code "value" returned from SecXXX() API calls
+(NSString * _Nonnull) SecAPI_errorToString:(OSStatus)value;

/// Performs a SQL like SELECT query on the iOS Keychain to recover attribute values from in
/// individual object or across all instances of a given object class. The values are returned
/// as an array of NSString or NSData objects.
///
/// @param key          the key whose value's were querying for e.g. kSecAttrDescription
/// @param fromClass    the class of Keychain object we're querying from e.g. kSecClassCertificate
/// @param whereKey     this is the key from a (key,value) pair used to narrow the search space.
///                     If 'whereKey' and/or 'equalsValue' are nil this method will return the values
///                     for 'key' from all object in the class 'fromClass', if 'whereKey' and 'equalsValue'
///                     are not-nil this method will return the values from 'key' from only those objects
///                     who's value for 'whereKey' equals its value for 'equalsValue'.
/// @param equalsValue  this is the key from a (key,value) pair used to narrow the search space.
///                     If 'whereKey' and/or 'equalsValue' are nil this method will return the values
///                     for 'key' from all object in the class 'fromClass', if 'whereKey' and 'equalsValue'
///                     are not-nil this method will return the values from 'key' from only those objects
///                     who's value for 'whereKey' equals its value for 'equalsValue'.
///
/// @return             an NSArray of NSString* or NSData* values copied from the objects
///                     that matched the query, this array will be empty if there were no matches
///
-(NSArray * _Nonnull) select:(NSString * _Nonnull) key
                   fromClass:(NSString * _Nonnull) fromClass
                    whereKey:(NSString * _Nullable) whereKey
                 equalsValue:(NSString * _Nullable) equalsValue;

/// Extracts and decodes the X509 certificate associated with an identity and retuns an X509 struct
/// of the decoded certificate to the caller. The caller is responsible for calling X509_free() on
/// the returned struct.
///
/// @param identityLabel   the "label" of the identity object we're geting the certificate info from
///
/// @return                An X509 struct containing the decoded certificate information from this identity,
///                        The caller is responsible for calling X509_free() on the returned struct.
///
-(X509 * _Nullable) getX509CertificateFromIdentity:(NSString * _Nonnull) identityLabel;

/// Extracts and decodes the private key associated with an identity and retuns an EVP_PKEY struct
/// of the decoded private key to the caller. The caller is responsible for calling EVP_PKEY_free() on
/// the returned struct.
///
/// @param identityLabel   the "label" of the identity object we're geting the certificate info from
///
/// @return                An EVP_KKEY struct containing the decoded private key from this identity,
///                        The caller is responsible for calling EVP_PKEY_free() on the returned struct.
///
-(EVP_PKEY * _Nullable) getPrivateKeyFromIdentity:(NSString * _Nonnull) identityLabel;

/// Returns an X509_STORE containing the currently trusted certificates. The caller is responsible for calling
/// X509_STORE_free() on the returned collection.
///
/// @return                A pointer to an X509_STORE containing all currently trusted certificates.
///                        The caller is responsible for calling X509_STORE_free() on the returned collection.
///
-(X509_STORE * _Nullable) getTrustedCertificates;

/// Deletes all items created by this app from the keychain where the item's class == "ofClass"
///
/// @param ofClass      the class of keychain object we wish to delete e.g. kClassCertificate
///
-(void) deleteItems:(NSString * _Nonnull)ofClass;

/// Dumps (to the log) details of all items created by this app in the keychain, where the
/// item's class == "ofClass"
///
/// @param ofClass    the class of keychain object we wish to deump e.g. (__bridge NSString *) kClassCertificate
///
-(void) dumpItems:(NSString * _Nonnull) ofClass;
                     
@end

#endif /* ARDK_OPENSSL_KEY_CHAIN_H */
