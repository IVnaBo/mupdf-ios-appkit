//
//  ARDKOpenSSLPKCS12Importer.h
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#ifndef ARDK_OPENSSL_PKCS12_IMPORTER_H
#define ARDK_OPENSSL_PKCS12_IMPORTER_H

#import <UIKit/UIKit.h>

@interface ARDKOpenSSLPKCS12Importer : NSObject

// Returns YES if url points to a PKCS12 file, otherwise returns NO
-(BOOL) isPKCS12File:(NSURL *) url;

// Imports the PKCS12File referred to by url into the application keychain,
// parentViewController is used by this method to present a UI dialog to
// prompt the user for the PKCSFile's password
-(void) importToKeychain:(NSURL *) url
    parentViewController:(UIViewController *)parentViewController;

@end

#endif /* ARDK_OPENSSL_PKCS12_IMPORTER_H */
