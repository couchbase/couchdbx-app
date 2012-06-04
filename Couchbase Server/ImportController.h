//
//  ImportController.h
//
//
//  Created by Dustin Sallings on 3/19/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ImportController : NSWindowController {
@private
    IBOutlet NSMutableArray *missingFiles;
    IBOutlet NSArrayController *arrayController;

    IBOutlet NSTextField *label;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSButton *importButton;

    NSString *src;
    NSString *dest;

    int numFiles;
    size_t totalCopied;
    size_t totalSize;
}

-(void)setPaths:(NSString *)dest from:(NSString *)src;

-(BOOL)hasImportableDBs;

-(IBAction)doImport:(id)sender;

@end
