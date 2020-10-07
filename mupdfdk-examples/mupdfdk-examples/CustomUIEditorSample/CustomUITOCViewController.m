// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "CustomUITOCViewController.h"
#import "CustomUITOCTableViewCell.h"

@interface CustomUITOCViewController ()
@property(readonly) MuPDFDKDoc *doc;
@property NSMutableArray<id<ARDKTocEntry>> *toc;
@end

@implementation CustomUITOCViewController

- (MuPDFDKDoc *)doc
{
    return (MuPDFDKDoc *)self.docView.doc;
}

- (void)addEntries:(NSArray<id<ARDKTocEntry>> *)entries
{
    for (id<ARDKTocEntry> entry in entries)
    {
        [self.toc addObject:entry];
        if (entry.children)
            [self addEntries:entry.children];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.toc = [NSMutableArray array];
    [self addEntries:self.doc.toc];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.toc.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CustomUITOCTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];

    id<ARDKTocEntry> tocEntry = self.toc[indexPath.row];
    cell.level = tocEntry.depth;
    cell.text = tocEntry.label;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.toc[indexPath.row] handleCaseInternal:^(NSInteger page, CGRect box) {
        [self.docView showPage:page withOffset:box.origin];
        [self.navigationController popViewControllerAnimated:YES];
    } orCaseExternal:^(NSURL *url) {
    }];
}

@end
