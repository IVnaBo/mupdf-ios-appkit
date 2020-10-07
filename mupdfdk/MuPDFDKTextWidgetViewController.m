// Copyright © 2018 Artifex Software Inc. All rights reserved.

#import "MuPDFDKTextWidgetViewController.h"

@interface MuPDFDKTextWidgetViewController ()
@property (weak, nonatomic) IBOutlet UITextView *textView;
@end

@implementation MuPDFDKTextWidgetViewController
{
    NSString *_text;
}

- (NSString *)text
{
    return self.textView ? self.textView.text : _text;
}

- (void)setText:(NSString *)text
{
    _text = text;
    // May do nothing if textView yet to be created, but
    // in that case the line in viewDidLoad will pass on the value
    self.textView.text = text;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.textView.text = _text;
    [self.textView becomeFirstResponder];
}

- (IBAction)updateButtonWasTapped:(id)sender
{
    self.onUpdate();
}

- (IBAction)cancelButtonWasTapped:(id)sender
{
    self.onCancel();
}

@end
