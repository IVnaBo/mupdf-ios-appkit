// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "CustomUITOCTableViewCell.h"

#define INDENT (30)

@interface CustomUITOCTableViewCell ()
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *labelOffset;
@end

@implementation CustomUITOCTableViewCell
{
    NSInteger _level;
}

- (NSInteger)level
{
    return _level;
}

- (void)setLevel:(NSInteger)level
{
    _level = level;
    self.labelOffset.constant = level * INDENT;
}

- (NSString *)text
{
    return self.label.text;
}

- (void)setText:(NSString *)text
{
    self.label.text = text;
}


@end
