//
//  MuPDFDKAnnotInfoViewController.h
//  smart-office-nui
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ARDKTextView.h"

@interface MuPDFDKAnnotInfoViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *authorLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet ARDKTextView *commentText;
@end
