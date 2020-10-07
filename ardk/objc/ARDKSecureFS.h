// Secure File System interface
//
// This file allows SmartOffice to read and write files without the files
// ever being present on the device file system in an unencrypted form.
//
// An example implementation is provided that does not provide any encryption,
// the integrator should implement whatever encryption they desire.

/// Protocol that must be implemented by secure file handles
///
/// The properties/methods mirror those of NSFileHandle and should have the
/// same behaviour of NSFileHandle, except they should encrypt any data
/// before it is stored.

#import <Foundation/Foundation.h>

@protocol ARDKSecureFS_Handle

@property (readonly) unsigned long long ARDKSecureFS_offsetInFile;

- (NSData *)ARDKSecureFS_readDataOfLength:(NSUInteger)length;

- (void)ARDKSecureFS_writeData:(NSData *)data;

- (void)ARDKSecureFS_seekToFileOffset:(unsigned long long)offset;

- (void)ARDKSecureFS_truncateFileAtOffset:(unsigned long long)offset;

- (void)ARDKSecureFS_synchronizeFile;

- (void)ARDKSecureFS_closeFile;

- (unsigned long long)ARDKSecureFS_seekToEndOfFile;

@end


/// Protocol that object that provides SecureFS must implement
///
/// Behaviour of the methods should match equivalents in NSFileHandle /
/// NSFileManager, except the desired encryption should be applied before
/// reading/writing.
@protocol ARDKSecureFS <NSObject>

- (BOOL)ARDKSecureFS_isSecure:(NSString *)path;

- (BOOL)ARDKSecureFS_fileRename:(NSString *)src to:(NSString *)dst;

- (BOOL)ARDKSecureFS_fileCopy:(NSString *)src to:(NSString *)dst;

/// Deletes a file or directory
- (BOOL)ARDKSecureFS_fileDelete:(NSString *)path;

- (BOOL)ARDKSecureFS_fileExists:(NSString *)path;

- (BOOL)ARDKSecureFS_isWritableFileAtPath:(NSString *)path;

- (BOOL)ARDKSecureFS_createFileAtPath:(NSString *)path;

- (id<ARDKSecureFS_Handle>)ARDKSecureFS_fileHandleForReadingAtPath:(NSString *)path;
- (id<ARDKSecureFS_Handle>)ARDKSecureFS_fileHandleForWritingAtPath:(NSString *)path;
- (id<ARDKSecureFS_Handle>)ARDKSecureFS_fileHandleForUpdatingAtPath:(NSString *)path;

/// Retrieve file attributes
///
/// Returned dictionary should include the keys:
///   NSFileModificationDate
///   NSFileType
///   NSFileSize
- (NSDictionary<NSString *, id> *)ARDKSecureFS_attributesOfItemAtPath:(NSString *)path;

/// Creates a directory at the specified path
- (BOOL)ARDKSecureFS_createDirectoryAtPath:(NSString *)path
               withIntermediateDirectories:(BOOL) withIntermediateDirectories;

/// Performs a search of the specified directory and returns the paths of any
/// contained items
- (NSArray <NSString *> *)ARDKSecureFS_contentsOfDirAtPath:(NSString *)path;

@end

