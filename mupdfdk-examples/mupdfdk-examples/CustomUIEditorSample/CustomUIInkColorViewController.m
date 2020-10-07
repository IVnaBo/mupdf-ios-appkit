// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "CustomUIInkColorViewController.h"

@interface CustomUIInkColorViewController () <UIPickerViewDelegate,UIPickerViewDataSource>
@property (weak, nonatomic) IBOutlet UIBarButtonItem *redButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *greenButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *blueButton;
@property UIPickerView *picker;
@property NSArray<UIColor *> *colors;
@end

@implementation CustomUIInkColorViewController

- (void)onIn
{
    [super onIn];
    self.colors = @[[UIColor blackColor],[UIColor grayColor],[UIColor whiteColor],
                    [UIColor redColor],[UIColor magentaColor],[UIColor blueColor],
                    [UIColor cyanColor],[UIColor greenColor],[UIColor yellowColor]];
    UIView *titleView = [[UIView alloc] init];
    self.picker = [[UIPickerView alloc] init];
    // Rotate picker so that it scrolls horizontally
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

    UIColor *currentColor = self.docViewController.inkAnnotationColor;
    NSInteger count = self.colors.count;
    for (NSInteger i = 0; i < count; i++)
    {
        if ([self.colors[i] isEqual:currentColor])
        {
            [self.picker selectRow:i inComponent:0 animated:NO];
            break;
        }
    }
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    self.docViewController.inkAnnotationColor = self.colors[row];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.colors.count;
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    if (!view)
    {
        view = [[UIView alloc] init];
    }

    view.backgroundColor = self.colors[row];

    return view;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return 50;
}
@end
