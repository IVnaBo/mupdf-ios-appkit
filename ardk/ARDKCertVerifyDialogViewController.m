 //
//  ARDKCertVerifyDialogViewController.m
//  smart-office-nui
//
//  Created by Stuart MacNeill on 19/7/2019
//  Copyright (c) 2019 Artifex Software Inc. All rights reserved.
//

#import "ARDKCertVerifyDialogViewController.h"
#import "ARDKCertDetailViewController.h"
#import "ARDKStackedButton.h"
#import "ARDKMutableSigner.h"
#import "ARDKPKCS7.h"

@interface ARDKCertVerifyDialogViewController ()

@property (weak, nonatomic) IBOutlet UIView *dialogView;
@property (weak, nonatomic) IBOutlet UILabel *messageHeading;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UIImageView *messageImageView;
@property (weak, nonatomic) IBOutlet UILabel *certificateDetailHeading;
@property (weak, nonatomic) IBOutlet UIButton *okButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *certificateDetailHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *certificateDetailWidthConstraint;

@property ARDKCertDetailViewController *certificateDetailVC;

@end

static NSString * const AcceptImageName  = @"icon-accept-color";
static NSString * const WarningImageName = @"icon-warning-color";
static NSString * const AlertImageName   = @"icon-alert-color";
static NSString * const DenyImageName    = @"icon-deny-color";

@implementation ARDKCertVerifyDialogViewController
{
    NSAttributedString      *_messageString;
    NSString                *_verifyImageName;
    id<PKCS7DesignatedName>  _designatedName;
    id<PKCS7Description>     _description;
    void (^_onDismiss)(void);
}

- (IBAction)okButtonPressed:(id)sender
{
    _onDismiss();
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

- (id)initWithVerifyResult:(PKCS7VerifyResult) verifyResult
        invalidChangePoint:(int) invalidChangePoint
            designatedName:(id<PKCS7DesignatedName>) designatedName
               description:(id<PKCS7Description>) description
                 onDismiss:(void (^)(void)) onDismiss
{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"ARDKSigning"
                                                 bundle:[NSBundle bundleForClass:self.class]];
    
    self = [sb instantiateViewControllerWithIdentifier:@"CertificateVerifyDialogId"];
    
    if (self)
    {
        NSMutableAttributedString *tempMessageString = [[NSMutableAttributedString alloc]initWithString:@""];

        // The message heading
        NSString *headingString = @"";
        NSMutableDictionary *headingStyle = [NSMutableDictionary dictionary];
        [headingStyle setObject:[UIFont boldSystemFontOfSize:16] forKey:NSFontAttributeName];

        // The message body
        NSString *bodyString = @"";
        NSMutableDictionary *bodyStyle = [NSMutableDictionary dictionary];
        [bodyStyle setObject:[UIFont systemFontOfSize:13] forKey:NSFontAttributeName];
                
        switch (verifyResult)
        {
        case PKCS7VerifyResult_Okay:
            if (invalidChangePoint != 0)
            {
                headingString = [headingString stringByAppendingString:
                                            NSLocalizedString(@"Signature warning",
                                                              @"Signature verifier message heading to indicate a warning about the signature")];
                headingString = [headingString stringByAppendingString:@"\n"];
                
                bodyString = [bodyString stringByAppendingString:
                                             NSLocalizedString(@"This signature has been invalidated by changes it prohibits since signing",
                                                               @"Signature verfier warning that this signature has been invalidated by changes it prohibits since signing")];
                bodyString = [bodyString stringByAppendingString:@"\n"];

                _verifyImageName = WarningImageName;
            }
            else
            {
                headingString = [headingString stringByAppendingString:
                                            NSLocalizedString(@"Signature valid",
                                                              @"Signature verifier message heading to indicate that the signature is valid")];
                headingString = [headingString stringByAppendingString:@"\n"];
                
                bodyString = [bodyString stringByAppendingString:
                                             NSLocalizedString(@"This signature is valid, and only changes it permits have been made since signing",
                                                               @"Signature verfier message that this signature is valid, and only changes it permits have been made since signing")];
                bodyString = [bodyString stringByAppendingString:@"\n"];

                _verifyImageName = AcceptImageName;
            }
            break;
            
        case PKCS7VerifyResult_DigestFailure:
            headingString = [headingString stringByAppendingString:
                                        NSLocalizedString(@"Verification failed",
                                                          @"Signature verifier message heading to indicate that the signature verify operation failed")];
            headingString = [headingString stringByAppendingString:@"\n"];
            
            bodyString = [bodyString stringByAppendingString:
                                         NSLocalizedString(@"Document digest failure",
                                                           @"Signature verifier message that there was a document digest failure")];
            bodyString = [bodyString stringByAppendingString:@"\n"];

            _verifyImageName = DenyImageName;
            break;

        default:
            headingString = [headingString stringByAppendingString:
                                        NSLocalizedString(@"Verification failed",
                                                          @"Signature verifier message heading to indicate that the signature verify operation failed")];
            headingString = [headingString stringByAppendingString:@"\n"];

            bodyString = [bodyString stringByAppendingString:
                                         NSLocalizedString(@"This signature is not trusted",
                                                           @"Signature verifier message that this signature is not trusted")];
            bodyString = [bodyString stringByAppendingString:@"\n"];

            _verifyImageName = DenyImageName;
            break;
        }

        [tempMessageString appendAttributedString:[[NSAttributedString alloc]initWithString:headingString
                                                                                 attributes:headingStyle]];
        
        [tempMessageString appendAttributedString:[[NSAttributedString alloc]initWithString:bodyString
                                                                                 attributes:bodyStyle]];

        _messageString = tempMessageString;

        _designatedName = designatedName;

        _description = description;

        _onDismiss = onDismiss;
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.messageHeading setText: NSLocalizedString(@"Document Signature Verification",
                                                    @"Label for document signature verification dialog title")];

    self.messageLabel.attributedText = _messageString;
    self.messageLabel.numberOfLines = 0;

    // load the relevant verify image
    UIImage *image = [UIImage imageNamed:_verifyImageName
                                inBundle:[NSBundle bundleForClass:self.class]
                              compatibleWithTraitCollection:nil];
    [self.messageImageView setImage:image];
    [self.messageImageView setContentMode:UIViewContentModeScaleAspectFit];

    [self.certificateDetailHeading setText: NSLocalizedString(@"Certificate Details",
                                                              @"Label for certificate details section on the certificate picker dialog")];
    
    [self.okButton setTitle: NSLocalizedString(@"OK", @"Caption on OK button")
                   forState:UIControlStateNormal];
    
    self.certificateDetailHeightConstraint.constant = self.certificateDetailVC.view.subviews[0].frame.size.height;
    self.certificateDetailWidthConstraint.constant = self.certificateDetailVC.view.subviews[0].frame.size.width;
    
    // update the certificate detail view controller
    [_certificateDetailVC displayCertificateFor:_designatedName
                                    description:_description];

    // round off the corners of the dialog box
    self.dialogView.layer.cornerRadius = 15.0;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
}

@end
