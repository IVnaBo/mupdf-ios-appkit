//
//  ARDKDefaultFileState.h
//  smart-office-examples
//
//  Created by Paul Gardiner on 17/01/2017.
//  Copyright © 2017 Artifex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKFileState.h"

/// This is a simple FileState implementation which can be used
/// for simple cases where no copyback is required, and no
/// SecureFS support
@interface ARDKDefaultFileState : NSObject<ARDKFileState>
@property NSString *docsRelativePath;

/// Create a file-state object for a path relative to the
/// Documents folder
+ (ARDKDefaultFileState *)fileStateForPath:(NSString *)path ofType:(ARDKDocType)type;

- (BOOL)pathExists:(NSString *)path;

@end
