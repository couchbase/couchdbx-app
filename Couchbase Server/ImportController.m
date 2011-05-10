//
//  ImportController.m
//
//
//  Created by Dustin Sallings on 3/19/11.
//  Copyright 2011 NorthScale. All rights reserved.
//

#import "ImportController.h"
#import "ImportableDatabase.h"


@implementation ImportController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
    }
    return self;
}

- (void)dealloc
{
    [dest release];
    [src release];
    [super dealloc];
}

-(BOOL)hasImportableDBs {
    return [[arrayController arrangedObjects] count] > 0;
}

-(void)awakeFromNib {
    NSLog(@"Looking for imports from %@ to %@", src, dest);

    NSString *file;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:src];
    [arrayController setSelectsInsertedObjects:NO];
    while ((file = [enumerator nextObject])) {
        BOOL isDirectory=NO;
        if([[file pathExtension] isEqualToString:@"couch"] &&
           ![fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", dest, file]
                              isDirectory:&isDirectory]) {
               NSLog(@"Missing file:  %@", file);
               NSDictionary *srcAttr = [fileManager fileAttributesAtPath:[NSString stringWithFormat:@"%@/%@",
                                                                          src, file]
                                                            traverseLink:YES];
               NSNumber *fileSize = [srcAttr objectForKey:NSFileSize];
               if (fileSize > 0) {
                   [arrayController addObject:[[ImportableDatabase alloc] initWithName:file
                                                                                  size:fileSize]];
               }
        }
    }

    NSLog(@"Content from %@:  %@", arrayController, [arrayController arrangedObjects]);

    if ([self hasImportableDBs]) {
        [[self window] orderFront:self];
    }
}

-(void)setPaths:(NSString *)d from:(NSString *)s {
    dest = [d retain];
    src = [s retain];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
}

-(void)copied:(size_t)bytes of:(const char*)p {
    
    NSString *path = [NSString stringWithUTF8String:p];

    totalCopied = 0;
    totalSize = 0;

    ImportableDatabase *db;
    NSEnumerator *enumerator = [[arrayController arrangedObjects] objectEnumerator];
    while ((db = [enumerator nextObject])) {
        if ([path isEqualToString:[db pathFrom:dest]]) {
            [db copiedSize:bytes];
        }
        if ([db shouldImport]) {
            totalCopied += [db copiedSize];
            totalSize += [db totalSize];
        }
    }

    NSLog(@"Copied %zd bytes of %zd", totalCopied, totalSize);
    [progressIndicator setDoubleValue:(double)totalCopied];
    [progressIndicator displayIfNeeded];
}

-(void)completedFile {
    NSLog(@"Completed a file, %d more to go.", numFiles-1);
    if (--numFiles == 0) {
        [progressIndicator setHidden:YES];
        [label setStringValue:@"Import complete.  Please remember to reresh Futon."];
        [label setHidden:NO];
        [importButton setTitle:@"Done"];
        [importButton setEnabled:YES];
        [importButton setAction:@selector(orderOut:)];
        [importButton setTarget:[self window]];
    }
}

static void statusCallback(FSFileOperationRef fileOp,
                           const FSRef *currentItem,
                           FSFileOperationStage stage,
                           OSStatus error,
                           CFDictionaryRef statusDictionary,
                           void *info) {
    ImportController *controller = (ImportController*)info;

    if (stage == kFSOperationStageComplete) {
        [controller completedFile];
    }

    // If the status dictionary is valid, we can grab the current values
    // to display status changes, or in our case to update the progress
    // indicator.
    if(stage == kFSOperationStageRunning && statusDictionary) {
        CFNumberRef bytesCompleted;

        bytesCompleted = (CFNumberRef) CFDictionaryGetValue(statusDictionary,
                                                            kFSOperationBytesCompleteKey);
        CGFloat floatBytesCompleted;
        CFNumberGetValue(bytesCompleted, kCFNumberMaxType, &floatBytesCompleted);

        // NSLog(@"Copied %llu bytes so far.", floatBytesCompleted);
        if (bytesCompleted > 0) {
            char* path[PATH_MAX];
            FSRefMakePath(currentItem, (UInt8*)path, sizeof(path));
            [controller copied:(size_t)floatBytesCompleted of:(const char*)path];
        }
    }
}

-(void)importFile:(ImportableDatabase *)db {
    NSString *srcPath = [db pathFrom: src];
    NSString *destPath = [db pathFrom: dest];
    NSLog(@"Importing %@ to %@", srcPath, destPath);

    NSString *baseDir = [[db pathFrom:dest] stringByDeletingLastPathComponent];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL isDir;
    BOOL exists = [fileManager fileExistsAtPath:baseDir isDirectory:&isDir];

    if (!(exists && isDir)) {
        [fileManager createDirectoryAtPath:baseDir
               withIntermediateDirectories:YES
                                attributes:nil error:NULL];
    }

    // Set the max value to our source file size
    // [progressIndicator setMaxValue:(double)[db totalBytes]];
    // [progressIndicator setDoubleValue:0.0];

    // Get the current run loop and schedule our callback
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    FSFileOperationRef fileOp = FSFileOperationCreate(kCFAllocatorDefault);

    OSStatus status = FSFileOperationScheduleWithRunLoop(fileOp, runLoop, kCFRunLoopDefaultMode);
    if (status) {
        NSLog(@"Failed to schedule operation with run loop: %ld", status);
        return;
    }

    // Create a filesystem ref structure for the source and destination and
    // populate them with their respective paths from our NSTextFields.
    FSRef source;
    FSRef destination;

    FSPathMakeRef((const UInt8 *)[srcPath fileSystemRepresentation], &source, NULL);
    FSPathMakeRef((const UInt8 *)[[destPath stringByDeletingLastPathComponent] fileSystemRepresentation],
                  &destination, NULL);

    // Start the async copy.
    NSLog(@"Sending async call with pointer to %p", self);
    static FSFileOperationClientContext ctx;
    ctx.info = self;
    status = FSCopyObjectAsync(fileOp,
                               &source,
                               &destination, // Full path to destination dir
                               NULL, // Use the same filename as source
                               kFSFileOperationDefaultOptions,
                               statusCallback,
                               1.0,
                               &ctx);

    CFRelease(fileOp);

    if (status) {
        NSLog(@"Failed to begin asynchronous object copy: %s (%s)", GetMacOSStatusErrorString(status),
            GetMacOSStatusCommentString(status));
    }

}

-(IBAction)doImport:(id)sender {
    NSLog(@"Doing import...");

    [label setHidden:YES];
    [importButton setTitle:@"Importing"];
    [importButton setEnabled:NO];

    ImportableDatabase *db;
    // Add up the total number of bytes to copy.
    NSEnumerator *enumerator = [[arrayController arrangedObjects] objectEnumerator];
    totalSize = 0;
    numFiles = 0;
    while ((db = [enumerator nextObject])) {
        if ([db shouldImport]) {
            totalSize += [db totalSize];
            ++numFiles;
        }
    }

    [progressIndicator setMaxValue:((double)totalSize)];
    [progressIndicator setHidden:NO];

    // Then copy them
    enumerator = [[arrayController arrangedObjects] objectEnumerator];
    while ((db = [enumerator nextObject])) {
        if ([db shouldImport]) {
            [self importFile: db];
        }
    }
}

@end
