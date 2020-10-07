//
//  DocumentListViewController.m
//  smart-office-examples
//
//  This class displays a list of all the sample documents
//  It is of no use by itself, but should be subclassed overriding
//  documentSelected:
//
//  Created by Joseph Heenan on 28/06/2016.
//  Copyright © 2016 Artifex. All rights reserved.
//

#import "DocumentListViewController.h"

#import "DirectoryWatcher.h"

@interface DocumentListViewController () <DirectoryWatcherDelegate>
@property (nonatomic, strong) DirectoryWatcher *docWatcher;
@end

@implementation DocumentListViewController
{
    NSMutableArray<NSString *> *_documents; // contains names of files in the NSDocumentDirectory
}

- (NSString *)documentsDirectory
{
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                               NSUserDomainMask,
                                               YES)[0];
}

- (void)updateDocumentsList
{
    /* Get a list of documents in the application's /Documents directory */
    NSFileManager *fileManager        = [NSFileManager defaultManager];
    NSString *documentsDirectory = [self documentsDirectory];
    _documents = [NSMutableArray arrayWithArray:[fileManager contentsOfDirectoryAtPath:documentsDirectory
                                                                                 error:nil]];
    for (NSString *doc in [_documents copy])
    {
        /* Remove any directories */
        NSString *fullPath =  [documentsDirectory stringByAppendingPathComponent:doc];
        BOOL      isDir    = NO;

        if (![fileManager fileExistsAtPath:fullPath isDirectory:&isDir] || isDir)
        {
            [_documents removeObject:doc];
        }
    }

    [_documents sortUsingSelector:@selector(caseInsensitiveCompare:)];
    if (self.isViewLoaded)
        [self.tableView reloadData];
}

- (void)directoryDidChange:(DirectoryWatcher *)folderWatcher
{
    [self updateDocumentsList];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        self.docWatcher = [DirectoryWatcher watchFolderWithPath:[self documentsDirectory] delegate:self];
        [self updateDocumentsList];
    }
    return self;
}

#pragma mark - UITableViewControllerDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _documents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"file"];

    cell.textLabel.text = _documents[indexPath.row];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *path = _documents[indexPath.row];

    [self documentSelected:path];
}

- (void)documentSelected:(NSString *)documentPath
{
    /* This method should be overriden by subclasses */
    assert(0);
}


@end
