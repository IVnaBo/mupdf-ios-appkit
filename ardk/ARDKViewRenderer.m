//
//  ARDKViewRenderer.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 12/11/2015.
//  Copyright © 2015 Artifex Software Inc. All rights reserved.
//

#import "ARDKGeometry.h"
#import "ARDKLib.h"
#import "ARDKPageView.h"
#import "ARDKViewRenderer.h"

// Factor by which our rendering buffer is greater than the screen
// in both width and height
#define OVERSIZE_FACTOR (1.4)
// Offset of the rendering buffer with respect to the screen.
// Positioned so that the screen lies centrally within its area
#define OVERSIZE_OFFSET ((OVERSIZE_FACTOR - 1.0)/2)

// Arbitrary set initial size
#define SET_SIZE (25)

@interface ARDKViewRenderer ()
@property BOOL firstRenderComplete;
@property void (^afterRenderBlock)(void);
@property NSArray<ARDKBitmap *> *bitmaps;
@property int bitmapIndex;
@property BOOL renderRequested;
@property BOOL forceRenderRequested;
@property int renderCount;
@property(weak) id<ARDKViewRendererDelegate> delegate;
@property NSMutableSet<ARDKPageView *> *previouslyRenderedPages;
@property id<ARDKDoc> ardkdoc;
@property NSDictionary<NSNumber *, NSValue *> *previousScreenRects;
@end

@implementation ARDKViewRenderer
{
    BOOL _darkMode;
}

- (instancetype)initWithDelegate:(id<ARDKViewRendererDelegate>)delegate lib:(id<ARDKDoc>)ardkdoc
{
    self = [super init];
    if (self)
    {
        self.ardkdoc = ardkdoc;
        self.delegate = delegate;
        [self createBitmaps];
        self.previousScreenRects = [NSDictionary dictionary];
        [self forceRender];
    }

    return self;
}

- (BOOL)darkMode
{
    return _darkMode;
}

- (void)setDarkMode:(BOOL)darkMode
{
    BOOL changed = (darkMode != _darkMode);
    _darkMode = darkMode;
    self.delegate.bitmap.darkMode = darkMode;
    if (changed)
    {
        [self.delegate iteratePages:^(NSInteger i, UIView<ARDKPageCellDelegate> *pageView, CGRect screenRect) {
            [((ARDKPageView *)pageView) onContentChange];
        }];
        [self forceRender];
        [self triggerRender];
    }
}

- (ARDKBitmap *)bitmap
{
    return self.delegate.bitmap;
}

- (void)setBitmap:(ARDKBitmap *)bitmap
{
    self.delegate.bitmap = bitmap;
}

- (void)createBitmaps
{
    // Create bitmaps for use in alternation when rendering.
    // All the pages will make use the same one of these in any one render
    // cycle, choosing which part of it a page uses based on what area of
    // the screen the page covers. Each pair of consecutive render cycles use
    // different bitmaps.
    if (self.bitmaps == nil)
    {
        CGSize bmSize = ARCGSizeScale([UIScreen mainScreen].bounds.size, [UIScreen mainScreen].scale);
        if (self.bitmap == nil)
        {
            // Make a bitmap with room for 4 screens. This is a good size for all current rendering
            // strategies.
            self.bitmap = [self.ardkdoc bitmapAtSize:CGSizeMake(bmSize.width, bmSize.height * 4)];
        }

        // For this view renderer, we need the overall bitmap split into 2 screen sizes with some
        // overlap
        bmSize = ARCGSizeScale(bmSize, OVERSIZE_FACTOR);
    }
}

- (void)adjustBitmapsToSize:(CGSize)size
{
    if (self.bitmaps == nil || self.bitmaps[0].width < size.width || self.bitmaps[0].height < size.height)
    {
        [self.bitmap adjustToWidth:size.width];
        assert(self.bitmap.height >= size.height * 2);
        CGRect rect = {CGPointZero, size};
        ARDKBitmap *bm0 = [ARDKBitmap bitmapFromSubarea:rect ofBitmap:self.bitmap];
        rect.origin.y += size.height;
        ARDKBitmap *bm1 = [ARDKBitmap bitmapFromSubarea:rect ofBitmap:self.bitmap];
        self.bitmaps = [NSArray arrayWithObjects:bm0, bm1, nil];
    }
}

- (CGRect)viewRectToBitmapRect:(CGRect)rect basedOn:(CGRect)renderRect
{
    return ARCGRectScale(CGRectOffset(rect, -renderRect.origin.x, -renderRect.origin.y),
                       [UIScreen mainScreen].scale);
}

