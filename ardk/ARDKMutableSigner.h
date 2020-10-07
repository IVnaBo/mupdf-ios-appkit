//
//  ARDKMutableSigner.h
//  smart-office-nui
//
//  Copyright © 2020 Artifex Software Inc. All rights reserved.
//

#ifndef ARDKMutableSigner_h
#define ARDKMutableSigner_h

#import "ARDKPKCS7.h"

@interface ARDKMutableSigner : NSObject <PKCS7Signer>
// The index (from the list all availiable certificates) of the currently selected
// certificate for this signer object, -1 means no certificate selected
@property NSInteger selectedCertificateIndex;

// Returns the number of available certificates known to this object
-(NSInteger) numCertificates;
@end

#endif /* ARDKMutableSigner_h */
