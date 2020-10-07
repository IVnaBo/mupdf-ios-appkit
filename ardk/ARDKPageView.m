//
//  ARDKPageView.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 05/07/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKGeometry.h"
#import "ARDKImageViewMatrix.h"
#import "ARDKPageView.h"

static NSArray<NSValue *> *rectMinus(CGRect whole, CGRect part)
{
    NSMutableArray<NSValue *> *res = [NSMutableArray arrayWithCapacity:2];
    if (CGRectIntersectsRect(whole, part))
    {
        CGRect slice, remainder;
        CGFloat d = CGRectGetMinY(part) - CGRectGetMinY(whole);
        if (d > 0)
        {
            CGRectDivide(whole, &slice, &remainder, d, CGRectMinYEdge);
            [res addObject:[NSValue valueWithCGRect:slice]];
            whole = remainder;
        }

        d = CGRectGetMaxY(whole) - CGRectGetMaxY(part);
        if (d > 0)
        {
            CGRectDivide(whole, &slice, &remainder, d, CGRectMaxYEdge);
            [res addObject:[NSValue valueWithCGRect:slice]];
            whole = remainder;
        }

        d = CGRectGetMinX(part) - CGRectGetMinX(whole);
        if (d > 0)
        {
            CGRectDivide(whole, &slice, &remainder, d, CGRectMinXEdge);
            [res addObject:[NSValue valueWithCGRect:slice]];
            whole = remainder;
        }

        d = CGRectGetMaxX(whole) - CGRectGetMaxX(part);
        if (d > 0)
        {
            CGRectDivide(whole, &slice, &remainder, d, CGRectMaxXEdge);
            [res addObject:[NSValue valueWithCGRect:slice]];
        }
    }
    else
    {
        [res addObject:[NSValue valueWithCGRect:whole]];
    }

    return res;
}

@interface ARDKPageView ()
@property CGRect layoutFrame;
@property CGRect bmRect;
@property CGFloat scale;
@property NSInteger pageNumber;
@property id<ARDKPage> page;
@property id<ARDKRender> updateRender;
@property NSMutableArray<id<ARDKRender>> *displayRenders;
@property CGFloat renderZoom;
@property ARDKBitmap *bm;
@property ARDKImageViewMatrix *tiles;
@property NSMutableArray<NSValue *> *requestedUpdates;
@property UIView *selectionHighlight; ///< Current page indicator in pages view / slide sorter
@property BOOL contentChanged;
@end

#define HIGHLIGHT_THICKNESS (5.0)
#define BORDER_LUM (0x8a)
#define MAX_QUEUED_UPDATES (5)

@implementation ARDKPageView
{
    id<ARDKDoc> _doc;
}

+ (CGSize) adjustSize:(CGSize)size toPage:(id<ARDKPage>)page
{
    // Use the width of the specified size and a height to match the page's aspect ratio
    CGSize pageSize = page.size;
    return CGSizeMake(size.width, size.width * pageSize.height / pageSize.width);
}

+ (CGAffineTransform)transformForPage:(id<ARDKPage>)page withinFrame:(CGRect)frame
{
    CGSize pageSize = page.size;
    // Calculate the zoom factors that would map the page to the frame
    CGFloat baseZoom = MIN(frame.size.width/pageSize.width, frame.size.height/pageSize.height);
    CGSize size = ARCGSizeScale(pageSize, baseZoom);
    frame = ARCGRectAdjustSizeAboutCenter(frame, size);
    // Return a transform that first scales and then translates (how this is written in Apple's
    // API is surprising)
    return CGAffineTransformScale(CGAffineTransformMakeTranslation(frame.origin.x, frame.origin.y), baseZoom, baseZoom);
}

- (instancetype)initWithDoc:(id<ARDKDoc>)doc
{
    self = [super initWithFrame:CGRectZero];
    if (self)
    {
        self.backgroundColor = [UIColor whiteColor];
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor colorWithWhite:BORDER_LUM/255.0 alpha:1.0].CGColor;
        self.backgroundColor = [UIColor whiteColor];
        self.requestedUpdates = [NSMutableArray array];
        // Create a view to contain the matrix if image views, used to
        // display the page contents. Using this separate view,
        // rather than attaching the image views directly, avoids
        // z-ordering problems.
        UIView *matrixContainer = [[UIView alloc] initWithFrame:CGRectZero];
        [self addSubview:matrixContainer];
        self.tiles = [ARDKImageViewMatrix matrixForView:matrixContainer];

        self.displayRenders = [NSMutableArray array];
        _doc = doc;
    }

    return self;
}

