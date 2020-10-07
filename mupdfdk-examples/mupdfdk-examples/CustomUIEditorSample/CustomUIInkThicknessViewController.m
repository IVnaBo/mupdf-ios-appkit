// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "CustomUIInkThicknessViewController.h"

@interface CustomUIInkThicknessViewController () <UIPickerViewDelegate,UIPickerViewDataSource>
@property UIPickerView *picker;
@property NSArray<NSNumber *> *thicknesses;
@end

@implementation CustomUIInkThicknessViewController

- (void)onIn
{
    [super onIn];
    self.thicknesses = @[@(0.25),@(0.5),@(1),@(1.5),@(3),@(4.5),@(6),@(8),@(12),@(18),@(24)];
    UIView *titleView = [[UIView alloc] init];
    self.picker = [[UIPickerView alloc] init];
    // Rotate the picker so that it scrolls horizontally. The content of each cell is
    // rotated back the other way.
    self.picker.transform = CGAffineTransformMakeRotation(-M_PI/2);
    self.picker.delegate = self;
    self.picker.dataSource = self;
    [titleView addSubview:self.picker];
    self.picker.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *xcon = [NSLayoutConstraint constraintWithItem:titleView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.picker attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
    NSLayoutConstraint *ycon = [NSLayoutConstraint constraintWithItem:titleView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.picker attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
    NSLayoutConstraint *wcon = [NSLayoutConstraint constraintWithItem:titleView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.picker attribute:NSLayoutAttributeHeight multiplier:1 constant:0];
    NSLayoutConstraint *hcon = [NSLayoutConstraint constraintWithItem:titleView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.picker attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
    [titleView addConstraints:@[xcon,ycon,wcon,hcon]];
    self.navigationItem.titleView = titleView;

    CGFloat currentThickness = self.docViewController.inkAnnotationThickness;
    NSInteger count = self.thicknesses.count;
    for (NSInteger i = 0; i < count; i++)
    {
        if (self.thicknesses[i].doubleValue >= currentThickness)
        {
            [self.picker selectRow:i inComponent:0 animated:NO];
            break;
        }
    }
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    self.docViewController.inkAnnotationThickness = self.thicknesses[row].floatValue;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.thicknesses.count;
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel *label = (UILabel *)view;
    if (!label)
    {
        label = [[UILabel alloc] init];
        label.textAlignment = NSTextAlignmentCenter;
        label.transform = CGAffineTransformMakeRotation(M_PI/2);
    }

    label.text = [NSString stringWithFormat:@"%1.2f pt", self.thicknesses[row].floatValue];

    return label;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return 75;
}

@end
