// Copyright © 2019 Paul Gardiner. All rights reserved.

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)copySampleDocs
{
    // Copy the sample docs from our bundle into the document's folder,
    // just to provide some initial content within the sample app.
    NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                            NSUserDomainMask,
                                                            YES)[0];

    NSString *srcPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"samples"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;

    NSArray<NSString *> *dirContents = [fileManager contentsOfDirectoryAtPath:srcPath error:&error];
    if (!dirContents)
    {
        NSLog(@"contentsOfDirectoryAtPath failed: %@", error);
    }
    for (NSString *srcFile in dirContents)
    {
        BOOL isDirectory;
        NSString *srcFileFullPath = [srcPath stringByAppendingPathComponent:srcFile];
        BOOL fileExists = [fileManager fileExistsAtPath:srcFileFullPath isDirectory:&isDirectory];
        if (fileExists && !isDirectory)
        {
            NSString *destPath = [docsDir stringByAppendingPathComponent:srcFile];
            if (![fileManager fileExistsAtPath:destPath])
            {
                NSLog(@"copy %@ to %@", srcFile, destPath);
                if (![fileManager copyItemAtPath:srcFileFullPath toPath:destPath error:&error])
                {
                    NSLog(@"Copying %@ into documents folder failed: %@", srcPath, error);
                }
            }
        }


    }
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self copySampleDocs];

    return YES;
}
@end
