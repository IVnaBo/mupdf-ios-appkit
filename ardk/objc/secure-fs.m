/**
 * iOS Wrapper for the SmartOffice Library secure fs API
 *
 * Maps the library's securefs API into a much more iOS-like ObjC API that
 * should be easier for customers to implement.
 *
 * Copyright (C) Artifex, 2012-2016. All Rights Reserved.
 *
 * @author Artifex
 */
#import <Foundation/Foundation.h>
#import <stdint.h>

#import "SODKLib.h"
#import "sol-secure-fs.h"

#ifdef SECURE_FS_DEBUG_VERBOSE
#define DBUGFV(x) NSLog x
#define DBUGF(x) NSLog x
#elif defined(SECURE_FS_DEBUG)
#define DBUGFV(x)
#define DBUGF(x) NSLog x
#else /* SECURE_FS_DEBUG */
#define DBUGFV(x)
#define DBUGF(x)
#endif /* SECURE_FS_DEBUG */

int SecureFs_isSecurePath(const char *path)
{
    @autoreleasepool
    {
        int   result     = 0;
        id<ARDKSecureFS> secureFS = [SODKLib secureFS];

        result = [secureFS ARDKSecureFS_isSecure:@(path)];

        DBUGFV((@"[ARDKSecureFS_isSecure:%s returned %s",
              path, result ? "YES" : "NO"));

        return result;
    }
}

int SecureFs_getFileProperties(const char              *path,
                               SecureFs_FileProperties *properties)
{
    @autoreleasepool
    {
        NSString           *stringPath;
        NSDictionary       *attributes  = NULL;
        NSDate             *date;
        id<ARDKSecureFS> secureFS = [SODKLib secureFS];
        unsigned long long  fileSize;

        if (path == NULL || properties == NULL)
            return -1;

        stringPath = @(path);
        if (stringPath == nil)
            return -1;

        attributes = [secureFS ARDKSecureFS_attributesOfItemAtPath:stringPath];
        if (attributes == nil)
        {
            return -1;
        }
        DBUGFV((@"ARDKSecureFS_attributesOfItemAtPath:%s returned %@", path, attributes));

        date     = attributes[NSFileModificationDate];
        fileSize = [attributes[NSFileSize] unsignedLongLongValue];

        properties->size             = (unsigned long)fileSize;
        properties->modificationDate = (unsigned long)[date timeIntervalSince1970];
        properties->accessDate       = 0;
        properties->creationDate     = 0;
        properties->attrib           = 0;

        if ([attributes[NSFileType] isEqualToString:NSFileTypeDirectory])
            properties->attrib |= SecureFs_FileAttrib_Dir;

        if (![secureFS ARDKSecureFS_isWritableFileAtPath:stringPath])
            properties->attrib |= SecureFs_FileAttrib_ReadOnly;

        return 0;
    }
}

int SecureFs_fileRename(const char *src,
                        const char *dst)
{
    @autoreleasepool
    {
        NSString      *stringSrc;
        NSString      *stringDst;
        int            result = 0;
        id<ARDKSecureFS> secureFS = [SODKLib secureFS];

        if (src == NULL || dst == NULL)
            return -1;

        stringSrc   = @(src);
        stringDst   = @(dst);
        if (stringSrc == nil || stringDst == nil)
            return -1;

        if ([secureFS ARDKSecureFS_fileExists:stringSrc])
        {
            /* we expect rename to be able to overwrite the destination file, but
             * iOS's expects not to, so delete the destination first */
            if ([secureFS ARDKSecureFS_fileExists:stringDst])
            {
                [secureFS ARDKSecureFS_fileDelete:stringDst];
            }
            if (![secureFS ARDKSecureFS_fileRename:stringSrc to:stringDst])
            {
                /* failed */
                result = -1;
            }
        }
        else
        {
            result = -1;
        }
        DBUGF((@"ARDKSecureFS_fileRename:%s to:%s returned %d", src, dst, result));

        return result;
    }
}

