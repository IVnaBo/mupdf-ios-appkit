//
//  MuPDFDKLineWidthViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 28/04/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "MuPDFDKLineWidthViewController.h"

#define ROW_HEIGHT (14.0)
#define TEXT_WIDTH (50.0)
#define GAP (5.0)
#define EMUS_PER_PT (12700.0)

static UIFont *font()
{
    return [UIFont fontWithName:@"Helvetica" size:14];
}

@interface  MuPDFDKLineWidthView : UIView
@property CGFloat width;
@end

@implementation MuPDFDKLineWidthView

- (void)drawRect:(CGRect)rect
{
    CGContextRef cx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(cx, self.width);
    CGContextSetStrokeColorWithColor(cx, [UIColor blackColor].CGColor);
    CGContextMoveToPoint(cx, 0, self.bounds.size.height/2.0);
    CGContextAddLineToPoint(cx, self.bounds.size.width - TEXT_WIDTH - GAP, self.bounds.size.height/2.0);
    CGContextStrokePath(cx);
    CGRect textRect = CGRectMake(self.bounds.size.width - TEXT_WIDTH, 0, TEXT_WIDTH, self.bounds.size.height);
    NSDictionary *textAttrs = @{NSFontAttributeName:font()};
    [[NSString stringWithFormat:@"%g pt", self.width] drawInRect:textRect withAttributes:textAttrs];
}

@end

static const CGFloat widths[] = {0.25, 0.5, 1.0, 1.5, 3.0, 4.5, 6.0, 8.0, 12.0, 18.0, 24.0};

@interface MuPDFDKLineWidthViewController () <UIPickerViewDelegate, UIPickerViewDataSource>
@property (weak, nonatomic) IBOutlet UIPickerView *picker;
@end

@implementation MuPDFDKLineWidthViewController

@synthesize activityIndicator, docWithUI;

- (void)updateUI
{
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    CGFloat width = self.docWithUI.docView.inkAnnotationThickness;
    NSInteger count = sizeof(widths)/sizeof(*widths);
    for (NSInteger i = 0; i < count; i++)
    {
        if (widths[i] == width)
        {
            [self.picker selectRow:i inComponent:0 animated:NO];
        }
    }
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return sizeof(widths)/sizeof(*widths);
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    MuPDFDKLineWidthView *lwview = (MuPDFDKLineWidthView *)view;
    if (!lwview)
    {
        lwview = [[MuPDFDKLineWidthView alloc]init];
        lwview.width = widths[row];
    }
    return lwview;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    self.docWithUI.docView.inkAnnotationThickness = widths[row];
}

@end
