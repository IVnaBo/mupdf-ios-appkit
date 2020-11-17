//
//  ARDKDocTypeDetail.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 20/12/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "ARDKLib.h"

@interface ARDKDocTypeDetail : NSObject

+ (NSString * _Nonnull)docTypeIcon:(ARDKDocType)type;

+ (UIColor * _Nonnull)docTypeColor:(ARDKDocType)type;

@end
