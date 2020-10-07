//
//  FileState.h
//  smart-office-examples
//
//  Created by Paul Gardiner on 17/01/2017.
//  Copyright © 2017 Artifex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <mupdfdk/mupdfdk.h>

/// To use MuPDFDK an app is required to create an implementation
/// of the ARDKFileState protocol. This is a simple example

@interface FileState : NSObject<ARDKFileState>

/// Create a file-state object for a path relative to the
/// Documents folder
+ (FileState *)fileStateForPath:(NSString *)path;

/// Set the path to a new string. There is no requirement to
/// have a method to change the path. This is here because
/// changing the path is how we choose to handle the user tapping
/// the "save as" icon
- (void)setPath:(NSString *)newPath;

@end