- (void)setSelected:(BOOL)selected
{
    if (self.doc && !self.selectionHighlight)
    {
        self.selectionHighlight = [[UIView alloc] init];
        self.selectionHighlight.backgroundColor = self.highlightColor;
        [self addSubview:self.selectionHighlight];
        [self sendSubviewToBack:self.selectionHighlight];
        [self resizeOverlays];
    }

    self.selectionHighlight.hidden = !selected;
}

- (void) resizeOverlays
{
    self.selectionHighlight.frame = CGRectInset(self.bounds, -HIGHLIGHT_THICKNESS, -HIGHLIGHT_THICKNESS);
}

- (id<ARDKDoc>) doc
{
    return _doc;
}

- (void)onContentChange
{
    self.contentChanged = YES;
}

- (void)requestUpdate:(CGRect)area
{
    if (self.updatesDisabled)
        return;
    // Add the new update to the queue
    [self.requestedUpdates addObject:[NSValue valueWithCGRect:area]];
    // If we've queued too many updates, combine them into one
    if (self.requestedUpdates.count > MAX_QUEUED_UPDATES)
    {
        CGRect rect = CGRectNull;

        for (NSValue *val in self.requestedUpdates)
            rect = CGRectUnion(rect, val.CGRectValue);

        [self.requestedUpdates removeAllObjects];
        [self.requestedUpdates addObject:[NSValue valueWithCGRect:rect]];
    }

    // If there is no current display renders running, kick off the update process
    if (self.displayRenders.count == 0 && self.updateRender == nil)
        [self performUpdate];
}

- (void)performUpdate
{
    if(self.bm && !CGRectIsNull(self.bmRect))
    {
        CGRect iArea;

        assert(self.requestedUpdates.count > 0);
        // Drop updates until we find one that overlaps the currently viewed area
        do
        {
            CGRect area = self.requestedUpdates[0].CGRectValue;
            [self.requestedUpdates removeObjectAtIndex:0];

            // self.bmRect is the part of the scaled up page the bitmap represents
            // iArea is the part of the scaled up page we wish to render
            iArea = CGRectIntegral(ARCGRectScale(area, self.renderZoom));
            iArea = CGRectIntersection(iArea, self.bmRect);
        } while (CGRectIsEmpty(iArea) && self.requestedUpdates.count > 0);

        if (CGRectIsEmpty(iArea))
            return;

        // The part of the bitmap to which we wish to render
        CGRect bmSub = CGRectOffset(iArea, -self.bmRect.origin.x, -self.bmRect.origin.y);
        ARDKBitmap *bmPart = [ARDKBitmap bitmapFromSubarea:bmSub ofBitmap:self.bm];

        self.updateRender = [self.page updateAtZoom:self.renderZoom
                                withDocOrigin:ARCGPointScale(iArea.origin, -1)
                                   intoBitmap: bmPart
                                     progress:^(ARError error)
                       {
                           if (error == 0)
                           {
                               if (self.onUpdate)
                                   self.onUpdate();

                               [self.tiles updateArea:iArea];
                           }

                           self.updateRender = nil;

                           if (self.requestedUpdates.count > 0)
                               [self performUpdate];
                       }];
    }
    else
    {
        // If bm or bmRect are NULL then we can rely on a future displayArea call
        [self.requestedUpdates removeAllObjects];
    }
}

/// Set the pages frame to position it centrally within a rectangle
/// of a given size
- (CGRect)positionWithinFrame:(CGRect)frame
{
    CGSize pageSize = self.page.size;
    if (pageSize.width == 0 || pageSize.height == 0)
    {
        // There are circumstances where we can get here with a page
        // that has just been removed from the document. Just use
        // default values in that case.
        self.baseZoom = 1.0;
        return frame;
    }

    if (self.maxAspect > 0.0)
    {
        pageSize = CGSizeMake(MIN(pageSize.width, pageSize.height * self.maxAspect),
                              MIN(pageSize.height, pageSize.width * self.maxAspect));
    }

    // Calculate the zoom factors that would map the page to the frame
    self.baseZoom = MIN(frame.size.width/pageSize.width, frame.size.height/pageSize.height);
    CGSize size = ARCGSizeScale(pageSize, self.baseZoom);
    if (self.positionPageTopLeft)
        frame.size = size;
    else
        frame = ARCGRectAdjustSizeAboutCenter(frame, size);

    return frame;
}

