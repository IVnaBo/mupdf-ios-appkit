//
//  ARDKCertDetailViewController.m
//  smart-office-nui
//
//  Created by Stuart MacNeill on 2/7/2019
//  Copyright (c) 2019 Artifex Software Inc. All rights reserved.
//

#import "ARDKCertDetailViewController.h"

@interface ARDKCertDetailViewController ()
@property (strong, nonatomic) IBOutlet UIView *topLevelView;
@property (weak, nonatomic) IBOutlet UITextView *certificateDetailText;
@end

@implementation ARDKCertDetailViewController
{
}

NSString *IssuedTo_Heading;
NSString *IssuedTo_CommonName_Name;
NSString *IssuedTo_Organization_Name;
NSString *IssuedTo_OrganizationalUnit_Name;
NSString *IssuedTo_Email_Name;
NSString *IssuedTo_Country_Name;
NSString *IssuedTo_State_Name;
NSString *IssuedTo_Locality_Name;
NSString *IssuedTo_SerialNumber_Name;
    
NSString *IssuedBy_Heading;
NSString *IssuedBy_CommonName_Name;
NSString *IssuedBy_Organization_Name;
NSString *IssuedBy_OrganizationalUnit_Name;

NSString *PeriodOfValidity_Heading;
NSString *PeriodOfValidity_NotValidBefore_Name;
NSString *PeriodOfValidity_NotValidAfter_Name;
    
NSString *Fingerprints_Heading;
NSString *Fingerprints_SHA256Fingerprint_Name;
NSString *Fingerprints_SHA1Fingerprint_Name;

NSString *KeyUsage_Heading;
NSString *KeyUsage_Usage_Name;

NSString *ExtendedKeyUsage_Heading;
NSString *ExtendedKeyUsage_Usage_Name;

NSString *NotPresentInCertificateString;

NSString *SectionHeadingIndentString;
NSString *AttributeNameIndentString;
NSString *AttributeValueIndentString;

- (void)allocStrings
{
    IssuedTo_Heading                     = NSLocalizedString(@"Issued To",                @"Heading for the certificate details 'Issued To' section");
    IssuedTo_CommonName_Name             = NSLocalizedString(@"Common Name (CN)",         @"Certificate details 'IssuedTo.CommonName' attribute name");
    IssuedTo_Organization_Name           = NSLocalizedString(@"Organization (O)",         @"Certificate details 'IssuedTo.Organization' attribute name");
    IssuedTo_OrganizationalUnit_Name     = NSLocalizedString(@"Organizational Unit (OU)", @"Certificate details 'IssuedTo.OrganizationlUnit' attribute name");
    IssuedTo_Email_Name                  = NSLocalizedString(@"Email",                    @"Certificate details 'IssuedTo.Email' attribute name");
    IssuedTo_Country_Name                = NSLocalizedString(@"Country (C)",              @"Certificate details 'IssuedTo.Country' attribute name");
    IssuedTo_State_Name                  = NSLocalizedString(@"State (S)",                @"Certificate details 'IssuedTo.State' attribute name");
    IssuedTo_Locality_Name               = NSLocalizedString(@"Locality (L)",             @"Certificate details 'IssuedTo.Locality' attribute name");
    IssuedTo_SerialNumber_Name           = NSLocalizedString(@"Serial Number",            @"Certificate details 'IssuedTo.Serial Number' attribute name");
    
    IssuedBy_Heading                     = NSLocalizedString(@"Issued By",                @"Heading for the certificate details 'Issued By' section");
    IssuedBy_CommonName_Name             = NSLocalizedString(@"Common Name (CN)",         @"Certificate details 'IssuedBy.CommonName' attribute name");
    IssuedBy_Organization_Name           = NSLocalizedString(@"Organization (O)",         @"Certificate details 'IssuedBy.Organization' attribute name");
    IssuedBy_OrganizationalUnit_Name     = NSLocalizedString(@"Organizational Unit (OU)", @"Certificate details 'IssuedBy.OrganizationalUnit' attribute name");
    
    PeriodOfValidity_Heading             = NSLocalizedString(@"Period Of Validity",       @"Heading for the certificate details 'Period Of Validity' section");
    PeriodOfValidity_NotValidBefore_Name = NSLocalizedString(@"Not Valid Before",         @"Certificate details 'PeriodOfValidity.NotValidBefore' attribute name");
    PeriodOfValidity_NotValidAfter_Name  = NSLocalizedString(@"Not Valid After",          @"Certificate details 'PeriodOfValidity.NotValidAfter' attribute name");
    
    Fingerprints_Heading                 = NSLocalizedString(@"Fingerprint",              @"Heading for the certificate details 'Fingerprints' section");;
    Fingerprints_SHA256Fingerprint_Name  = NSLocalizedString(@"SHA-256 Fingerprint",      @"Certificate details 'Fingerprint.SHA256Fingerprint' attribute name");
    Fingerprints_SHA1Fingerprint_Name    = NSLocalizedString(@"SHA1 Fingerprint",         @"Certificate details 'Fingerprint.SHA1Fingerprint' attribute name");

    KeyUsage_Heading                     = NSLocalizedString(@"Key Usage",                @"Heading for the certificate details 'Key Usage' section");;
    KeyUsage_Usage_Name                  = NSLocalizedString(@"Usage",                    @"Certificate details 'KeyUsage.Usage' attribute name");

    ExtendedKeyUsage_Heading             = NSLocalizedString(@"Extended Key Usage",       @"Heading for the certificate details 'Extended Key Usage' section");;
    ExtendedKeyUsage_Usage_Name          = NSLocalizedString(@"Usage",                    @"Certificate details 'ExtendedKeyUsage.Usage' attribute name");
    
    NotPresentInCertificateString        = NSLocalizedString(@"-",                        @"String displayed to indicate that a given attribute is not present in this certifcate");

    SectionHeadingIndentString = @"";
    AttributeNameIndentString  = @"  ";
    AttributeValueIndentString = @"    ";
}