/// Enumerate currently represented pages performing render
- (void)renderPages
{
    self.renderRequested = NO;

    CGSize required = ARCGSizeScale(self.delegate.view.bounds.size, [UIScreen mainScreen].scale * OVERSIZE_FACTOR);
    // Make sure we have the screen bitmap configured with an aspect to match
    // the screen
    [self adjustBitmapsToSize:required];

    // Test whether any pages have changed scale or moved sufficiently to uncover nonrendered areas
    CGSize offsetSize = ARCGSizeScale(self.delegate.view.bounds.size, OVERSIZE_OFFSET);

    CGRect renderRect;
    renderRect.size = ARCGSizeScale(self.delegate.view.bounds.size, OVERSIZE_FACTOR);
    renderRect.origin = CGPointMake(-offsetSize.width, -offsetSize.height);

    if (!self.forceRenderRequested)
    {
        __block BOOL renderNeeded = NO;
        [self.delegate iteratePages:^(NSInteger i, UIView<ARDKPageCellDelegate> *pageView, CGRect screenRect) {
            if (pageView && CGRectIntersectsRect(screenRect, renderRect))
            {
                if (renderNeeded)
                    return; // Already decided

                if (!self.previousScreenRects[@(i)])
                {
                    // There's a page not previously rendered
                    renderNeeded = YES;
                    return;
                }

                CGRect previousScreenRect = self.previousScreenRects[@(i)].CGRectValue;
                if (previousScreenRect.size.width != screenRect.size.width || previousScreenRect.size.height != screenRect.size.height)
                {
                    // Change of scale
                    renderNeeded = YES;
                    return;
                }

                if (fabs(screenRect.origin.x - previousScreenRect.origin.x) >= offsetSize.width/2.0
                    || fabs(screenRect.origin.y - previousScreenRect.origin.y) >= offsetSize.height/2.0)
                {
                    // Change of position sufficient to uncover nonrendered content
                    renderNeeded = YES;
                    return;
                }
            }
        }];

        if (!renderNeeded)
            return;
    }

    self.forceRenderRequested = NO;

    NSMutableDictionary<NSNumber *,NSValue *> *screenRects = [NSMutableDictionary dictionary];

    NSMutableSet<ARDKPageView *> *renderedPages = [NSMutableSet setWithCapacity:SET_SIZE];

    // Swap which screen sized bitmap we use on each pass through telling
    // the current PageViews to update themselves.
    self.bitmapIndex = (self.bitmapIndex + 1) % 2;

    [self.delegate iteratePages:^(NSInteger i, UIView<ARDKPageCellDelegate> *pageView, CGRect screenRect) {
        if (pageView && CGRectIntersectsRect(screenRect, renderRect))
        {
            [screenRects setObject:@(screenRect) forKey:@(i)];

            // Calculate the rendering scale
            CGFloat pageScale = screenRect.size.width / pageView.bounds.size.width;

            // Calculate the part of the enlarged view the page covers
            CGRect partRect = CGRectIntersection(screenRect, renderRect);

            // Get the corresponding part of the bitmap
            CGRect bmRect = [self viewRectToBitmapRect:partRect basedOn:renderRect];

            // Calculate the part of the page view that is to be rendered
            CGRect pageViewRect = ARCGRectScale(CGRectOffset(partRect, -screenRect.origin.x, -screenRect.origin.y), 1 / pageScale);

            // Use the area of screen covered by the PageView to select a part of the current
            // screen bitmap for use in generating a UIImageView. The UIImageView will initially
            // appear initially exactly in that position, but may be panned and zoomed before
            // eventually being replaced by another.
            ARDKBitmap *bm = [ARDKBitmap bitmapFromSubarea:bmRect ofBitmap: self.bitmaps[self.bitmapIndex]];

            // Calculate the overall scale accounting for retinal scaling.
            CGFloat retinalScale = [UIScreen mainScreen].scale * pageScale;

            // Count up as we kick off rendering of each visible page
            self.renderCount++;
            // Record which page views we render
            [renderedPages addObject:(ARDKPageView *)pageView];
            // Knock out each from the previously rendered set so we can see at the end
            // which we've missed
            [self.previouslyRenderedPages removeObject:(ARDKPageView *)pageView];
            [(ARDKPageView *)pageView displayArea:pageViewRect atScale:retinalScale usingBitmap:bm whenDone:^{
                // Count down as they complete
                self.renderCount--;

                if (self.renderCount == 0)
                {
                    self.firstRenderComplete = YES;
                    if (self.afterRenderBlock)
                    {
                        self.afterRenderBlock();
                        self.afterRenderBlock = nil;
                    }
                }

                // If this phase of rendering has completed and another has
                // been requested, start it now
                if (self.renderCount == 0 && self.renderRequested)
                    [self renderPages];
            }];
        }
    }];

    self.previousScreenRects = screenRects;

    // Mark the previously rendered pages that we've missed this pass
    for (ARDKPageView *pageView in self.previouslyRenderedPages)
    {
        [pageView missRenderPass];
    }

    self.previouslyRenderedPages = renderedPages;
}

- (void)triggerRender
{
    // Note that a render is needed
    self.renderRequested = YES;
    // If the previous render has completed, start a new one. Otherwise
    // a new one will start as soon as the previous one completes.
    if (self.renderCount == 0)
        [self renderPages];
}

- (void)forceRender
{
    self.forceRenderRequested = YES;
}

- (void) afterFirstRender:(void (^)(void))block
{
    if (self.firstRenderComplete)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            block();
        });
    }
    else
    {
        self.afterRenderBlock = block;
    }
}

@end
