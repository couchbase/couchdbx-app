/*
 *  Author: Jan Lehnardt <jan@apache.org>
 *  This is Apache 2.0 licensed free software
 */
#import "Couchbase_ServerAppDelegate.h"
#import "ImportController.h"
#import "Sparkle/Sparkle.h"
#import "SUUpdaterDelegate.h"

#import "iniparser.h"

@implementation Couchbase_ServerAppDelegate

-(void)applicationWillTerminate:(NSNotification *)notification
{
	[self ensureFullCommit];
}

- (void)windowWillClose:(NSNotification *)aNotification 
{
    [self stop];
}

-(void)applicationWillFinishLaunching:(NSNotification *)notification
{
	SUUpdater *updater = [SUUpdater sharedUpdater];
	SUUpdaterDelegate *updaterDelegate = [[SUUpdaterDelegate alloc] init];
	[updater setDelegate: updaterDelegate];
}

- (IBAction)showAboutPanel:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:sender];
}

-(void)logMessage:(NSString*)msg {
    const char *str = [msg cStringUsingEncoding:NSUTF8StringEncoding];
    if (str) {
        fwrite(str, strlen(str), 1, logFile);
    }
}

-(void)flushLog {
    fflush(logFile);
}

-(void)ensureFullCommit
{
	// find couch.uri file
	NSMutableString *urifile = [[NSMutableString alloc] init];
	[urifile appendString: [task currentDirectoryPath]]; // couchdbx-core
	[urifile appendString: @"/var/lib/couchdb/couch.uri"];
    
	// get couch uri
	NSString *uri = [NSString stringWithContentsOfFile:urifile encoding:NSUTF8StringEncoding error:NULL];
    
	// TODO: maybe parse out \n
    
	// get database dir
	NSString *databaseDir = [self applicationSupportFolder];
    
	// get ensure_full_commit.sh
	NSMutableString *ensure_full_commit_script = [[NSMutableString alloc] init];
	[ensure_full_commit_script appendString: [[NSBundle mainBundle] resourcePath]];
	[ensure_full_commit_script appendString: @"/ensure_full_commit.sh"];
    
	// exec ensure_full_commit.sh database_dir couch.uri
	NSArray *args = [[NSArray alloc] initWithObjects:databaseDir, uri, nil];
	NSTask *commitTask = [[NSTask alloc] init];
	[commitTask setArguments: args];
	[commitTask launch];
	[commitTask waitUntilExit];
    
	// yay!
}

- (NSString *)finalConfigPath {
    NSString *confFile = nil;
    FSRef foundRef;
    OSErr err = FSFindFolder(kUserDomain, kPreferencesFolderType, kDontCreateFolder, &foundRef);
    if (err == noErr) {
        unsigned char path[PATH_MAX];
        OSStatus validPath = FSRefMakePath(&foundRef, path, sizeof(path));
        if (validPath == noErr) {
            confFile = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:(const char *)path
                                                                                   length:(NSUInteger)strlen((char*)path)];
        }
    }
    confFile = [confFile stringByAppendingPathComponent:@"couchbase-server.ini"];
    return confFile;
}

- (NSString *)logFilePath:(NSString*)logName {
    NSString *logDir = nil;
    FSRef foundRef;
    OSErr err = FSFindFolder(kUserDomain, kLogsFolderType, kDontCreateFolder, &foundRef);
    if (err == noErr) {
        unsigned char path[PATH_MAX];
        OSStatus validPath = FSRefMakePath(&foundRef, path, sizeof(path));
        if (validPath == noErr) {
            logDir = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:(const char *)path
                                                                                 length:(NSUInteger)strlen((char*)path)];
        }
    }
	logDir = [logDir stringByAppendingPathComponent:logName];
    return logDir;
}

-(void)awakeFromNib
{
    hasSeenStart = NO;

    logPath = [[self logFilePath:@"Couchbase.log"] retain];
    const char *logPathC = [logPath cStringUsingEncoding:NSUTF8StringEncoding];

    NSString *oldLogFileString = [self logFilePath:@"Couchbase.log.old"];
    const char *oldLogPath = [oldLogFileString cStringUsingEncoding:NSUTF8StringEncoding];
    rename(logPathC, oldLogPath); // This will fail the first time.

    // Now our logs go to a private file.
    logFile = fopen(logPathC, "w");

    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self selector:@selector(flushLog)
                                   userInfo:nil
                                    repeats:YES];

    [[NSUserDefaults standardUserDefaults]
     registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithBool:YES], @"browseAtStart",
                        [NSNumber numberWithBool:YES], @"runImport", nil, nil]];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Make sure we have a unique identifier for this installation.
    if ([defaults valueForKey:@"uniqueness"] == nil) {
        CFUUIDRef uuidObj = CFUUIDCreate(nil);
        NSString *uuidString = (NSString*)CFUUIDCreateString(nil, uuidObj);
        CFRelease(uuidObj);

        [defaults setValue:uuidString forKey:@"uniqueness"];
        [defaults synchronize];

        [uuidString release];
    }
    
    statusBar=[[NSStatusBar systemStatusBar] statusItemWithLength: 26.0];
    NSImage *statusIcon = [NSImage imageNamed:@"Couchbase-Status-bw.png"];
    [statusBar setImage: statusIcon];
    [statusBar setMenu: statusMenu];
    [statusBar setEnabled:YES];
    [statusBar setHighlightMode:YES];
    [statusBar retain];

    // Fix up the masks for all the alt items.
    for (int i = 0; i < [statusMenu numberOfItems]; ++i) {
        NSMenuItem *itm = [statusMenu itemAtIndex:i];
        if ([itm isAlternate]) {
            [itm setKeyEquivalentModifierMask:NSAlternateKeyMask];
        }
    }

    [launchBrowserItem setState:([defaults boolForKey:@"browseAtStart"] ? NSOnState : NSOffState)];
    [self updateAddItemButtonState];
    
	[self launchCouchDB];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"runImport"]) {
        [self showImportWindow:nil];
    }
}

