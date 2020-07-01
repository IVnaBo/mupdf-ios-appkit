// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import "ARDKBookModePageView.h"
#import "ARDKBookModePageViewController.h"

@interface ARDKBookModePageViewController ()
@end

@implementation ARDKBookModePageViewController

- (instancetype)initForPage:(NSInteger)pageNumber
                 withBitmap:(ARDKBitmap *)bitmap
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _pageNumber = pageNumber;
        _bitmap = bitmap;
    }
    return self;
}

- (void)loadView
{
    self.view = [[ARDKBookModePageView alloc] initForPage:self.pageNumber
                                               withBitmap:self.bitmap];
}


@end
