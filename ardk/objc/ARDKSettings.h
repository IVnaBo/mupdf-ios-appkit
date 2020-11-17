//  Copyright © 2017 Artifex Software Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import "ARDKSecureFS.h"

@interface ARDKSettings : NSObject

/// The location where temporary files are stored
///
/// Decrypted document content will be temporarily stored in this location,
/// particularly during the process of saving a document.
///
/// In a secure application, this should be a location within SecureFS.
///
/// The referenced directory should already exist and must be different from
/// directory that documents are stored in.
///
/// These settings should not be changed whilst the library is running.
///
/// If the library is used in read-only mode (no editing, no saving, no
/// pdf export) then this can be left as nil.
///
/// Note that if this is set to a location within SecureFS, any filenames passed
/// to openInHandler/openPdfInHandler/shareHandler will be inside SecureFS,
/// and hence cannot be directly passed to the iOS(macOS) open in / share
/// methods.
@property (copy) NSString * _Nullable temporaryPath;

@property (strong) id<ARDKSecureFS> _Nullable secureFs;

@end
