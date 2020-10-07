//  Copyright © 2017 Artifex Software Inc. All rights reserved.

#import "Pasteboard.h"

/// Implementation of ARDKPasteboard to use OS UIPasteboard
///
/// In a secure app, you would probably not want to use the OS UIPasteboard,
/// and would instead store any string in a property of this class, isolating
/// it inside your application.
@implementation Pasteboard

- (BOOL)ARDKPasteboard_hasStrings
{
    UIPasteboard *pb = [UIPasteboard generalPasteboard];

    if ([NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10,0,0}])
    {
        return pb.hasStrings;
    }

    /* before iOS 10, use old way */
    return (pb.string != nil);
}

- (NSString *)ARDKPasteboard_string
{
    UIPasteboard *pb = [UIPasteboard generalPasteboard];

    return pb.string;
}

- (NSInteger)ARDKPasteboard_changeCount
{
    UIPasteboard *pb = [UIPasteboard generalPasteboard];

    return pb.changeCount;
}

- (void)ARDKPasteboard_setString:(NSString *)string
{
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    pb.string = string;
}

@end
