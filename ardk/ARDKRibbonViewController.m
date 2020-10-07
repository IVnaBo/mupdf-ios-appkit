// Copyright © 2020 Artifex Software Inc. All rights reserved.

#import "ARDKDocSession.h"
#import "ARDKRibbonViewController.h"

// All localized string in this file should be obtained from the sodk framework
#undef NSLocalizedString
#define NSLocalizedString(key, comment) NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:self.class], comment)

#define OVERSIZE_THRESHOLD (50.0)
#define ANIMATION_DURATION (1.0)
#define HOLD_OFF_MAX (10)
#define HOLD_OFF_FOR_GOOD (-1)

@interface ARDKRibbonViewController () <UIScrollViewDelegate>
@property BOOL animationShouldContinue;
@property NSInteger ribbonScrollWarningHoldOff;
@property BOOL hasScrolled;
@end

@implementation ARDKRibbonViewController

- (UIScrollView *)findScrollView
{
    for (UIView *view in self.view.subviews)
    {
        if ([view isKindOfClass:UIScrollView.class])
            return (UIScrollView *)view;
    }

    return nil;
}

- (NSInteger)ribbonScrollWarningHoldOff
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:ARDK_RibbonScrollWarningHoldOff];
}

- (void)setRibbonScrollWarningHoldOff:(NSInteger)ribbonScrollWarningHoldOff
{
    [[NSUserDefaults standardUserDefaults] setInteger:ribbonScrollWarningHoldOff forKey:ARDK_RibbonScrollWarningHoldOff];
}

- (void)startAnimation
{
    UIScrollView *scrollView = [self findScrollView];

    if (scrollView)
    {
        CGFloat slack = scrollView.contentSize.width - scrollView.bounds.size.width;
        if (slack > OVERSIZE_THRESHOLD)
        {
            [UIView animateWithDuration:ANIMATION_DURATION delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                scrollView.contentOffset = CGPointMake(slack, 0.0);
                [scrollView layoutIfNeeded];
            } completion:^(BOOL finished) {
                if (finished)
                {
                    [UIView animateWithDuration:ANIMATION_DURATION delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                        scrollView.contentOffset = CGPointZero;
                        [scrollView layoutIfNeeded];
                    } completion:^(BOOL finished) {
                        if (self.animationShouldContinue)
                            [self startAnimation];
                    }];
                }
            }];
        }
    }
}

- (void)showAlert
{
    NSString *title = NSLocalizedString(@"Some button bars are scrollable",
                                        @"Title of alert view informing the user that part of the UI scrolls.");
    NSString *message = NSLocalizedString(@"Some button bars are too long to fit the screen, and some buttons may be hidden.\nYou can scroll the bar to see what is hidden.",
                                          @"Message of alert view informing the user that part of the UI scrolls.");
    NSString *dismissMessage = NSLocalizedString(@"OK", @"Button title for dismissing alert view.");
    NSString *dimissForGoodMessage = NSLocalizedString(@"Never show this again",
                                                @"Button title for dismissing alert view and requesting not to see it again.");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *dismiss = [UIAlertAction actionWithTitle:dismissMessage style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.animationShouldContinue = NO;
        self.ribbonScrollWarningHoldOff = HOLD_OFF_MAX-1;
    }];
    [alert addAction:dismiss];

    UIAlertAction *dismissForGood = [UIAlertAction actionWithTitle:dimissForGoodMessage style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        self.animationShouldContinue = NO;
        self.ribbonScrollWarningHoldOff = HOLD_OFF_FOR_GOOD;
    }];
    [alert addAction:dismissForGood];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    UIScrollView *scrollView = [self findScrollView];

    if (scrollView)
    {
        CGFloat slack = scrollView.contentSize.width - scrollView.bounds.size.width;
        if (slack > OVERSIZE_THRESHOLD)
        {
            if (self.ribbonScrollWarningHoldOff >= 0)
            {
                if (self.ribbonScrollWarningHoldOff == 0)
                {
                    self.animationShouldContinue = YES;
                    [self startAnimation];
                    [self showAlert];
                }
                else
                {
                    self.ribbonScrollWarningHoldOff--;
                    // Monitor scrolling: if the user scrolls the bar then we
                    // can hold off on the warnings.
                    self.hasScrolled = NO;
                    scrollView.delegate = self;
                }
            }
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!self.hasScrolled && scrollView.contentOffset.x > 0.0)
    {
        self.hasScrolled = YES;
        // The user has scrolled a ribbon. If we are still giving
        // warnings, hold off on them.
        if (self.ribbonScrollWarningHoldOff >= 0)
            self.ribbonScrollWarningHoldOff = HOLD_OFF_MAX-1;
    }
}

@end
