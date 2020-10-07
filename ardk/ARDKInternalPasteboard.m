//  Copyright © 2017 Artifex Software Inc. All rights reserved.

#import "ARDKInternalPasteboard.h"

@implementation ARDKInternalPasteboard
{
    NSString *_string;
    NSInteger _changeCount;
}

- (BOOL)ARDKPasteboard_hasStrings
{
    return (_string != nil);
}

- (NSString *)ARDKPasteboard_string
{
    return _string;
}

- (NSInteger)ARDKPasteboard_changeCount
{
    return _changeCount;
}

- (void)ARDKPasteboard_setString:(NSString *)string
{
    _string = string;
    _changeCount++;
}

@end
