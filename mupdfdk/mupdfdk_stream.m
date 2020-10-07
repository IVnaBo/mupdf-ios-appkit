// Copyright © 2017 Artifex Software Inc. All rights reserved.

#include "mupdfdk_stream.h"

#define BUF_SIZE (4096)

@interface MuPDFDKStreamState : NSObject
@property(readonly) id<ARDKSecureFS_Handle> handle;
+ (MuPDFDKStreamState *)stateForHandle:(id<ARDKSecureFS_Handle>)handle;

@end

@implementation MuPDFDKStreamState
{
    @public

    unsigned char _buffer[BUF_SIZE];
}

- (instancetype)initWithHandle:(id<ARDKSecureFS_Handle>)handle
{
    self = [super init];
    if (self)
    {
        _handle = handle;
    }
    return self;
}

+ (MuPDFDKStreamState *)stateForHandle:(id<ARDKSecureFS_Handle>)handle
{
    return [[MuPDFDKStreamState alloc] initWithHandle:handle];
}

@end

static int mupdfdk_next(fz_context *ctx, fz_stream *stm, size_t max)
{
    MuPDFDKStreamState *state = (__bridge MuPDFDKStreamState *)stm->state;
    NSData *data = [state.handle ARDKSecureFS_readDataOfLength:BUF_SIZE];
    if (data.length == 0)
        return -1;

    unsigned char *buf = (unsigned char *)data.bytes;
    NSInteger len = data.length;
    memcpy(state->_buffer, buf, len);
    stm->rp = state->_buffer;
    stm->wp = stm->rp + len;
    stm->pos += len;

    return *stm->rp++;
}

static void mupdfdk_drop(fz_context *ctx, void *state)
{
    MuPDFDKStreamState *s = ((__bridge_transfer MuPDFDKStreamState *)state);
    [s.handle ARDKSecureFS_closeFile];
    // Since s was transfered in, returning from this function will release it
}

static void mupdfdk_drop_no_close(fz_context *ctx, void *state)
{
    (void)((__bridge_transfer MuPDFDKStreamState *)state);
    // Since state was transfered in, returning from this function will release it
}

static void mupdfdk_seek(fz_context *ctx, fz_stream *stm, int64_t offset, int whence)
{
    MuPDFDKStreamState *state = (__bridge MuPDFDKStreamState *)stm->state;
    int64_t pos = 0;

    switch (whence)
    {
        case SEEK_SET:
            [state.handle ARDKSecureFS_seekToFileOffset:offset];
            pos = offset;
            break;

        case SEEK_CUR:
        {
            int64_t cur = [state.handle ARDKSecureFS_offsetInFile];
            pos = cur + offset;
            [state.handle ARDKSecureFS_seekToFileOffset:pos];
            break;
        }

        case SEEK_END:
            [state.handle ARDKSecureFS_seekToEndOfFile];
            int64_t cur = [state.handle ARDKSecureFS_offsetInFile];
            pos = cur + offset;
            if (offset)
                [state.handle ARDKSecureFS_seekToFileOffset:cur + offset];
            break;
    }

    stm->pos = pos;
    stm->rp = stm->wp = state->_buffer;
}

static void mupdfdk_write(fz_context *ctx, void *opaque, const void *buffer, size_t count)
{
    MuPDFDKStreamState *state = (__bridge MuPDFDKStreamState *)opaque;

    [state.handle ARDKSecureFS_writeData:[NSData dataWithBytes:buffer length:count]];
}

static void mupdfdk_write_seek(fz_context *ctx, void *opaque, int64_t offset, int whence)
{
    MuPDFDKStreamState *state = (__bridge MuPDFDKStreamState *)opaque;

    switch (whence)
    {
        case SEEK_SET:
            [state.handle ARDKSecureFS_seekToFileOffset:offset];
            break;

        case SEEK_CUR:
        {
            int64_t cur = [state.handle ARDKSecureFS_offsetInFile];
            [state.handle ARDKSecureFS_seekToFileOffset:cur + offset];
            break;
        }

        case SEEK_END:
            [state.handle ARDKSecureFS_seekToEndOfFile];
            int64_t cur = [state.handle ARDKSecureFS_offsetInFile];
            if (offset)
                [state.handle ARDKSecureFS_seekToFileOffset:cur + offset];
            break;
    }
}

static int64_t mupdfdk_write_tell(fz_context *ctx, void *opaque)
{
    MuPDFDKStreamState *state = (__bridge MuPDFDKStreamState *)opaque;
    return [state.handle ARDKSecureFS_offsetInFile];
}

static fz_stream *as_stream(fz_context *ctx, void *opaque)
{
    MuPDFDKStreamState *state = (__bridge MuPDFDKStreamState *)opaque;
    fz_stream *stm = secure_stream(ctx, state.handle);
    stm->drop = mupdfdk_drop_no_close;
    return stm;
}

fz_stream *secure_stream(fz_context *ctx, id<ARDKSecureFS_Handle> handle)
{
    fz_stream *stm = fz_new_stream(ctx, (__bridge_retained void *)[MuPDFDKStreamState stateForHandle:handle], mupdfdk_next, mupdfdk_drop);
    stm->seek = mupdfdk_seek;
    return stm;
}

fz_output *secure_output(fz_context *ctx, id<ARDKSecureFS_Handle> handle)
{
    fz_output *op = fz_new_output(ctx, 8192, (__bridge_retained void *)[MuPDFDKStreamState stateForHandle:handle], mupdfdk_write, NULL, mupdfdk_drop);
    op->seek = mupdfdk_write_seek;
    op->tell = mupdfdk_write_tell;
    op->as_stream = as_stream;

    return op;
}
