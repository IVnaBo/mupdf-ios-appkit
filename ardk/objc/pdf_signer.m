// Copyright © 2018 Artifex Software Inc. All rights reserved.

#import <Foundation/Foundation.h>
#include "pdf_signer.h"

#define BUF_LEN (4096)
#define SAFETY_NET (100)

typedef struct
{
    pdf_pkcs7_signer base;
    fz_context *ctx;
    int refs;
    void *objCSigner;
} signer_internal;

static pdf_pkcs7_signer *signer_keep(fz_context *ctx, pdf_pkcs7_signer *signer)
{
    ++((signer_internal*)signer)->refs;
    return signer;
}

static void signer_destroy(pdf_pkcs7_signer *signer)
{
    signer_internal *isigner = (signer_internal *)signer;
    if (isigner)
    {
        (void)(__bridge_transfer id<PKCS7Signer>)isigner->objCSigner;
    }
}

static void signer_drop(fz_context *ctx, pdf_pkcs7_signer *signer)
{
    if (--((signer_internal*)signer)->refs <= 0)
        signer_destroy(signer);
}

static pdf_pkcs7_designated_name *signer_designated_name(fz_context *ctx, pdf_pkcs7_signer *signer)
{
    signer_internal *isigner = (signer_internal *)signer;
    pdf_pkcs7_designated_name *name = calloc(1, sizeof(*name));
    if (name == NULL)
        return NULL;

    @autoreleasepool
    {
        id<PKCS7Signer> objCSigner = (__bridge id<PKCS7Signer>)isigner->objCSigner;
        id<PKCS7DesignatedName> objCname = [objCSigner name];
        name->cn = strdup(objCname.cn.UTF8String);
        name->o = strdup(objCname.o.UTF8String);
        name->ou = strdup(objCname.ou.UTF8String);
        name->email = strdup(objCname.email.UTF8String);
        name->c = strdup(objCname.c.UTF8String);
   }

    return name;
}

static size_t signer_max_digest_size(fz_context *ctx, pdf_pkcs7_signer *signer)
{
    signer_internal *isigner = (signer_internal *)signer;
    size_t res = 0;
    @autoreleasepool
    {
        id<PKCS7Signer> objCSigner = (__bridge id<PKCS7Signer>)isigner->objCSigner;
        [objCSigner begin];

        NSData *digestData = [objCSigner sign];
        res = digestData.length;
    }

    return res + SAFETY_NET;
}

static int signer_create_digest(fz_context *ctx, pdf_pkcs7_signer *signer, fz_stream *in, unsigned char *digest, size_t digest_len)
{
    signer_internal *isigner = (signer_internal *)signer;
    int res = 0;
    @autoreleasepool
    {
        id<PKCS7Signer> objCSigner = (__bridge id<PKCS7Signer>)isigner->objCSigner;
        [objCSigner begin];
        for (;;)
        {
            NSMutableData *data = [NSMutableData dataWithLength:BUF_LEN];
            size_t n = 0;
            fz_try(ctx)
            {
                n = fz_read(ctx, in, data.mutableBytes, BUF_LEN);
                data.length = n;
            }
            fz_catch(ctx)
            {
            }

            if (n > 0)
                [objCSigner data:data];
            else
                break;
        }
        NSData *digestData = [objCSigner sign];
        if (digestData.length <= digest_len)
        {
            memcpy(digest, digestData.bytes, digestData.length);
            res = (int)digestData.length;
        }
    }

    return res;
}

pdf_pkcs7_signer *pdf_pkcs7_signer_create(fz_context *ctx, id<PKCS7Signer> objCSigner)
{
    signer_internal *signer = calloc(1, sizeof(*signer));
    if (signer == NULL)
        return NULL;

    signer->base.keep = signer_keep;
    signer->base.drop = signer_drop;
    signer->base.get_signing_name = signer_designated_name;
    signer->base.max_digest_size = signer_max_digest_size;
    signer->base.create_digest = signer_create_digest;
    signer->ctx = ctx;
    signer->refs = 1;
    signer->objCSigner = (__bridge_retained void *)objCSigner;

    return &signer->base;
}
