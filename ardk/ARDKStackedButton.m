//
//  ARDKStackedButton.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 15/03/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "ARDKStackedButton.h"

#define MARGIN (3)
#define OVERLAP (2)

static CGRect adjustRect(CGRect rect, UIEdgeInsets insets)
{
    return CGRectMake(rect.origin.x + insets.left,
                      rect.origin.y + insets.top,
                      rect.size.width - insets.left - insets.right,
                      rect.size.height - insets.top - insets.bottom);
}

@implementation ARDKStackedButton

- (void)initCommon:(UIImage *)image
{
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.showsTouchWhenHighlighted = true;
    self.titleLabel.textColor = [UIColor redColor];
}

- (void)tintColorDidChange
{
    [self setTitleColor:[self tintColor] forState:UIControlStateNormal];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    [self initCommon:self.imageView.image];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    [self initCommon:self.imageView.image];
    return self;
}

- (instancetype)initWithText:(NSString *)text imageName:(NSString *)imageName
{
    NSString *realImage = imageName;
    UIImage *image = nil;

    self = [super initWithFrame:CGRectZero];
    [self setTitle:text forState:UIControlStateNormal];
    
    if([imageName hasPrefix:@"oem-"])
    {
        // OEM resources may come from the main bundle
        image = [UIImage            imageNamed:realImage
                                      inBundle:[NSBundle mainBundle]
                 compatibleWithTraitCollection:nil];
        
        // If we couldn't find the asset in the main bundle, strip off the
        // 'oem-' part and drop through to attempt a load of the non-oem version
        if(image == nil)
            realImage = [imageName substringFromIndex:4];
    }
    
    if(image == nil)
    {
        image = [UIImage            imageNamed:realImage
                                      inBundle:[NSBundle bundleForClass:self.class]
                 compatibleWithTraitCollection:nil];
    }
    
    [self setImage:image forState:UIControlStateNormal];
    [self initCommon:self.imageView.image];
    return self;
}

- (UIImage *)tintedImageWithColor:(UIColor *)tintColor image:(UIImage *)image
{
    UIGraphicsBeginImageContextWithOptions(image.size, NO, [[UIScreen mainScreen] scale]);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextTranslateCTM(context, 0, image.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);

    // draw alpha-mask
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextDrawImage(context, rect, image.CGImage);

    // draw tint color, preserving alpha values of original image
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    [tintColor setFill];
    CGContextFillRect(context, rect);

    UIImage *coloredImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return coloredImage;
}

- (CGRect)titleRectForContentRect:(CGRect)contentRect
{
    CGSize imageSize = [self imageForState:UIControlStateNormal].size;
    CGRect rect = CGRectMake(contentRect.origin.x,
                             contentRect.origin.y + imageSize.height + MARGIN - OVERLAP + self.titleTopInset,
                             contentRect.size.width,
                             contentRect.size.height - imageSize.height);
    return adjustRect(rect, self.titleEdgeInsets);
}

- (CGRect)imageRectForContentRect:(CGRect)contentRect
{
    CGSize imageSize = [self imageForState:UIControlStateNormal].size;
    CGRect rect = CGRectMake(contentRect.origin.x + (contentRect.size.width - imageSize.width)/2,
                             contentRect.origin.y + MARGIN,
                             imageSize.width,
                             imageSize.height);
    return adjustRect(rect, self.imageEdgeInsets);
}

- (void)layoutSubviews
{
    // Make sure the intrinsic content size of the title accounts for
    // the limited width. Two calls to the super method are required. The
    // first ensures that width constraints applied to self are accounted
    // for in the width of the label, i.e., self.titleLabel.frame.size.width
    // is correctly set. The second is needed because setting prefferredMaxLayoutWidth
    // will affect titleLabel's reported intrinsicContentSize.
    [super layoutSubviews];
    self.titleLabel.preferredMaxLayoutWidth = self.titleLabel.frame.size.width;
    [super layoutSubviews];

    // Match the title height to its contents so as to
    // align the text to the top of its rectangle
    CGRect titleFrame = self.titleLabel.frame;
    CGSize requiredSize = self.titleLabel.intrinsicContentSize;
    titleFrame.size.height = requiredSize.height;
    self.titleLabel.frame = titleFrame;
}

- (CGSize)intrinsicContentSize
{
    CGSize isize = self.imageView.intrinsicContentSize;
    CGSize tsize = self.titleLabel.intrinsicContentSize;

    return CGSizeMake(MAX(isize.width, tsize.width), isize.height + tsize.height + 2*MARGIN + self.titleTopInset);
}

@end
