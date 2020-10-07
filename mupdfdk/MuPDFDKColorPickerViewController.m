//
//  MuPDFDKColorPickerViewController.m
//  smart-office-nui
//
//  Created by Paul Gardiner on 18/02/2016.
//  Copyright © 2016 Artifex Software Inc. All rights reserved.
//

#import "MuPDFDKColorPickerCell.h"
#import "MuPDFDKColorPickerViewController.h"

#define BORDER_WIDTH (3)
#define NO_INDEX (-1)

static UIColor *colorFromHex(unsigned hex)
{
    return [UIColor colorWithRed:((hex & 0xFF0000)>>16)/255.0 green:((hex & 0xFF00)>>8)/255.0 blue:(hex & 0xFF)/255.0 alpha:1.0];
}

@interface MuPDFDKColorPickerViewController () <UICollectionViewDataSource,UICollectionViewDelegate>
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property NSArray<UIColor *> *colors;
@property NSInteger currentIndex;
@end

@implementation MuPDFDKColorPickerViewController

@synthesize docWithUI, activityIndicator;

- (void)updateUI
{

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.colors = @[colorFromHex(0x000000),
                    colorFromHex(0xFFFFFF),
                    colorFromHex(0xD8D8D8),
                    colorFromHex(0x808080),
                    colorFromHex(0xEEECE1),
                    colorFromHex(0x1F497D),
                    colorFromHex(0x0070C0),
                    colorFromHex(0xC0504D),
                    colorFromHex(0x9BBB59),
                    colorFromHex(0x8064A2),
                    colorFromHex(0x4BACC6),
                    colorFromHex(0xF79646),
                    colorFromHex(0xFF0000),
                    colorFromHex(0xFFFF00),
                    colorFromHex(0xDBE5F1),
                    colorFromHex(0xF2DCDB),
                    colorFromHex(0xEBF1DD),
                    colorFromHex(0x00B050)];

    UIColor *currentColor = self.docWithUI.docView.inkAnnotationColor;

    // Look for a color that matches the current one
    self.currentIndex = NO_INDEX;
    for (NSInteger i = 0; i < self.colors.count; i++)
    {
        if ([self.colors[i] isEqual:currentColor])
            self.currentIndex = i;
    }
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.colors.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    MuPDFDKColorPickerCell *cell;

    if ([self.colors[indexPath.item] isEqual:[UIColor colorWithWhite:0 alpha:0]])
    {
        cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"TransparentCell" forIndexPath:indexPath];
    }
    else
    {
        cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"ColoredCell" forIndexPath:indexPath];
        cell.square.backgroundColor = self.colors[indexPath.item];
    }

    // Highlight the currently selected color
    if (indexPath.item == self.currentIndex)
        cell.outer.layer.borderWidth = BORDER_WIDTH;

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    self.docWithUI.docView.inkAnnotationColor = self.colors[indexPath.item];

    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