int SecureFs_fileCopy(const char *src,
                      const char *dst)
{
    @autoreleasepool
    {
        NSString      *stringSrc;
        NSString      *stringDst;
        int            result = 0;
        id<ARDKSecureFS> secureFS = [SODKLib secureFS];


        if (src == NULL || dst == NULL)
            return -1;

        stringSrc   = @(src);
        stringDst   = @(dst);
        if (stringSrc == nil || stringDst == nil)
            return -1;

        if (![secureFS ARDKSecureFS_fileCopy:stringSrc to:stringDst])
        {
            /* failed */
            result = -1;
        }
        DBUGF((@"ARDKSecureFS_fileCopy:%s to:%s returned %d", src, dst, result));

        return result;
    }
}

int SecureFs_fileDelete(const char *path)
{
    @autoreleasepool
    {
        NSString      *stringPath;
        id<ARDKSecureFS> secureFS = [SODKLib secureFS];
        int            result = 0;

        DBUGF((@"SecureFs_fileDelete(%s)", path));

        if (path == NULL)
            return -1;

        stringPath  = @(path);
        if (stringPath == nil)
            return -1;

        if (![secureFS ARDKSecureFS_fileDelete:stringPath])
        {
            /* failed */
            result = -1;
        }

        return result;
    }
}

int SecureFs_fileExists(const char *path)
{
    @autoreleasepool
    {
        NSString      *stringPath;
        BOOL            result;

        id<ARDKSecureFS> secureFS = [SODKLib secureFS];

        if (path == NULL)
            return 0;

        stringPath  = @(path);
        if (stringPath == nil)
            return 0;

        result = [secureFS ARDKSecureFS_fileExists:stringPath];

        DBUGFV((@"SOSecureFs_fileExists:%s returned %s",
               path, result ? "YES" : "NO"));

        return result;
    }
}

SecureFs_FileHandle *SecureFs_fileOpen(const char        *path,
                                       SecureFs_FileMode  mode)
{
    @autoreleasepool
    {
        id<ARDKSecureFS_Handle> handle = nil;
        NSString      *stringPath;
        SecureFs_FileHandle *sfh;
        id<ARDKSecureFS> secureFS = [SODKLib secureFS];

        if (path == NULL)
            return NULL;

        stringPath = @(path);
        if (stringPath == nil)
            return NULL;

        /* Create the file if required */
        if (0 == SecureFs_fileExists(path))
        {
            if ((mode & SecureFs_FileMode_Create) == 0)
                return NULL;

            if (![secureFS ARDKSecureFS_createFileAtPath:stringPath])
                return NULL;
        }

        /* Open the file */
        if ((mode & SecureFs_FileMode_ReadOnly) != 0)
        {
            handle = [secureFS ARDKSecureFS_fileHandleForReadingAtPath:stringPath];
            DBUGF((@"ARDKSecureFS_fileHandleForReadingAtPath:%s return %@", path, handle));
        }
        else if ((mode & SecureFs_FileMode_WriteOnly) != 0)
        {
            handle = [secureFS ARDKSecureFS_fileHandleForWritingAtPath:stringPath];
            DBUGF((@"ARDKSecureFS_fileHandleForWritingAtPath:%s return %@", path, handle));
        }
        else if ((mode & SecureFs_FileMode_ReadWrite) != 0)
        {
            handle = [secureFS ARDKSecureFS_fileHandleForUpdatingAtPath:stringPath];
            DBUGF((@"ARDKSecureFS_fileHandleForUpdatingAtPath:%s return %@", path, handle));
        }

        if (handle && (mode & SecureFs_FileMode_Truncate))
        {
            [handle ARDKSecureFS_truncateFileAtOffset:0];
        }

        sfh = (__bridge_retained SecureFs_FileHandle *)handle;
        return sfh;
    }
}

int SecureFs_fileClose(SecureFs_FileHandle *fileHandle)
{
    @autoreleasepool
    {
       id<ARDKSecureFS_Handle> handle = (__bridge_transfer id<ARDKSecureFS_Handle>)fileHandle;

        DBUGFV((@"ARDKSecureFS_Handle deallocate [%@]", handle));

        if (handle == nil)
            return -1;

        [handle ARDKSecureFS_closeFile];

        return 0;
    }
}

