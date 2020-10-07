//
//  ARDKDocumentSettings.m
//  smart-office-nui
//
//  Created by Joseph Heenan on 09/01/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKDocumentSettings.h"

@implementation ARDKDocumentSettings

static NSString *const keyForSaveButtonEnabled        = @"keyForSaveButtonEnabled";
static NSString *const keyForEditingEnabled           = @"keyForEditingEnabled";
static NSString *const keyForPrintingEnabled          = @"keyForPrintingEnabled";
static NSString *const keyForSecurePrintingEnabled    = @"keyForSecurePrintingEnabled";
static NSString *const keyForInsertFromCameraEnabled  = @"keyForInsertFromCameraEnabled";
static NSString *const keyForInsertFromPhotosEnabled  = @"keyForInsertFromPhotosEnabled";
static NSString *const keyForPdfAnnotationsEnabled    = @"keyForPdfAnnotationsEnabled";
static NSString *const keyForPdfRedactionEnabled      = @"keyForPdfRedactionEnabled";
static NSString *const keyForPdfFormFillingEnabled    = @"keyForPdfFormFillingEnabled";
static NSString *const keyForPdfFormSigningEnabled    = @"keyForPdfFormSigningEnabled";
static NSString *const keyForPdfSignatureFieldCreationEnabled = @"keyForPdfSignatureFieldCreationEnabled";
static NSString *const keyForFullScreenModeEnabled    = @"keyForFullScreenModeEnabled";
static NSString *const keyForPpdfFormFillingAvailable = @"keyForPpdfFormFillingAvailable";
static NSString *const keyForPdfRedactionAvailable    = @"keyForPdfRedactionAvailable";
static NSString *const keyForExpiresDate              = @"keyForExpiresDate";


- (void)enableAll:(BOOL)enable
{
    _saveButtonEnabled = enable;
    _saveToButtonEnabled = enable;
    _editingEnabled = enable;
    _printingEnabled = enable;
    _securePrintingEnabled = enable;
    _insertFromCameraEnabled = enable;
    _insertFromPhotosEnabled = enable;
    _pdfAnnotationsEnabled = enable;
    _pdfRedactionEnabled = enable;
    _pdfFormFillingEnabled = enable;
    _pdfFormSigningEnabled = enable;
    _pdfSignatureFieldCreationEnabled = enable;
    _fullScreenModeEnabled = enable;

    _pdfFormFillingAvailable = YES;
    _pdfRedactionAvailable = YES;
}

- (BOOL)expired
{
    if ( self.expiresDate )
    {
        NSTimeInterval interval;
        interval = [self.expiresDate timeIntervalSinceNow];
        if ( interval <= 0 )
            return YES;
    }

    return NO;
}


- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if ( self )
    {
        _saveButtonEnabled       = [aDecoder decodeBoolForKey:keyForSaveButtonEnabled];
        _editingEnabled          = [aDecoder decodeBoolForKey:keyForEditingEnabled];
        _printingEnabled         = [aDecoder decodeBoolForKey:keyForPrintingEnabled];
        _securePrintingEnabled   = [aDecoder decodeBoolForKey:keyForSecurePrintingEnabled];
        _insertFromCameraEnabled = [aDecoder decodeBoolForKey:keyForInsertFromCameraEnabled];
        _insertFromPhotosEnabled = [aDecoder decodeBoolForKey:keyForInsertFromPhotosEnabled];
        _pdfAnnotationsEnabled   = [aDecoder decodeBoolForKey:keyForPdfAnnotationsEnabled];
        _pdfRedactionEnabled     = [aDecoder decodeBoolForKey:keyForPdfRedactionEnabled];
        _pdfFormFillingEnabled   = [aDecoder decodeBoolForKey:keyForPdfFormFillingEnabled];
        _pdfFormSigningEnabled   = [aDecoder decodeBoolForKey:keyForPdfFormSigningEnabled];
        _pdfSignatureFieldCreationEnabled = [aDecoder decodeBoolForKey:keyForPdfSignatureFieldCreationEnabled];
        _fullScreenModeEnabled   = [aDecoder decodeBoolForKey:keyForFullScreenModeEnabled];
        _pdfFormFillingAvailable = [aDecoder decodeBoolForKey:keyForPpdfFormFillingAvailable];
        _pdfRedactionAvailable   = [aDecoder decodeBoolForKey:keyForPdfRedactionAvailable];
        _expiresDate             = [aDecoder decodeObjectForKey:keyForExpiresDate];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeBool:_saveButtonEnabled forKey:keyForSaveButtonEnabled];
    [aCoder encodeBool:_editingEnabled forKey:keyForEditingEnabled];
    [aCoder encodeBool:_printingEnabled forKey:keyForPrintingEnabled];
    [aCoder encodeBool:_securePrintingEnabled forKey:keyForSecurePrintingEnabled];
    [aCoder encodeBool:_insertFromCameraEnabled forKey:keyForInsertFromCameraEnabled];
    [aCoder encodeBool:_insertFromPhotosEnabled forKey:keyForInsertFromPhotosEnabled];
    [aCoder encodeBool:_pdfAnnotationsEnabled forKey:keyForPdfAnnotationsEnabled];
    [aCoder encodeBool:_pdfRedactionEnabled forKey:keyForPdfRedactionEnabled];
    [aCoder encodeBool:_pdfFormFillingEnabled forKey:keyForPdfFormFillingEnabled];
    [aCoder encodeBool:_pdfFormSigningEnabled forKey:keyForPdfFormSigningEnabled];
    [aCoder encodeBool:_pdfSignatureFieldCreationEnabled forKey:keyForPdfSignatureFieldCreationEnabled];
    [aCoder encodeBool:_fullScreenModeEnabled forKey:keyForFullScreenModeEnabled];
    [aCoder encodeBool:_pdfFormFillingAvailable forKey:keyForPpdfFormFillingAvailable];
    [aCoder encodeBool:_pdfRedactionAvailable forKey:keyForPdfRedactionAvailable];
    [aCoder encodeObject:_expiresDate forKey:keyForExpiresDate];
}

@end
