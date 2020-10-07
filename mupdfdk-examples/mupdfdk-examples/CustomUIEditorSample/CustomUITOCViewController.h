// Copyright © 2019 Paul Gardiner. All rights reserved.

#import <UIKit/UIKit.h>
#import <mupdfdk/mupdfdk.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomUITOCViewController : UITableViewController
@property id<MuPDFDKBasicDocumentViewAPI> docView;
@end

NS_ASSUME_NONNULL_END