- (void)displayArea:(CGRect)area atScale:(CGFloat)scale usingBitmap:(ARDKBitmap *)bm whenDone:(void (^)(void))block
{
    CGRect irect    = CGRectIntegral(ARCGRectScale(area, scale));
    // Restrict the area to the size of the bitmap provided (because of use of floats could be too big by 1 pixel)
    irect.size = CGSizeMake(MIN(irect.size.width, bm.width), MIN(irect.size.height, bm.height));

    if (CGRectIsEmpty(irect))
    {
        [self missRenderPass];
        dispatch_async(dispatch_get_main_queue(), ^{
            block();
        });
    }
    else
    {
        __block int renderProcessCount = 0;
        CGRect lastRect = self.bmRect;
        ARDKBitmap *lastBm = self.bm;
        if (self.updateRender || scale != self.scale || self.contentChanged)
        {
            // If there was an update render going or if the area to be rendered has changed
            // better not reuse any of the tiles in the image view matrix, or copy any data
            // from the previously used bitmap.
            lastRect = CGRectNull;
            [self.tiles requestReset];
        }

        self.contentChanged = NO;
        self.bmRect = irect;
        self.tiles.scale = scale;
        self.tiles.width = self.bounds.size.width;
        self.scale = scale;
        self.renderZoom = scale * self.baseZoom;
        self.bm = bm;

        // Abort the update render if there is one
        [self.updateRender abort];
        self.updateRender = nil;

        // This function will be called when all processing of the bitmap (copying and rendering to) is complete
        void (^onRenderFinished)(void) = ^(void){
            [self.tiles displayArea:self.bmRect usingBitmap:self.bm onComplete:^{
                [self.displayRenders removeAllObjects];

                if (self.requestedUpdates.count > 0)
                    [self performUpdate];

                block();
            }];
        };

        // Copy from previous bitmap to the new one for any overlap area
        CGRect overlapArea = CGRectIntersection(lastRect, irect);
        if (!CGRectIsNull(overlapArea))
        {
            renderProcessCount++;
            // Pull out the overlap part from both bitmaps
            ARDKBitmap *src = [ARDKBitmap bitmapFromSubarea:CGRectOffset(overlapArea, -lastRect.origin.x, -lastRect.origin.y) ofBitmap:lastBm];
            ARDKBitmap *tgt = [ARDKBitmap bitmapFromSubarea:CGRectOffset(overlapArea, -irect.origin.x, -irect.origin.y) ofBitmap:bm];
            // Perform the copy on a background thread
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [tgt copyFrom:src];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (--renderProcessCount == 0)
                        onRenderFinished();
                });
            });
        }

        // Render any new area
        for (NSValue *val in rectMinus(irect, lastRect))
        {
            renderProcessCount++;
            CGRect renderArea = val.CGRectValue;
            id<ARDKRender> render = [self.page renderAtZoom:self.renderZoom
                                              withDocOrigin:ARCGPointScale(renderArea.origin, -1)
                                                 intoBitmap:[ARDKBitmap bitmapFromSubarea:CGRectOffset(renderArea, -irect.origin.x, -irect.origin.y) ofBitmap:bm]
                                                   progress:^(ARError error)
            {
                if (--renderProcessCount == 0)
                    onRenderFinished();
            }];
            [self.displayRenders addObject:render];
        }

        assert(renderProcessCount > 0);
    }
}

- (void)abortRenders
{
    [self.updateRender abort];
    for (id<ARDKRender> render in self.displayRenders)
        [render abort];
}

- (void)missRenderPass
{
    [self abortRenders];
    self.updateRender = nil;
    [self.displayRenders removeAllObjects];
    self.bmRect = CGRectNull;
    self.bm = nil;
    [self.tiles clear];
}

- (void)reset
{
    self.page = nil;
    self.bmRect = CGRectNull;
    [self abortRenders];
    [self.tiles clear];
    self.selectionHighlight.hidden = YES;
}

- (void)prepareForReuse
{
    [self reset];
}

- (void)useForPageNumber:(NSInteger)pageNumber withSize:(CGSize)size
{
    BOOL pageChange = (self.pageNumber != pageNumber);
    BOOL sizeChange = !CGSizeEqualToSize(self.layoutFrame.size, size);

    if (pageChange || !self.page)
    {
        self.pageNumber = pageNumber;
        __weak typeof(self) weakSelf = self;
        self.page = [self.doc getPage:pageNumber update:^(CGRect area) {
            [weakSelf requestUpdate:area];
        }];
    }

    if (sizeChange)
    {
        CGRect layoutFrame = {CGPointZero, size};
        self.layoutFrame = layoutFrame;
        self.frame = self.page ? [self positionWithinFrame:self.layoutFrame] : self.layoutFrame;
    }

    if (pageChange || sizeChange)
    {
        [self resizeOverlays];
        self.tiles.width = self.bounds.size.width;
        self.bmRect = CGRectNull;
    }
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    if (newSuperview == nil)
        [self reset];
}

- (void) dealloc
{
    [self abortRenders];
}

@end