-(IBAction)start:(id)sender
{
    if([task isRunning]) {
        [self stop];
        return;
    } 
    
    [self launchCouchDB];
}

-(void)stop
{
    NSFileHandle *writer;
    writer = [in fileHandleForWriting];
    [writer writeData:[@"q().\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [writer closeFile];
}

/* found at http://www.cocoadev.com/index.pl?ApplicationSupportFolder */
- (NSString *)applicationSupportFolder:(NSString*)appName {
    NSString *applicationSupportFolder = nil;
    FSRef foundRef;
    OSErr err = FSFindFolder(kUserDomain, kApplicationSupportFolderType, kDontCreateFolder, &foundRef);
    if (err == noErr) {
        unsigned char path[PATH_MAX];
        OSStatus validPath = FSRefMakePath(&foundRef, path, sizeof(path));
        if (validPath == noErr) {
            applicationSupportFolder = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:(const char *)path
                                                                                                   length:(NSUInteger)strlen((char*)path)];
        }
    }
	applicationSupportFolder = [applicationSupportFolder stringByAppendingPathComponent:appName];
    return applicationSupportFolder;
}

- (NSString *)applicationSupportFolder {
    return [self applicationSupportFolder:@"CouchbaseServer"];
}

-(void)setInitParams
{
	// determine data dir
	NSString *dataDir = [self applicationSupportFolder];
	// create if it doesn't exist
	if(![[NSFileManager defaultManager] fileExistsAtPath:dataDir]) {
		[[NSFileManager defaultManager] createDirectoryAtPath:dataDir withIntermediateDirectories:YES attributes:nil error:NULL];
	}

    dictionary* iniDict = iniparser_load([[self finalConfigPath] UTF8String]);
    if (iniDict == NULL) {
        iniDict = dictionary_new(0);
        assert(iniDict);
    }

    dictionary_set(iniDict, "couchdb", NULL);
    if (iniparser_getstring(iniDict, "couchdb:database_dir", NULL) == NULL) {
        dictionary_set(iniDict, "couchdb:database_dir", [dataDir UTF8String]);
    }
    if (iniparser_getstring(iniDict, "couchdb:view_index_dir", NULL) == NULL) {
        dictionary_set(iniDict, "couchdb:view_index_dir", [dataDir UTF8String]);
    }
    
    dictionary_set(iniDict, "query_servers", NULL);
    dictionary_set(iniDict, "query_servers:javascript", "bin/couchjs share/couchdb/server/main.js");

    dictionary_set(iniDict, "product", NULL);
    NSString *vstr = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    dictionary_set(iniDict, "product:title", [vstr UTF8String]);

    NSString *tmpfile = [NSString stringWithFormat:@"%@.tmp", [self finalConfigPath]];
    FILE *f = fopen([tmpfile UTF8String], "w");
    if (f) {
        iniparser_dump_ini(iniDict, f);
        fclose(f);
        rename([tmpfile UTF8String], [[self finalConfigPath] UTF8String]);
    } else {
        NSLog(@"Can't write to temporary config file:  %@:  %s\n", tmpfile, strerror(errno));
    }

    iniparser_freedict(iniDict);
}

-(void)launchCouchDB
{
	[self setInitParams];
    
	in = [[NSPipe alloc] init];
	out = [[NSPipe alloc] init];
	task = [[NSTask alloc] init];
    
    startTime = time(NULL);
    
	NSMutableString *launchPath = [[NSMutableString alloc] init];
	[launchPath appendString:[[NSBundle mainBundle] resourcePath]];
	[launchPath appendString:@"/couchdbx-core"];
	[task setCurrentDirectoryPath:launchPath];

    NSDictionary *env = [NSDictionary dictionaryWithObjectsAndKeys:
                         @"./bin:/bin:/usr/bin", @"PATH",
                         NSHomeDirectory(), @"HOME",
                         [self finalConfigPath], @"COUCHDB_ADDITIONAL_CONFIG_FILE",
                         nil, nil];
    [task setEnvironment:env];
    
	[launchPath appendString:@"/bin/couchdb"];
    [self logMessage:[NSString stringWithFormat:@"Launching '%@'\n", launchPath]];
	[task setLaunchPath:launchPath];
	NSArray *args = [[NSArray alloc] initWithObjects:@"-i", nil];
	[task setArguments:args];
	[task setStandardInput:in];
	[task setStandardOutput:out];
    
	NSFileHandle *fh = [out fileHandleForReading];
	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
    
	[nc addObserver:self
           selector:@selector(dataReady:)
               name:NSFileHandleReadCompletionNotification
             object:fh];
	
	[nc addObserver:self
           selector:@selector(taskTerminated:)
               name:NSTaskDidTerminateNotification
             object:task];
    
  	[task launch];
  	[fh readInBackgroundAndNotify];
}

-(void)taskTerminated:(NSNotification *)note
{
    [self cleanup];
    [self logMessage: [NSString stringWithFormat:@"Terminated with status %d\n",
                       [[note object] terminationStatus]]];
    
    time_t now = time(NULL);
    if (now - startTime < MIN_LIFETIME) {
        NSInteger b = NSRunAlertPanel(@"Problem Running Couchbase",
                                      @"Couchbase Server doesn't seem to be operating properly.  "
                                      @"Check Console logs for more details.", @"Retry", @"Quit", nil);
        if (b == NSAlertAlternateReturn) {
            [NSApp terminate:self];
        }
    }
    
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self selector:@selector(launchCouchDB)
                                   userInfo:nil
                                    repeats:NO];
}

