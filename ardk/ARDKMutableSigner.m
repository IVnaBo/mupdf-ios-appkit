//
//  ARDKMutableSigner.m
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#import "ARDKMutableSigner.h"

@implementation ARDKMutableSigner
@synthesize selectedCertificateIndex;

-(NSInteger) numCertificates
{
    assert("Must be defined in derived class" == NULL);
    return 0;
}

- (void)begin
{
    assert("Must be defined in derived class" == NULL);
}

- (void)data:(NSData *)data
{
    assert("Must be defined in derived class" == NULL);
}

- (NSData *)sign
{
    assert("Must be defined in derived class" == NULL);
    return nil;
}

- (id<PKCS7DesignatedName>)name
{
    assert("Must be defined in derived class" == NULL);
    return nil;
}

- (NSDictionary *)description
{
    assert("Must be defined in derived class" == NULL);
    return nil;
}
@end
