/// Example implementation of SecureFS API
///
/// This implementation does not do any encryption, the implementations in
/// this file should be replaced routines that access your encrypted file
/// system.
///
/// Alternatively, if you do not need any encryption, you can remove this
/// file and pass a nil SecureFS object to the library.

#import <mupdfdk/mupdfdk.h>
#import "SecureFS.h"

@interface SecureHandle : NSObject <ARDKSecureFS_Handle>
{
    NSFileHandle *_fh;
}
@end

@implementation SecureHandle

- (instancetype)initWithFileHandle:(NSFileHandle *)fh
{
    self = [super init];
    if (self)
    {
        _fh = fh;
    }
    return self;
}

- (NSData *)ARDKSecureFS_readDataOfLength:(NSUInteger)length
{
    return [_fh readDataOfLength:length];
}

- (void)ARDKSecureFS_writeData:(NSData *)data
{
    [_fh writeData:data];
}

- (void)ARDKSecureFS_seekToFileOffset:(unsigned long long)offset
{
    [_fh seekToFileOffset:offset];
}

- (void)ARDKSecureFS_truncateFileAtOffset:(unsigned long long)offset
{
    [_fh truncateFileAtOffset:offset];
}

- (void)ARDKSecureFS_synchronizeFile
{
    [_fh synchronizeFile];
}

- (unsigned long long)ARDKSecureFS_seekToEndOfFile
{
    return [_fh seekToEndOfFile];
}

- (unsigned long long)ARDKSecureFS_offsetInFile
{
    return _fh.offsetInFile;
}

- (void)ARDKSecureFS_closeFile
{
    [_fh closeFile];
}

@end


@implementation SecureFS

/// Temporary path passed
///
/// These paths do not need to actually exist on disk
/// When the document view tries to open these paths, we map them to the actual
/// locations on disk.
+ (NSString *)temporaryPath
{
    return @"/SECURETMP";
}

+ (NSString *)docsPath
{
    return @"/SECUREDOCS";
}

/// The actual filesystem location we store temporary files
+ (NSString *)realTemporaryPath
{
    NSString *docsPath;
    BOOL result;

    docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                   NSUserDomainMask,
                                                   YES)[0];

    NSString *tempPath = [docsPath stringByAppendingPathComponent:@"MuPDFDKLibTmp"];

    result = [[NSFileManager defaultManager] createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:nil];
    if (!result)
        return nil;

    return tempPath;
}

/// The actual filesystem location we store documents
+ (NSString *)realDocsPath
{
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                               NSUserDomainMask,
                                               YES)[0];

}

/// Accepts a path that means something to the document view and returns the
/// underlying file system path that matches.
- (NSString *)mapPath:(NSString *)path
{
    path = [path stringByReplacingOccurrencesOfString:[self.class temporaryPath]
                                           withString:[self.class realTemporaryPath]];
    path = [path stringByReplacingOccurrencesOfString:[self.class docsPath]
                                           withString:[self.class realDocsPath]];

    return path;
}

- (BOOL)ARDKSecureFS_isSecure:(NSString *)path
{
    return [path hasPrefix:[self.class temporaryPath]] ||
           [path hasPrefix:[self.class docsPath]];
}


- (NSDictionary<NSString *, id> *)ARDKSecureFS_attributesOfItemAtPath:(NSString *)path
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSDictionary<NSString *,id> *attributes;

    if (fileManager == nil)
        return nil;

    attributes = [fileManager attributesOfItemAtPath:[self mapPath:path] error:nil];

    return attributes;
}

- (BOOL)ARDKSecureFS_fileRename:(NSString *)src to:(NSString *)dst
{
    BOOL ret;
    NSError *e = nil;
    NSFileManager *fileManager = [[NSFileManager alloc] init];

    if (fileManager == nil)
        return NO;

    ret = [fileManager moveItemAtPath:[self mapPath:src] toPath:[self mapPath:dst] error:&e];
    if (!ret)
    {
        NSLog(@"Rename error: %@\n", e);
    }
    return ret;
}


- (BOOL)ARDKSecureFS_fileCopy:(NSString *)src to:(NSString *)dst
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];

    if (fileManager == nil)
        return NO;

    return [fileManager copyItemAtPath:[self mapPath:src] toPath:[self mapPath:dst] error:NULL];
}

- (BOOL)ARDKSecureFS_fileDelete:(NSString *)path
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];

    return [fileManager removeItemAtPath:[self mapPath:path] error:nil];
}

- (BOOL)ARDKSecureFS_fileExists:(NSString *)path
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];

    if (fileManager == nil)
        return NO;

    return [fileManager fileExistsAtPath:[self mapPath:path] isDirectory:NULL];
}

- (BOOL)ARDKSecureFS_isWritableFileAtPath:(NSString *)path
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];

    if (fileManager == nil)
        return NO;

    return [fileManager isWritableFileAtPath:[self mapPath:path]];
}

- (BOOL)ARDKSecureFS_createFileAtPath:(NSString *)path
{
    NSFileManager *fileManager = [[NSFileManager alloc] init];

    return [fileManager createFileAtPath:[self mapPath:path] contents:nil attributes:nil];
}

- (id<ARDKSecureFS_Handle>)ARDKSecureFS_fileHandleForReadingAtPath:(NSString *)path
{
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:[self mapPath:path]];

    if (!fh)
        return nil;

    return [[SecureHandle alloc] initWithFileHandle:fh];
}

- (id<ARDKSecureFS_Handle>)ARDKSecureFS_fileHandleForWritingAtPath:(NSString *)path
{
    NSError *error;
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingToURL:[NSURL fileURLWithPath:[self mapPath:path]] error:&error];


    if (!fh)
    {
        NSLog(@"Creating %@ in SecureFS failed: %@", path, error);
        return nil;
    }

    return [[SecureHandle alloc] initWithFileHandle:fh];
}

- (id<ARDKSecureFS_Handle>)ARDKSecureFS_fileHandleForUpdatingAtPath:(NSString *)path
{
    NSFileHandle *fh = [NSFileHandle fileHandleForUpdatingAtPath:[self mapPath:path]];

    if (!fh)
        return nil;

    return [[SecureHandle alloc] initWithFileHandle:fh];
}

@end
