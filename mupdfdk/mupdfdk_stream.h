// Copyright © 2017 Artifex Software Inc. All rights reserved.

#ifndef mupdfdk_stream_h
#define mupdfdk_stream_h

#include "mupdf/fitz.h"
#import "MuPDFDKLib.h"

fz_stream *secure_stream(fz_context *ctx, id<ARDKSecureFS_Handle> handle);

fz_output *secure_output(fz_context *ctx, id<ARDKSecureFS_Handle> handle);

#endif /* mupdfdk_stream_h */
