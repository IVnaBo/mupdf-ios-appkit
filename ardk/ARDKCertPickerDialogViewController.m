//
//  ARDKCertPickerDialogViewController.m
//  smart-office-nui
//
//  Created by Stuart MacNeill on 2/7/2019
//  Copyright (c) 2019 Artifex Software Inc. All rights reserved.
//

#import "ARDKCertPickerDialogViewController.h"
#import "ARDKCertDetailViewController.h"
#import "ARDKMutableSigner.h"
#import "ARDKStackedButton.h"

#define FONT_SIZE (12)
#define CORNER_RADUIS (10.0)
#define LABEL_TOP_INSET (10.0)

@interface ARDKCertPickerDialogViewController ()

@property (weak, nonatomic) IBOutlet UIView *dialogView;
@property (weak, nonatomic) IBOutlet UILabel *availableCertificatesHeading;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIStackView *stackView;
@property (weak, nonatomic) IBOutlet UILabel *certificateDetailHeading;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIButton *selectButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *certificateDetailHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *certificateDetailWidthConstraint;

@property ARDKCertDetailViewController *certificateDetailVC;

@end

@implementation ARDKCertPickerDialogViewController
{
    ARDKMutableSigner *_signer;
    void              (^_onDismiss)(void);
    NSMutableArray    *_buttons;
    NSMutableArray    *_buttonCertIndexes;
    NSInteger          _selectedCertIndex;

}
static BOOL _filterCertificates;

- (void)dealloc
{
    _buttons = nil;
}


+ (BOOL) certificateFilterEnabled
{
    return _filterCertificates;
}

+ (void) setCertificateFilterEnabled:(BOOL) enable
{
    _filterCertificates = enable;
}

- (IBAction)selectButtonPressed:(id)sender
{
    _onDismiss();
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

- (IBAction)cancelButtonPressed:(id)sender
{
    if (_signer)
    {
        // the user cancelled, make sure _signer is updated to have no
        // certificate selected when we call _onDismiss
        [_signer setSelectedCertificateIndex:NSNotFound];
    }
    _onDismiss();
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

- (id)initWithSigner:(ARDKMutableSigner *) signer
           onDismiss:(void (^)(void))onDismiss
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"ARDKSigning"
                                                 bundle:[NSBundle bundleForClass:self.class]];
    
    self = [sb instantiateViewControllerWithIdentifier:@"CertificatePickerDialogId"];
    
    if (self)
    {
        _signer = signer;
        _onDismiss = onDismiss;
        _buttons = [NSMutableArray array];
        _buttonCertIndexes = [NSMutableArray array];
        _selectedCertIndex = NSNotFound;
    }
    
    return self;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Store a reference to the embedded view controllers
    if ([segue.identifier isEqualToString:@"CertificateDetailSegue"])
    {
        self.certificateDetailVC = segue.destinationViewController;
    }
}