-(void)cleanup
{
    [task release];
    task = nil;
    
    [in release];
    in = nil;
    [out release];
    out = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)openFuton
{
	NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *homePage = [info objectForKey:@"HomePage"];
    NSURL *url=[NSURL URLWithString:homePage];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

-(IBAction)browse:(id)sender
{
	[self openFuton];
    //[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://127.0.0.1:5984/_utils/"]];
}

- (void)appendData:(NSData *)d
{
    NSString *s = [[NSString alloc] initWithData: d
                                        encoding: NSUTF8StringEncoding];
    
    if (!hasSeenStart) {
        if ([s hasPrefix:@"Apache CouchDB has started"]) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            if ([defaults boolForKey:@"browseAtStart"]) {
                [self openFuton];
            }
            hasSeenStart = YES;
        }
    }

    [self logMessage:[s stringByReplacingOccurrencesOfString:@"1> "
                                                  withString:@""]];

    [s release];
}

- (void)dataReady:(NSNotification *)n
{
    NSData *d;
    d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
    if ([d length]) {
        [self appendData:d];
    }
    if (task)
        [[out fileHandleForReading] readInBackgroundAndNotify];
}

-(IBAction)setLaunchPref:(id)sender {
    
    NSCellStateValue stateVal = [sender state];
    stateVal = (stateVal == NSOnState) ? NSOffState : NSOnState;
    
    NSLog(@"Setting launch pref to %s", stateVal == NSOnState ? "on" : "off");
    
    [[NSUserDefaults standardUserDefaults]
     setBool:(stateVal == NSOnState)
     forKey:@"browseAtStart"];
    
    [launchBrowserItem setState:([[NSUserDefaults standardUserDefaults]
                                  boolForKey:@"browseAtStart"] ? NSOnState : NSOffState)];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void) updateAddItemButtonState {
    [launchAtStartupItem setState:[loginItems inLoginItems] ? NSOnState : NSOffState];
}

-(IBAction)changeLoginItems:(id)sender {
    if([sender state] == NSOffState) {
        [loginItems addToLoginItems:self];
    } else {
        [loginItems removeLoginItem:self];
    }
    [self updateAddItemButtonState];
}

- (IBAction)showImportWindow:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"runImport"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self logMessage:@"Starting import"];
    [NSApp activateIgnoringOtherApps:YES];
    
    ImportController *controller = [[ImportController alloc]
                                    initWithWindowNibName:@"Importer"];
    
    [controller setPaths:[self applicationSupportFolder]
                    from:[self applicationSupportFolder:@"CouchDBX"]];
    [controller loadWindow];

    if (sender != nil && ![controller hasImportableDBs]) {
        NSRunAlertPanel(@"No Importable Databases",
                        @"No databases can be imported from CouchDBX.", nil, nil, nil);
    }
}

-(IBAction)showTechSupport:(id)sender {
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *homePage = [info objectForKey:@"SupportPage"];
    NSURL *url=[NSURL URLWithString:homePage];
    [[NSWorkspace sharedWorkspace] openURL:url];
    
}

-(IBAction)showLogs:(id)sender {
    FSRef ref;

    if (FSPathMakeRef((const UInt8 *)[logPath cStringUsingEncoding:NSUTF8StringEncoding],
                      &ref, NULL) != noErr) {
        NSRunAlertPanel(@"Cannot Find Logfile",
                        @"I've been looking for logs in all the wrong places.", nil, nil, nil);
        return;
    }

    LSLaunchFSRefSpec params = {NULL, 1, &ref, NULL, kLSLaunchDefaults, NULL};

    if (LSOpenFromRefSpec(&params, NULL) != noErr) {
        NSRunAlertPanel(@"Cannot View Logfile",
                        @"Error launching log viewer.", nil, nil, nil);
    }
}

@end
