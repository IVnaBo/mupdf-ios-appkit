//
//  ARDKRibbonItemStackedButton.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 28/02/2017.
//  Copyright © 2017 Artifex Software Inc. All rights reserved.
//

#import "ARDKStackedButton.h"
#import "ARDKRibbonItemStackedButton.h"

#define FONT_SIZE (11)
#define FONT_COLOR (0x333333)

@implementation ARDKRibbonItemStackedButton

- (instancetype)initWithText:(NSString *)text imageName:(NSString *)imageName selectedImageName:(NSString *)selectedImageName
                       width:(CGFloat)width target:(id)target action:(SEL)action
{
    self = [super init];
    if (self)
    {
        NSBundle *bundle    = [NSBundle bundleForClass:[self class]];
        UIColor  *textColor = [UIColor colorNamed:@"so.ui.menu.ribbon.font.color" inBundle:bundle compatibleWithTraitCollection:nil];
        UIColor  *disabledColor = [UIColor colorNamed:@"so.ui.menu.ribbon.font.disabled.color" inBundle:bundle compatibleWithTraitCollection:nil];

        ARDKStackedButton *button = [[ARDKStackedButton alloc] initWithText:text imageName:imageName];
        if (selectedImageName)
            [button setImage:[UIImage imageNamed:selectedImageName inBundle:[NSBundle bundleForClass:self.class] compatibleWithTraitCollection:nil] forState:UIControlStateSelected];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        button.titleLabel.font = [UIFont systemFontOfSize:FONT_SIZE];
        [button setTitleColor:textColor forState:UIControlStateNormal];
        [button setTitleColor:disabledColor forState:UIControlStateDisabled];
        [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        self.view = button;
        NSLayoutConstraint *constraint;
        constraint = [NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:width];
        [self.view addConstraint:constraint];
    }

    return self;
}

+ (ARDKRibbonItemStackedButton *)itemWithText:(NSString *)text imageName:(NSString *)imageName width:(CGFloat)width target:(id)target action:(SEL)action
{
    return [[ARDKRibbonItemStackedButton alloc] initWithText:text imageName:imageName selectedImageName:nil width:width target:target action:action];
}

+ (ARDKRibbonItemStackedButton *)itemWithText:(NSString *)text imageName:(NSString *)imageName selectedImageName:(NSString *)selectedImageName width:(CGFloat)width target:(id)target action:(SEL)action
{
    return [[ARDKRibbonItemStackedButton alloc] initWithText:text imageName:imageName selectedImageName:selectedImageName width:width target:target action:action];
}

- (void)updateUI
{
    UIButton *button = (UIButton *)self.view;

    if (self.enableCondition)
        button.enabled = self.enableCondition();

    if (self.selectCondition)
        button.selected = self.selectCondition();

    if (self.hiddenCondition)
        button.hidden = self.hiddenCondition();
}

@end
