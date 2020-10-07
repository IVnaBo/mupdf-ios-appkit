// Copyright © 2018 Artifex Software Inc. All rights reserved.

#import "MuPDFDKOptionWidgetViewController.h"

@interface MuPDFDKOptionWidgetViewController () <UIPickerViewDelegate, UIPickerViewDataSource>
@property (weak, nonatomic) IBOutlet UIPickerView *picker;
@end

@implementation MuPDFDKOptionWidgetViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _currentOption = self.options[0];
}

- (IBAction)updateButtonWasTapped:(id)sender
{
    self.onUpdate();
}

- (IBAction)cancelButtonWasTapped:(id)sender
{
    self.onCancel();
}

- (NSInteger)numberOfComponentsInPickerView:(nonnull UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(nonnull UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.options.count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return self.options[row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    _currentOption = self.options[row];
}

@end