- (void)iconButtonPressed:(UIButton *) button
{
    NSUInteger buttonIndex = [_buttons indexOfObject:button];

    _selectedCertIndex = (buttonIndex == NSNotFound) ? NSNotFound : [(NSNumber *)[_buttonCertIndexes objectAtIndex:buttonIndex] intValue];

    for(int i = 0; i < _buttons.count; i++)
    {
        UIButton *currButton = _buttons[ i ];
        
        UIColor *bgColor = self.dialogView.backgroundColor;
        UIColor *fgColor = self.availableCertificatesHeading.textColor;

        if ( currButton == button )
        {
            // swap the fg and bg colors for the button that has been pressed
            UIColor *tempColor = fgColor;
            fgColor = bgColor;
            bgColor = tempColor;
        }

        [currButton.titleLabel setHighlighted:YES];
        [currButton.titleLabel setHighlightedTextColor:fgColor];
        
        [currButton.titleLabel setBackgroundColor:bgColor];
    }

    if (self.certificateDetailVC)
    {
        [_signer setSelectedCertificateIndex:_selectedCertIndex];

        [self.certificateDetailVC displayCertificateFor:[_signer name]
                                            description:[_signer description]];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.availableCertificatesHeading setText: NSLocalizedString(@"Available Certificates",
                                                                  @"Label for available certificates section on the certificate picker dialog")];

    [self.certificateDetailHeading setText: NSLocalizedString(@"Certificate Details",
                                                              @"Label for certificate details section on the certificate picker dialog")];
    
    [self.cancelButton setTitle: NSLocalizedString(@"Cancel",
                                                   @"Label for cancel button on certificate picker dialog")
                      forState:UIControlStateNormal];
    
    [self.selectButton setTitle: NSLocalizedString(@"Sign",
                                                   @"Label for button on certificate picker dialog to sign with the selected certificate")
                       forState:UIControlStateNormal];
                 
    // get the names and icons for all the certificates  known to _signer
    NSInteger numCerts = 0;
    NSMutableArray *nameArray = [NSMutableArray array];
    NSMutableArray *iconArray = [NSMutableArray array];
    NSMutableArray *certIndexArray = [NSMutableArray array];
    if (_signer)
    {
        numCerts = [_signer numCertificates];
        for(NSInteger certIndex = 0; certIndex < numCerts; certIndex++)
        {
            [_signer setSelectedCertificateIndex:certIndex];
                 
            BOOL certFilteredOut = NO;
            if (_filterCertificates)
            {
                NSSet *certKeyUsage = [_signer description].keyUsage;
                if (certKeyUsage)
                {
                    // filter out certificate where "Non Repudiation" is not present in the "Key Usage" value
                    certFilteredOut = ![certKeyUsage containsObject:@"Non Repudiation"];
                }
            }
            
            if (!certFilteredOut)
            {
                id<PKCS7DesignatedName> certName = [_signer name];
                if (certName)
                {
                    [nameArray addObject:certName.cn];
                    UIImage *certImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@", @"cert-x509"]
                                                    inBundle:[NSBundle bundleForClass:self.class]
                                                  compatibleWithTraitCollection:nil];
                    [iconArray addObject:certImage];
                    [certIndexArray addObject:[NSNumber numberWithInteger:certIndex]];
                }
            }
        }
    }
    
    // add a button to stackView for every item in [nameArray, iconArray]
    assert(nameArray.count == iconArray.count);
    assert(nameArray.count == certIndexArray.count);
    for(int index = 0; index < nameArray.count; index++)
    {
        ARDKStackedButton *button = nil;

        // set the text for the button we're about to add to this control
        NSString *name = [nameArray objectAtIndex:index];
        button = [[ARDKStackedButton alloc] initWithText:name
                                               imageName:@"cert-x509"];
        button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        button.titleLabel.font = [UIFont systemFontOfSize:FONT_SIZE];
        button.titleTopInset = LABEL_TOP_INSET;
       
        // create a scaled version of the icon for this button with rounded corners,
        // icon is scaled to be the same size as a launcher icon on this device
        UIImage  *icon = [iconArray objectAtIndex:index];
        
        // icon height for this control should be screen height / 30;
        int iconSizeInPixels = (CGFloat) ([[UIScreen mainScreen] nativeBounds].size.height / 30);
        CGFloat scaleFactor = (icon.size.height * icon.scale) / ((CGFloat)iconSizeInPixels);
        UIImage *scaledIcon = [UIImage imageWithCGImage:[icon CGImage]
                                                   scale:scaleFactor
                                             orientation:UIImageOrientationUp];
        
        CALayer *iconLayer = [CALayer layer];
        iconLayer.frame = CGRectMake(0, 0, scaledIcon.size.width, scaledIcon.size.height);
        iconLayer.contents = (id) scaledIcon.CGImage;
        
        iconLayer.masksToBounds = YES;
        iconLayer.cornerRadius = CORNER_RADUIS;

        UIGraphicsBeginImageContext(scaledIcon.size);
        [iconLayer renderInContext:UIGraphicsGetCurrentContext()];

        UIImage *roundedIcon = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        UIImage *tintedIcon = [button tintedImageWithColor:self.availableCertificatesHeading.textColor
                                                     image:roundedIcon];
        
        // set the image for the button we're about to add to this control
        [button setImage:tintedIcon
                forState:UIControlStateNormal];
        
        // store this button in an array so iconButtonPressed can figure out which button was pressed
        [_buttons addObject:button];
       
        // add an action to be call when this button is pressed
        [button addTarget:self
                   action:@selector(iconButtonPressed:)
                forControlEvents:UIControlEventTouchUpInside];
        
        // add the button to the StackView at the correct position
        [_stackView insertArrangedSubview:button
                                  atIndex:index];
        
        [_buttonCertIndexes addObject:[certIndexArray objectAtIndex:index]];
    }
    assert(nameArray.count == _buttonCertIndexes.count);

    // disable the sign button if there are no certificates known to the signer
    self.selectButton.enabled = (_buttonCertIndexes.count > 0) ? YES : NO;
                                                   
    // select the first icon in the certificate list
    if (_buttons.count > 0)
    {
        [self iconButtonPressed:_buttons[ 0 ]];
    }

    self.certificateDetailHeightConstraint.constant = self.certificateDetailVC.view.subviews[0].frame.size.height;
    self.certificateDetailWidthConstraint.constant = self.certificateDetailVC.view.subviews[0].frame.size.width;

    // round off the corners of the dialog box
    self.dialogView.layer.cornerRadius = 15.0;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
    if ( @available(iOS 13.0, *) )
    {
        BOOL hasUserInterfaceStyleChanged = [previousTraitCollection hasDifferentColorAppearanceComparedToTraitCollection:self.traitCollection];
        if (hasUserInterfaceStyleChanged)
        {
            // re-tint the images in the buttons to look correct for the new user interface style ("Light Mode"/"Dark Mode")
            for (UIView *currView in _stackView.subviews)
            {
                if ([currView isKindOfClass:[ARDKStackedButton class]])
                { 
                    ARDKStackedButton *currButton = (ARDKStackedButton *) currView;
                    UIImage *currImage = [currButton imageForState:UIControlStateNormal];
                    if (currImage)
                    {
                        [currButton setImage:[currButton tintedImageWithColor:self.availableCertificatesHeading.textColor
                                                                        image:currImage]
                                    forState:UIControlStateNormal];
                    }
                }
            }
        }
    }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 */
}

@end
