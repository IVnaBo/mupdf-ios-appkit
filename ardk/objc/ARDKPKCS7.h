// Copyright © 2018 Artifex Software Inc. All rights reserved.

#ifndef ARDKPKCS7_h
#define ARDKPKCS7_h

#import <Foundation/Foundation.h>

typedef enum
{
    PKCS7VerifyResult_Okay,
    PKCS7VerifyResult_No_Signature,
    PKCS7VerifyResult_No_Certificate,
    PKCS7VerifyResult_DigestFailure,
    PKCS7VerifyResult_SelfSigned,
    PKCS7VerifyResult_SelfSignedInChain,
    PKCS7VerifyResult_NotTrusted,
    PKCS7VerifyResult_Unknown,
} PKCS7VerifyResult;

@protocol PKCS7DesignatedName <NSObject>
@property(nonatomic, retain) NSString *cn;
@property(nonatomic, retain) NSString *o;
@property(nonatomic, retain) NSString *ou;
@property(nonatomic, retain) NSString *email;
@property(nonatomic, retain) NSString *c;
@end

@protocol PKCS7Description <NSObject>
@property(nonatomic, retain) NSString *issuer;
@property(nonatomic, retain) NSString *subject;
@property(nonatomic, retain) NSString *subjectAlt;
@property(nonatomic, retain) NSString *serial;
@property(nonatomic, retain) NSString *notValidBefore;
@property(nonatomic, retain) NSString *notValidAfter;
@property(nonatomic, retain) NSSet    *keyUsage;
@property(nonatomic, retain) NSSet    *extKeyUsage;
@end

@protocol PKCS7Signer <NSObject>

// Get the signers designated name
- (id<PKCS7DesignatedName>)name;

// Get the signers certificate description
- (id<PKCS7Description>)description;

// Announce the start of a signing request before sending the data to sign
- (void)begin;

// Send a chunk of the data to be signed (may be called repeatedly)
- (void)data:(NSData *)data;

// Announce the end of the data and request the signature
- (NSData *)sign;

@end

@protocol PKCS7Verifier <NSObject>

// Announce the start of a verification request before sending the data
- (void)begin;

// Send a chunk of the data on which a signature is to be verified
- (void)data:(NSData *)data;

// Announce the end of the data and request verification of the signature
- (PKCS7VerifyResult)verify:(NSData *)signature;

// Get the signers designated name from the signature
- (id<PKCS7DesignatedName>)name:(NSData *)signature;

// Get the signers certificate description from the signature
- (id<PKCS7Description>)description:(NSData *)signature;

@end

#endif /* ARDKPKCS7_h */
