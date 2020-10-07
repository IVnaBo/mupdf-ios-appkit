//
//  Settings.m
//  smart-office-examples
//
//  Created by Joseph Heenan on 27/03/2017.
//  Copyright © 2017 Artifex. All rights reserved.
//

#import "Settings.h"

@implementation Settings

- (void)enableAll:(BOOL)enable
{
    [super enableAll:enable];

    _systemPasteboardEnabled = enable;

    _saveAsEnabled = enable;
    _shareEnabled = enable;
    _openInEnabled = enable;
 
    _openUrlEnabled = enable;
}

@end