- (NSAttributedString *) sectionHeadingStringFor:(NSString *) string
{
    NSMutableDictionary *style = [NSMutableDictionary dictionary];

    [style setObject:[UIFont boldSystemFontOfSize:14] 
              forKey:NSFontAttributeName];

    [style setObject:[NSNumber numberWithInteger: NSUnderlineStyleSingle]
              forKey:NSUnderlineStyleAttributeName];

    [style setObject:self.certificateDetailText.textColor
              forKey:NSForegroundColorAttributeName];
    
    NSString *tempString = @"";
    tempString = [tempString stringByAppendingString:SectionHeadingIndentString];
    tempString = [tempString stringByAppendingString:string];
    tempString = [tempString stringByAppendingString:@"\n"];

    return [[NSAttributedString alloc]initWithString:tempString
                                          attributes:style];
}

- (NSAttributedString *) attributeNameStringFor:(NSString *) string
{
    NSMutableDictionary *style = [NSMutableDictionary dictionary];

    [style setObject:[UIFont boldSystemFontOfSize:14]
              forKey:NSFontAttributeName];

    [style setObject:self.certificateDetailText.textColor
              forKey:NSForegroundColorAttributeName];
    
    NSString *tempString = @"";
    tempString = [tempString stringByAppendingString:SectionHeadingIndentString];
    tempString = [tempString stringByAppendingString:AttributeNameIndentString];
    tempString = [tempString stringByAppendingString:string];
    tempString = [tempString stringByAppendingString:@"\n"];

    return [[NSAttributedString alloc]initWithString:tempString
                                          attributes:style];
}

- (NSAttributedString *) attributeValueStringFor:(NSString *) string
{
    NSMutableDictionary *style = [NSMutableDictionary dictionary];

    [style setObject:[UIFont systemFontOfSize:14]
              forKey:NSFontAttributeName];

    [style setObject:self.certificateDetailText.textColor
              forKey:NSForegroundColorAttributeName];
    
    NSString *tempString = @"";
    tempString = [tempString stringByAppendingString:SectionHeadingIndentString];
    tempString = [tempString stringByAppendingString:AttributeNameIndentString];
    tempString = [tempString stringByAppendingString:AttributeValueIndentString];
    tempString = [tempString stringByAppendingString:string];
    tempString = [tempString stringByAppendingString:@"\n"];

    return [[NSAttributedString alloc]initWithString:tempString
                                          attributes:style];
}

