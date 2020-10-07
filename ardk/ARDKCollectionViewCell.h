// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import <UIKit/UIKit.h>
#import "ARDKPageCell.h"

// Implementation of the ARDKPageCell protocol for use with
// UICollectionViews. This the cell class to use when a UICollectionView
// is used to control page view's positioning and movement.

@interface ARDKCollectionViewCell : UICollectionViewCell<ARDKPageCell>

@end
