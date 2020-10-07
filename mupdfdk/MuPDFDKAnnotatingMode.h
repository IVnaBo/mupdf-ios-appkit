// Copyright © 2017 Artifex Software Inc. All rights reserved.

typedef enum
{
    MuPDFDKAnnotatingMode_None,
    MuPDFDKAnnotatingMode_EditAnnotation,
    MuPDFDKAnnotatingMode_EditRedaction,
    MuPDFDKAnnotatingMode_Draw,
    MuPDFDKAnnotatingMode_RedactionAreaSelect,
    MuPDFDKAnnotatingMode_RedactionTextSelect,
    MuPDFDKAnnotatingMode_HighlightTextSelect,
    MuPDFDKAnnotatingMode_Note,
    MuPDFDKAnnotatingMode_DigitalSignature
}
MuPDFDKAnnotatingMode;
