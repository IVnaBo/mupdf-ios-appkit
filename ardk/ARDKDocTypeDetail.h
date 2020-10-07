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

+ (NSString *)docTypeIcon:(ARDKDocType)type;

+ (UIColor *)docTypeColor:(ARDKDocType)type;

@end
