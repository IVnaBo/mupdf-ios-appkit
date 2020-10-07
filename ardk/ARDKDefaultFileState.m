//
//  FileState.m
//  smart-office-examples
//
//  Created by Paul Gardiner on 17/01/2017.
//  Copyright © 2017 Artifex. All rights reserved.
//

#import "ARDKDefaultFileState.h"

@implementation ARDKDefaultFileState
{
    ARDKDocType _docType;
}

@synthesize viewingStateInfo=_viewingStateInfo;

+ (NSString *)documentsPath
{
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                   NSUserDomainMask,
                                                   YES)[0];
}

+ (ARDKDefaultFileState *)fileStateForPath:(NSString *)path ofType:(ARDKDocType)type
{
    ARDKDefaultFileState *fileState = [[ARDKDefaultFileState alloc] init];
    fileState.docsRelativePath = path;
    fileState->_docType = type;
    return fileState;
}

- (BOOL)pathExists:(NSString *)path
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[ARDKDefaultFileState.documentsPath stringByAppendingPathComponent:path]];
}

- (NSString *)absoluteInternalPath
{
    return [ARDKDefaultFileState.documentsPath stringByAppendingPathComponent:self.docsRelativePath];
}

- (ARDKDocType)docType
{
    return _docType;
}

- (NSString *)displayPath
{
    return [@"Storage" stringByAppendingPathComponent:self.docsRelativePath];
}

- (BOOL)isReadonly
{
    return NO;
}

- (BOOL)requiresCopyBack
{
    return NO;
}

- (void)sessionDidLoadFirstPage:(ARDKDocSession *)session
{
}

- (void)sessionDidShowDoc:(ARDKDocSession *)session
{
}

- (void)sessionDidSaveDoc:(ARDKDocSession *)session
{
}

- (void)sessionRequestedCopyBackOnCompletion:(void (^)(BOOL))block
{
}

- (void)sessionDidClose
{
}

@end
