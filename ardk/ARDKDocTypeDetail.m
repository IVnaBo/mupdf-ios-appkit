//
//  ARDKDocTypeDetail.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 20/12/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "ARDKDocTypeDetail.h"

#define PDF_COLOR @"so.ui.doctype.pdf.color"
#define DOC_COLOR @"so.ui.doctype.doc.color"
#define XLS_COLOR @"so.ui.doctype.xls.color"
#define PPT_COLOR @"so.ui.doctype.ppt.color"
#define HWP_COLOR @"so.ui.doctype.hwp.color"
#define TXT_COLOR @"so.ui.doctype.txt.color"
#define IMG_COLOR @"so.ui.doctype.img.color"
#define CBZ_COLOR @"so.ui.doctype.cbz.color"
#define EPUB_COLOR @"so.ui.doctype.epub.color"
#define FB2_COLOR @"so.ui.doctype.fb2.color"
#define SVG_COLOR @"so.ui.doctype.svg.color"
#define XPS_COLOR @"so.ui.doctype.xps.color"

@implementation ARDKDocTypeDetail

+ (NSString *)docTypeIcon:(ARDKDocType)type
{
    switch (type)
    {
        case ARDKDocType_DOC:
            return @"explorer-doc";
        case ARDKDocType_DOCX:
            return @"explorer-docx";
        case ARDKDocType_PDF:
            return @"explorer-pdf";
        case ARDKDocType_XLS:
            return @"explorer-xls";
        case ARDKDocType_XLSX:
            return @"explorer-xlsx";
        case ARDKDocType_PPT:
            return @"explorer-ppt";
        case ARDKDocType_PPTX:
            return @"explorer-pptx";
        case ARDKDocType_HWP:
            return @"explorer-hangul";
        case ARDKDocType_TXT:
            return @"explorer-txt";
        case ARDKDocType_WMF:
        case ARDKDocType_EMF:
        case ARDKDocType_IMG:
            return @"explorer-image";

        case ARDKDocType_CSV:
            /* we currently don't support CSV */
            break;

        case ARDKDocType_CBZ:
            return @"explorer-cbz";
        case ARDKDocType_FB2:
            return @"explorer-fb2";
        case ARDKDocType_SVG:
            return @"explorer-svg";
        case ARDKDocType_XPS:
            return @"explorer-xps";
        case ARDKDocType_EPUB:
            return @"explorer-epub";

        case ARDKDocType_Other:
            break;
    }

    return @"explorer-doc";
}

+ (UIColor *)docTypeColor:(ARDKDocType)type
{
    NSString *col = DOC_COLOR;
    switch (type)
    {
        case ARDKDocType_DOC:
        case ARDKDocType_DOCX:
            col = DOC_COLOR;
            break;
        case ARDKDocType_PDF:
            col = PDF_COLOR;
            break;
        case ARDKDocType_XLS:
        case ARDKDocType_XLSX:
            col = XLS_COLOR;
            break;
        case ARDKDocType_PPT:
        case ARDKDocType_PPTX:
            col = PPT_COLOR;
            break;
        case ARDKDocType_HWP:
            col = HWP_COLOR;
            break;
        case ARDKDocType_TXT:
            col = TXT_COLOR;
            break;
        case ARDKDocType_IMG:
        case ARDKDocType_WMF:
        case ARDKDocType_EMF:
            col = IMG_COLOR;
            break;

        case ARDKDocType_CSV:
            /* we currently don't support CSV */
            break;

        case ARDKDocType_CBZ:
            col = CBZ_COLOR;
            break;
        case ARDKDocType_FB2:
            col = FB2_COLOR;
            break;
        case ARDKDocType_SVG:
            col = SVG_COLOR;
            break;
        case ARDKDocType_XPS:
            col = XPS_COLOR;
            break;
        case ARDKDocType_EPUB:
            col = EPUB_COLOR;
            break;

        case ARDKDocType_Other:
            break;
    }

    return [UIColor colorNamed:col inBundle:[NSBundle bundleForClass:self.class] compatibleWithTraitCollection:nil];
}

@end
