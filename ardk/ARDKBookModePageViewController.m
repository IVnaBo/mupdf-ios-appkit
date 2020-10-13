// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import "ARDKBookModePageViewController.h"

@interface ARDKBookModePageViewController ()
@property(weak) id<ARDKBookModePageViewControllerDelegate> delegate;
@end

@implementation ARDKBookModePageViewController

- (instancetype)initForPage:(NSInteger)pageNumber
                 withBitmap:(ARDKBitmap *)bitmap
                andDelegate:(id<ARDKBookModePageViewControllerDelegate>)delegate
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _pageNumber = pageNumber;
        _bitmap = bitmap;
        _delegate = delegate;
    }
    return self;
}

- (void)loadView
{
    self.view = [[ARDKBookModePageView alloc] initForPage:self.pageNumber
                                               withBitmap:self.bitmap
                                                 delegate:_delegate];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.delegate onPageSizeUpdate];
}


@end
