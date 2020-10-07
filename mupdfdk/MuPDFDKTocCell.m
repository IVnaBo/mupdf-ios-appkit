//
//  MuPDFDKTocCell.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 20/03/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "MuPDFDKTocCell.h"

#define INDENT (30)
#define SELECT_INTENSITY (0.5)

@interface MuPDFDKTocCell ()
@property (weak, nonatomic) IBOutlet UILabel *labelView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *labelIndent;
@end

@implementation MuPDFDKTocCell
{
    NSUInteger _depth;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        UIView *bg = [[UIView alloc] initWithFrame:self.bounds];
        bg.backgroundColor = [UIColor colorWithWhite:SELECT_INTENSITY alpha:1.0];
        self.selectedBackgroundView = bg;
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        UIView *bg = [[UIView alloc] initWithFrame:self.bounds];
        bg.backgroundColor = [UIColor colorWithWhite:SELECT_INTENSITY alpha:1.0];
        self.selectedBackgroundView = bg;
    }

    return self;
}

- (NSString *)label
{
    return self.labelView.text;
}

- (void)setLabel:(NSString *)label
{
    self.labelView.text = label;
}

- (NSUInteger)depth
{
    return _depth;
}

- (void)setDepth:(NSUInteger)depth
{
    _depth = depth;
    self.labelIndent.constant = INDENT * depth;
}

@end
