//
//  ARDKUIContainerViewController.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 13/01/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

/// This subclass of ContainerViewController supports the case of
/// multiple alternative embedded view controllers each supporting
/// the SODKUI protocol

#import "ARDKContainerViewController.h"
#import "ARDKUI.h"

@interface ARDKUIContainerViewController : ARDKContainerViewController<ARDKUI>
@end
