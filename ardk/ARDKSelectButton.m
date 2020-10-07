//
//  ARDKSelectButton.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 12/01/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "ARDKSelectButton.h"

@interface ARDKSelectButton ()
@property UIColor *backgroundColorWhenUnselected;
@property UIColor *tintColorWhenUnselected;
@end

@implementation ARDKSelectButton
{
    UIColor *_backgroundColorWhenSelected;
    
    NSString *_backgroundColorNameWhenSelected;
    NSString *_tintColorNameWhenSelected;
    NSString *_tintColorNameWhenUnselected;
}

- (UIColor *)backgroundColorWhenSelected
{
    return _backgroundColorWhenSelected;
}

- (void)setBackgroundColorWhenSelected:(UIColor *)backgroundColorWhenSelected
{
    _backgroundColorWhenSelected = backgroundColorWhenSelected;
    self.backgroundColorWhenUnselected = self.backgroundColor;
}

- (NSString *)backgroundColorNameWhenSelected
{
    return _backgroundColorNameWhenSelected;
}

- (void)setBackgroundColorNameWhenSelected:(NSString *)backgroundColorNameWhenSelected
{
    _backgroundColorNameWhenSelected = backgroundColorNameWhenSelected;
    self.backgroundColorWhenUnselected = self.backgroundColor;

    NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];
    self.backgroundColorWhenSelected = [UIColor colorNamed:_backgroundColorNameWhenSelected inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
}

- (NSString *)tintColorNameWhenSelected
{
    return _tintColorNameWhenSelected;
}

- (void)setTintColorNameWhenSelected:(NSString *)tintColorNameWhenSelected
{
    _tintColorNameWhenSelected = tintColorNameWhenSelected;

    NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];
    self.tintColorWhenSelected = [UIColor colorNamed:_tintColorNameWhenSelected inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
}

- (NSString *)tintColorNameWhenUnselected
{
    return _tintColorNameWhenUnselected;
}

- (void)setTintColorNameWhenUnselected:(NSString *)tintColorNameWhenUnselected
{
    _tintColorNameWhenUnselected = tintColorNameWhenUnselected;

    NSBundle *frameWorkBundle = [NSBundle bundleForClass:[self class]];
    self.tintColorWhenUnselected = [UIColor colorNamed:_tintColorNameWhenUnselected inBundle:frameWorkBundle compatibleWithTraitCollection:nil];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.backgroundColorWhenUnselected = self.backgroundColor;
        self.tintColorWhenUnselected = self.tintColor;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        self.backgroundColorWhenUnselected = self.backgroundColor;
        self.tintColorWhenUnselected = self.tintColor;
    }
    return self;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    if (self.backgroundColorWhenSelected)
        self.backgroundColor = selected ? self.backgroundColorWhenSelected : self.backgroundColorWhenUnselected;
    if (self.tintColorWhenSelected)
        [super setTintColor:(selected ? self.tintColorWhenSelected : self.tintColorWhenUnselected)];
    [super setSelected:selected];
}

-(void)setTintColor:(UIColor *)tintColor{
    //In case we want to apply tint colours to the uiimage, the behaviour will be the same if the color is equal to the titlecolor.
    if (tintColor == [self titleColorForState:UIControlStateNormal]){
        self.tintColorWhenUnselected = [self titleColorForState:UIControlStateNormal];
        self.tintColorWhenSelected = [self titleColorForState:UIControlStateSelected];
    }
    [super setTintColor:tintColor];
}


@end
