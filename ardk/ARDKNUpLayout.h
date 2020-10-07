//
//  ARDKNUpLayout.h
//  smart-office-nui
//
//  Created by Paul Gardiner on 23/03/2015.
//  Copyright (c) 2015 Artifex Software Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ARDKNUpLayout : UICollectionViewLayout
/// The width of the view into which to layout pages
@property CGFloat viewWidth;
/// The size of each page
@property CGSize cellSize;
/// Number of pages
@property NSInteger pageCount;
/// Number of pages to fit within the width of the view
@property NSInteger nup;
/// Currently viewed area in layout coords. We are using
@property CGRect viewedArea;
/// The zoom factor to exactly fit the maximum N-up
@property(readonly) CGFloat minZoom;
/// The zoom factor to exactly fit the current N-up
@property(readonly) CGFloat fitZoom;
/// The best N-up value given the current viewed area
@property(readonly) NSInteger suggestedNup;
/// The currently viewed pages based on the last setting of viewedArea
@property(readonly) NSArray *viewedPages;

/// The frame for a page, without alteration for the sake
/// of the specific aspect ratio of that page
- (CGRect)pageFrame:(NSInteger)page;

/// Show at least these pages, ignoring the last setting of viewedArea
- (void)viewPages:(NSArray *)pages;

@end
