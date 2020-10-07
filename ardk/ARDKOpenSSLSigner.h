//
//  ARDKOpenSSLSigner.h
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#ifndef ARDKOpenSSLSigner_h
#define ARDKOpenSSLSigner_h

#import "ARDKMutableSigner.h"

@interface ARDKOpenSSLSigner : ARDKMutableSigner
// The index (from the list all availiable certificates) of the currently selected
// certificate for this signer object, -1 means no certificate selected
@property NSInteger selectedCertificateIndex;

// Returns the number of available certificates known to this object
-(NSInteger) numCertificates;
@end

#endif /* ARDKOpenSSLSigner_h */
