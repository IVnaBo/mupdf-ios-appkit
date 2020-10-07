//  Copyright © 2016 Artifex Software Inc. All rights reserved.

#import "ARDKGeometry.h"
#import "ARDKPrintPageRenderer.h"

#define PRINT_SCALING (4.0)

@implementation ARDKPrintPageRenderer
{
    id<ARDKDoc> _doc;
    BOOL        _skipRenderPageWithLowMemory;
}

- (id)initWithDocument:(id<ARDKDoc>)doc
{
    self = [super init];
    if (self)
    {
        NSNotificationCenter *noti = [NSNotificationCenter defaultCenter];
        
        assert(doc);
        _doc = doc;
        _skipRenderPageWithLowMemory = NO;
    
        if ( noti )
        {
            [noti addObserver:self
                     selector:@selector(handleMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification
                       object:nil];
        }
        
    }
    return self;
}

- (void)dealloc
{
    NSNotificationCenter *noti = [NSNotificationCenter defaultCenter];

    [noti removeObserver:self
                    name:UIApplicationDidReceiveMemoryWarningNotification
                  object:nil];
}

- (void)handleMemoryWarning:(NSNotification *)notification
{
    _skipRenderPageWithLowMemory = YES;
}

- (NSInteger)numberOfPages
{
    /* WARNING: called on background threads */

    __block NSInteger pageCount = 0;

    void (^queryBlock)(void) = ^{
        // the call to pageCount: needs to be on the main thread
        pageCount = self->_doc.pageCount;
    };

    if ([NSThread isMainThread])
        queryBlock();
    else
        dispatch_sync(dispatch_get_main_queue(), queryBlock);

    return pageCount;
}

- (void)prepareForDrawingPages:(NSRange)range
{
    // Reset the flag for new rendering
    _skipRenderPageWithLowMemory = NO;
}

- (void)drawPageAtIndex:(NSInteger)pageIndex inRect:(CGRect)printableRect
{
    /* WARNING: called on a background thread to generate previews and on the
     * main thread when printing */
    BOOL printing = [NSThread isMainThread];

    assert(_doc);

    if ( _skipRenderPageWithLowMemory )
        return;

    if ( printing )
        printableRect = ARCGRectScale(printableRect, PRINT_SCALING);

    __block UIImage *image = nil;
    __block ARError err = 0;
    __block BOOL landscape = false;

    void (^drawBlock)(void) = ^{
        id<ARDKPage> page;
        // the call to getPage: needs to be on the main thread
        page = [self->_doc getPage:pageIndex update:nil];
        assert(page);

        /* figure out what scale we need to print the page at, and if it would
         * be better to print it in landscape.
         */
        CGSize portraitZoom = CGSizeMake(printableRect.size.width/page.size.width, printableRect.size.height/page.size.height);
        CGFloat zoom = MIN(portraitZoom.width, portraitZoom.height);
        CGSize landscapeZoom = CGSizeMake(printableRect.size.height/page.size.width, printableRect.size.width/page.size.height);
        CGFloat lZoom = MIN(landscapeZoom.width, landscapeZoom.height);
        landscape = lZoom > zoom;

        ARDKBitmap *bm = [self->_doc bitmapAtSize:landscape ? CGSizeMake(printableRect.size.height, printableRect.size.width)
                                             : printableRect.size];

        // ideally we would do this render on a background thread, however
        // using the SmartOffice objects on a background thread is not currently
        // supported so we block the main thread for now.
        err = [page renderAtZoom:landscape ? lZoom : zoom withDocOrigin:CGPointMake(0, 0) intoBitmap:bm];
        if (err)
            return;

        // if we don't sanitize the image, the print preview (and actual printing,
        // at least to the Printer Simulator) just produce black images with
        // random vertical colour lines
        image = [[bm asImage] ARDKsanitizedImage];
    };

    if ( printing )
        drawBlock();
    else
        dispatch_sync(dispatch_get_main_queue(), drawBlock);

    if (err || !image)
        return;

    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    if ( printing )
        CGContextScaleCTM(currentContext, 1.0/PRINT_SCALING, 1.0/PRINT_SCALING);
    CGContextTranslateCTM(currentContext, printableRect.origin.x, printableRect.origin.y);
    if (landscape)
    {
        CGContextRotateCTM(currentContext, -M_PI_2);
        CGContextTranslateCTM(currentContext, -image.size.width, 0);
    }
    // Avoid the image being mirrored in the horizontal axis
    CGContextTranslateCTM(currentContext, 0.0, image.size.height);
    CGContextScaleCTM(currentContext, 1.0, -1.0);

    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    CGContextDrawImage(currentContext, rect, image.CGImage);
}

@end
