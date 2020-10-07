//
//  ARDKButton.m
//  smart-office-nui
//
//  Copyright © 2018 Artifex Software Inc. All rights reserved.
//

#import "ARDKButton.h"

@implementation ARDKButton
{
    NSString *_backgroundColorNameWhenSelected;
    NSString *_tintColorNameWhenSelected;
    NSString *_backgroundColorNameWhenUnselected;
    NSString *_tintColorNameWhenUnselected;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    // Ignore backgroundColor because we want the when-selected and when-unselected
    // values to override this.
}

- (void)setTintColor:(UIColor *)tintColor
{
    // Ignore tintColor because we want the when-selected and when-unselected
    // values to override this.
}

- (NSString *)backgroundColorNameWhenSelected
{
    return _backgroundColorNameWhenSelected;
}

- (void)setBackgroundColorNameWhenSelected:(NSString *)backgroundColorNameWhenSelected
{
    _backgroundColorNameWhenSelected = backgroundColorNameWhenSelected;
    if (self.selected)
    {
        NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];
        super.backgroundColor = [UIColor colorNamed:_backgroundColorNameWhenSelected inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
    }
}

- (NSString *)tintColorNameWhenSelected
{
    return _tintColorNameWhenSelected;
}

- (void)setTintColorNameWhenSelected:(NSString *)tintColorNameWhenSelected
{
    _tintColorNameWhenSelected = tintColorNameWhenSelected;
    if (self.selected)
    {
        NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];
        super.tintColor = [UIColor colorNamed:_tintColorNameWhenSelected inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
    }
}

- (NSString *)backgroundColorNameWhenUnselected
{
    return _backgroundColorNameWhenUnselected;
}

- (void)setBackgroundColorNameWhenUnselected:(NSString *)backgroundColorNameWhenUnselected
{
    _backgroundColorNameWhenUnselected = backgroundColorNameWhenUnselected;
    if (!self.selected)
    {
        NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];
        super.backgroundColor = [UIColor colorNamed:_backgroundColorNameWhenUnselected inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
    }
}

- (NSString *)tintColorNameWhenUnselected
{
    return _tintColorNameWhenUnselected;
}

- (void)setTintColorNameWhenUnselected:(NSString *)tintColorNameWhenUnselected
{
    _tintColorNameWhenUnselected = tintColorNameWhenUnselected;
    if (!self.selected)
    {
        NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];
        super.tintColor = [UIColor colorNamed:_tintColorNameWhenUnselected inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
    }
}

- (void)setSelected:(BOOL)selected
{
    NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];

    [super setSelected:selected];

    if (selected)
    {
        if (_backgroundColorNameWhenSelected)
        {
            super.backgroundColor = [UIColor colorNamed:_backgroundColorNameWhenSelected inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        }
        if (_tintColorNameWhenSelected)
        {
            super.tintColor = [UIColor colorNamed:_tintColorNameWhenSelected inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        }
    }
    else
    {
        if (_backgroundColorNameWhenUnselected)
        {
            super.backgroundColor = [UIColor colorNamed:_backgroundColorNameWhenUnselected inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        }
        if (_tintColorNameWhenUnselected)
        {
            super.tintColor = [UIColor colorNamed:_tintColorNameWhenUnselected inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
        }
    }
}

@end
