// Copyright © 2018 Artifex Software Inc. All rights reserved.

#ifndef pdf_signer_h
#define pdf_signer_h

#include "mupdf/pdf.h"
#include "ARDKPKCS7.h"

pdf_pkcs7_signer *pdf_pkcs7_signer_create(fz_context *ctx, id<PKCS7Signer> objCSigner);

#endif /* pdf_signer_h */
