//
//  ARDKCertDetailViewController.h
//  smart-office-nui
//
//  Created by Stuart MacNeill on 2/7/2019
//  Copyright (c) 2019 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKPKCS7.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARDKCertDetailViewController : UIViewController

/**
 * Update the content of this view controller to display the details of the
 * designatedName and description
 *
 * @param designatedName    The designatedName information to display
 * @param description       The description information to display
 */
- (void) displayCertificateFor:(id<PKCS7DesignatedName> _Nullable) designatedName
                   description:(id<PKCS7Description> _Nullable) description;

@end

NS_ASSUME_NONNULL_END