- (void) displayCertificateFor:(id<PKCS7DesignatedName>)designatedName
                   description:(id<PKCS7Description>)description
{
    NSMutableAttributedString *detailString = [[NSMutableAttributedString alloc]initWithString:@""];
    NSString *nameString;
    NSString *valueString;
    
    // the "Issued To" section of the certificate
    [detailString appendAttributedString:[self sectionHeadingStringFor:IssuedTo_Heading]];

    nameString = IssuedTo_CommonName_Name;
    valueString = designatedName ? designatedName.cn : NotPresentInCertificateString;
    [detailString appendAttributedString:[self attributeNameStringFor:nameString]];
    [detailString appendAttributedString:[self attributeValueStringFor:valueString]];

    nameString = IssuedTo_Organization_Name;
    valueString = designatedName ? designatedName.o : NotPresentInCertificateString;
    [detailString appendAttributedString:[self attributeNameStringFor:nameString]];
    [detailString appendAttributedString:[self attributeValueStringFor:valueString]];

    nameString = IssuedTo_OrganizationalUnit_Name;
    valueString = designatedName ? designatedName.ou : NotPresentInCertificateString;
    [detailString appendAttributedString:[self attributeNameStringFor:nameString]];
    [detailString appendAttributedString:[self attributeValueStringFor:valueString]];

    nameString = IssuedTo_Email_Name;
    valueString = designatedName ? designatedName.email : NotPresentInCertificateString;
    [detailString appendAttributedString:[self attributeNameStringFor:nameString]];
    [detailString appendAttributedString:[self attributeValueStringFor:valueString]];

    nameString = IssuedTo_Country_Name;
    valueString = designatedName ? designatedName.c : NotPresentInCertificateString;
    [detailString appendAttributedString:[self attributeNameStringFor:nameString]];
    [detailString appendAttributedString:[self attributeValueStringFor:valueString]];

    // the "Period Of Validity" section of the certificate
    [detailString appendAttributedString:[self sectionHeadingStringFor:PeriodOfValidity_Heading]];

    nameString = PeriodOfValidity_NotValidBefore_Name;
    NSString *notValidBefore = description ? description.notValidBefore : nil;
    if (notValidBefore)
    {
        long long secsSinceEpoch = [notValidBefore longLongValue];
        valueString = (secsSinceEpoch == 0) ?
            NotPresentInCertificateString :
            [[NSDate dateWithTimeIntervalSince1970:[notValidBefore doubleValue]] description];
    }
    else
    {
        valueString = NotPresentInCertificateString;
    }
    [detailString appendAttributedString:[self attributeNameStringFor:nameString]];
    [detailString appendAttributedString:[self attributeValueStringFor:valueString]];

    nameString = PeriodOfValidity_NotValidAfter_Name;
    NSString *notValidAfter = description ? description.notValidAfter : nil;
    if (notValidAfter)
    {
        long long secsSinceEpoch = [notValidAfter longLongValue];
        valueString = (secsSinceEpoch == 0) ?
            NotPresentInCertificateString :
            [[NSDate dateWithTimeIntervalSince1970:[notValidAfter doubleValue]] description];
    }
    else
    {
        valueString = NotPresentInCertificateString;
    }
    [detailString appendAttributedString:[self attributeNameStringFor:nameString]];
    [detailString appendAttributedString:[self attributeValueStringFor:valueString]];

    // the "Key Usage" section of the certificate
    [detailString appendAttributedString:[self sectionHeadingStringFor:KeyUsage_Heading]];

    NSString *csvSeparator = @",\n";
    csvSeparator = [csvSeparator stringByAppendingString:SectionHeadingIndentString];
    csvSeparator = [csvSeparator stringByAppendingString:AttributeNameIndentString];
    csvSeparator = [csvSeparator stringByAppendingString:AttributeValueIndentString];

    nameString = KeyUsage_Usage_Name;
    NSSet *keyUsage = description ? description.keyUsage : [[NSSet alloc] init];
    valueString = keyUsage ? [[self class] stringSetToCSVString:keyUsage separator:csvSeparator] : NotPresentInCertificateString;
    if (valueString.length == 0)
    {
        valueString = @"-";
    }
    [detailString appendAttributedString:[self attributeNameStringFor:nameString]];
    [detailString appendAttributedString:[self attributeValueStringFor:valueString]];

    // the "Extended Key Usage" section of the certificate
    [detailString appendAttributedString:[self sectionHeadingStringFor:ExtendedKeyUsage_Heading]];

    nameString = ExtendedKeyUsage_Usage_Name;
    NSSet *extendedKeyUsage = description ? description.extKeyUsage : [[NSSet alloc] init];
    valueString = extendedKeyUsage ? [[self class] stringSetToCSVString:extendedKeyUsage separator:csvSeparator] : NotPresentInCertificateString;
    if (valueString.length == 0)
    {
        valueString = @"-";
    }
    [detailString appendAttributedString:[self attributeNameStringFor:nameString]];
    [detailString appendAttributedString:[self attributeValueStringFor:valueString]];
    
    // update the display certificate detail text
    self.certificateDetailText.attributedText = detailString;
    
    // resize the topLevel to be the size of the detail string we've just created
    CGSize detailStringSize = [detailString size];
    float padding = 20.0;
    self.topLevelView.frame = CGRectMake(0.0,
                                         0.0,
                                         detailStringSize.width + padding,
                                         detailStringSize.height + padding);

    [self.topLevelView layoutIfNeeded];
}

// Convert an NSSet of NSString items to a string that's a comma separated list
// uses "," as the separator by default or the value passed in separator if non-nil
+(NSString *) stringSetToCSVString:(NSSet *)stringSet
                         separator:(NSString *)separator
{
    NSString *csvString = [NSString string];
    NSString *separatorString = separator ? separator : @",";
    
    int i = 0;
    for(NSString *item in stringSet)
    {
        if (i > 0)
        {
            // add a separator between the strings in stringSet
            csvString = [csvString stringByAppendingString:separatorString];
        }
        csvString = [csvString stringByAppendingString:item];
        i++;
    }
    return csvString;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self allocStrings];

    // update the value field to show no certificate selected
    [self displayCertificateFor:nil
                    description:nil];
}

@end