int64_t SecureFs_fileRead(SecureFs_FileHandle *fileHandle,
                          void                *buffer,
                          uint64_t             count)
{
    @autoreleasepool
    {
        id<ARDKSecureFS_Handle> handle = (__bridge id<ARDKSecureFS_Handle>)fileHandle;
        NSData       *data;

        if (handle == nil || buffer == NULL || count == 0)
            return -1;

        /* Read the data to an NSData object, and then memcpy it into the supplied
         * buffer */
        data = [handle ARDKSecureFS_readDataOfLength:(NSUInteger)count];
        DBUGFV((@"ARDKSecureFS_readDataOfLength:%qu [%@]", count, handle));
        if (data == nil)
            return -1;

        memcpy(buffer, data.bytes, [data length]);
        return [data length];
    }
}

int64_t SecureFs_fileWrite(SecureFs_FileHandle *fileHandle,
                           const void          *buffer,
                           uint64_t             count)
{
    @autoreleasepool
    {
        id<ARDKSecureFS_Handle> handle = (__bridge id<ARDKSecureFS_Handle>)fileHandle;
        NSData       *data;

        if (handle == nil || buffer == NULL || count == 0)
            return -1;

        /* Copy the data into an NSData object, and then write that out to the file */
        data = [NSData dataWithBytes:buffer length:(NSUInteger)count];
        if (data == nil)
            return -1;

        [handle ARDKSecureFS_writeData:data];
        DBUGFV((@"ARDKSecureFS_writeData %qu bytes [%@]", count, handle));
        return count;
    }
}

int64_t SecureFs_fileSeek(SecureFs_FileHandle *fileHandle,
                          int64_t              offset,
                          SecureFs_SeekOrigin  origin)
{
    @autoreleasepool
    {
        id<ARDKSecureFS_Handle> handle = (__bridge id<ARDKSecureFS_Handle>)fileHandle;
        unsigned long long  newOffset;

        if (handle == nil)
            return -1;

        switch (origin)
        {
            case SecureFs_SeekOrigin_Set:
                newOffset = offset;
                break;

            case SecureFs_SeekOrigin_Cur:
                newOffset = offset + [handle ARDKSecureFS_offsetInFile];
                break;

            case SecureFs_SeekOrigin_End:
                newOffset = offset + SecureFs_fileSize(fileHandle);
                break;

            default:
                return -1;
        }

        [handle ARDKSecureFS_seekToFileOffset:newOffset];

        DBUGFV((@"ARDKSecureFS_seekToFileOffset:%qu [%@]", newOffset, handle));

        return (long)newOffset;
    }
}

int SecureFs_fileFlush(SecureFs_FileHandle *fileHandle)
{
    @autoreleasepool
    {
        id<ARDKSecureFS_Handle> handle = (__bridge id<ARDKSecureFS_Handle>)fileHandle;

        DBUGFV((@"ARDKSecureFS_synchronizeFile [%@]", handle));

        if (handle == nil)
            return -1;

        [handle ARDKSecureFS_synchronizeFile];
        return 0;
    }
}

int SecureFs_fileTruncate(SecureFs_FileHandle *fileHandle,
                          uint64_t             size)
{
    @autoreleasepool
    {
       id<ARDKSecureFS_Handle> handle = (__bridge id<ARDKSecureFS_Handle>)fileHandle;

        DBUGFV((@"ARDKSecureFS_truncateFileAtOffset:%qu [%@] ", size, handle));

        if (handle == nil)
            return -1;

        [handle ARDKSecureFS_truncateFileAtOffset:size];
        return 0;
    }
}

uint64_t SecureFs_fileSize(SecureFs_FileHandle *fileHandle)
{
    @autoreleasepool
    {
        id<ARDKSecureFS_Handle> handle = (__bridge id<ARDKSecureFS_Handle>)fileHandle;
        unsigned long long  offset;
        unsigned long long  len;

        if (handle == nil)
            return 0;

        /* Remember where we were */
        offset = [handle ARDKSecureFS_offsetInFile];

        /* Seek to the end of the file to get the offset (file size) */
        len = [handle ARDKSecureFS_seekToEndOfFile];

        DBUGFV((@"ARDKSecureFS_seekToEndOfFile returned %qu [%@]", len, handle));

        /* Now seek back to the original position */
        [handle ARDKSecureFS_seekToFileOffset:offset];

        return len;
    }
}
