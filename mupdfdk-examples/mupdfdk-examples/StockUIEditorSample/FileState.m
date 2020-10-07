//
//  FileState.m
//  smart-office-examples
//
//  Created by Paul Gardiner on 17/01/2017.
//  Copyright © 2017 Artifex. All rights reserved.
//

#import "FileState.h"
#import "SecureFS.h"

@interface FileState ()
@property NSString *docsRelativePath;
@end

@implementation FileState

@synthesize viewingStateInfo=_viewingStateInfo;

+ (NSString *)documentsPath
{
    return [SecureFS docsPath];
}

+ (FileState *)fileStateForPath:(NSString *)path
{
    FileState *fileState = [[FileState alloc] init];
    fileState.docsRelativePath = path;
    return fileState;
}

- (void)setPath:(NSString *)newPath
{
    self.docsRelativePath = newPath;
}

- (NSString *)absoluteInternalPath
{
    return [[FileState documentsPath] stringByAppendingPathComponent:self.docsRelativePath];
}

- (ARDKDocType)docType
{
    return [MuPDFDKDoc docTypeFromFileExtension:self.docsRelativePath];
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
