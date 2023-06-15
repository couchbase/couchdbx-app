/*
 *  Author: Jan Lehnardt <jan@apache.org>
 *  This is Apache 2.0 licensed free software
 */
#import "Couchbase_ServerAppDelegate.h"
#import "ImportController.h"
#import "Sparkle/Sparkle.h"
#import "ToolInstallController.h"
#import "LaunchAtLoginController.h"
#import "iniparser.h"
#include "TargetConditionals.h"

#define FORCEKILL_INTERVAL 15.0     // How long to wait for the server task to exit, on quit

#define MAX_OPEN_FILES 10240        // rlimit for max # of open files (RLIMIT_NOFILE)

@interface Couchbase_ServerAppDelegate () <SUUpdaterDelegate>
@end


@implementation Couchbase_ServerAppDelegate

#if TARGET_CPU_ARM64
  // Code meant for the arm64 architecture here.
#elif TARGET_CPU_X86_64
  // Code meant for the x86_64 architecture here.
#endif

-(BOOL)isSingle
{
    return
#ifdef COUCHBASE_SINGLE
    YES;
#else
    NO;
#endif
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [self stop];
}

-(void)applicationWillFinishLaunching:(NSNotification *)notification
{
	[[SUUpdater sharedUpdater] setDelegate: self];
}

-(void)willInstallUpdate:(SUAppcastItem *)update
{
	[self ensureFullCommit];
}

- (NSArray *)feedParametersForUpdater:(SUUpdater *)updater
                 sendingSystemProfile:(BOOL)sendingProfile
{
    // Place our UUID into each software update request.
    NSString *uuid = [[NSUserDefaults standardUserDefaults] valueForKey:@"uniqueness"];

    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                uuid, @"value",
                                @"uuid", @"key",
                                uuid, @"displayValue",
                                @"uuid", @"displayKey",
                                nil];

    return [NSArray arrayWithObject: dictionary];
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
    if (![self isSingle]) {
        return;
    }

	// find couch.uri file
	NSMutableString *urifile = [NSMutableString string];
	[urifile appendString: [task currentDirectoryPath]]; // couchdbx-core
	[urifile appendString: @"/var/lib/couchdb/couch.uri"];

	// get couch uri
	NSString *uri = [NSString stringWithContentsOfFile:urifile encoding:NSUTF8StringEncoding error:NULL];

	// TODO: maybe parse out \n

	// get database dir
	NSString *databaseDir = [self applicationSupportFolder];

	// get ensure_full_commit.sh
	NSMutableString *ensure_full_commit_script = [NSMutableString string];
	[ensure_full_commit_script appendString: [[NSBundle mainBundle] resourcePath]];
	[ensure_full_commit_script appendString: @"/ensure_full_commit.sh"];

	// exec ensure_full_commit.sh database_dir couch.uri
	NSArray *args = [NSArray arrayWithObjects:databaseDir, uri, nil];
	NSTask *commitTask = [[[NSTask alloc] init] autorelease];
	[commitTask setArguments: args];
	[commitTask launch];
	[commitTask waitUntilExit];

	// yay!
}

- (NSString *)finalConfigPath {
    NSString *confFile = nil;
    confFile = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/couchbase-server.ini"];
    return confFile;
}

- (NSString *)logFilePath:(NSString*)logName {
    NSString *logDir = nil;
    logDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/"];
    NSString *logFile = [NSString stringWithFormat: @"%@/%@", logDir,logName];
    return logFile;
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
            [itm setKeyEquivalentModifierMask:NSEventModifierFlagOption];
        }
    }

    [launchBrowserItem setState:([defaults boolForKey:@"browseAtStart"] ? NSControlStateValueOn : NSControlStateValueOff)];
    [self updateAddItemButtonState];

	[self launchServer];

//    [ToolInstallController showIfFirstRun];

//    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"runImport"]) {
//        [self showImportWindow:nil];
//    }
}

-(IBAction)start:(id)sender
{
    if([task isRunning]) {
        [self stop];
        return;
    }

    [self launchServer];
}

-(void)stop
{
    NSFileHandle *writer;
    writer = [in fileHandleForWriting];
    [writer writeData:[@"q().\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [writer closeFile];
}

- (NSString *)applicationSupportFolder:(NSString*)appName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportFolder = paths.firstObject;
    return applicationSupportFolder;
}

- (NSString *)applicationSupportFolder {
    return [self applicationSupportFolder:@"CouchbaseServer"];
}

-(void)setInitParams
{

    if (![self isSingle]) {
        return;
    }

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
    dictionary_set(iniDict, "query_servers:coffeescript", "bin/couchjs share/couchdb/server/main-coffee.js");

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

-(void)launchServer
{
	[self setInitParams];

	in = [[NSPipe alloc] init];
	out = [[NSPipe alloc] init];
	task = [[NSTask alloc] init];

    startTime = time(NULL);

	NSMutableString *launchPath = [NSMutableString string];
	[launchPath appendString:[[NSBundle mainBundle] resourcePath]];
	[task setCurrentDirectoryPath:launchPath];

    [launchPath appendString:@"/start-server.sh"];

    NSDictionary *env = [NSDictionary dictionaryWithObjectsAndKeys:
                         NSHomeDirectory(), @"HOME",
                         [self finalConfigPath], @"COUCHDB_ADDITIONAL_CONFIG_FILE",
                         nil, nil];
    [task setEnvironment:env];

    NSLog(@"Launching:  %@\n", launchPath);
	[task setLaunchPath:launchPath];
	[task setStandardInput:in];

    // output from 'start-server.log' used to be processed by dataReady function.
    // This was causing problems in MacOS Mojave. Instead we will pipe output
    // directly to CouchbaseServer.log.
    NSString *logPath = [self logFilePath:@"CouchbaseServer.log"];
    NSLog(@"Write output to %@", logPath);
    NSFileManager *outputFileManager = [NSFileManager defaultManager];

    // if the log file exists, move it to CouchbaseServer.log.old
    if ([outputFileManager fileExistsAtPath: logPath ] == YES)
    {
        const char *logPathC = [logPath cStringUsingEncoding:NSUTF8StringEncoding];
        const char *oldLogPath = [[self logFilePath:@"CouchbaseServer.log.old"] cStringUsingEncoding:NSUTF8StringEncoding];
        rename(logPathC, oldLogPath);
    }

    // CouchbaseServer.log must exist in order to pipe to it, make an empty version
    [outputFileManager createFileAtPath: logPath
                       contents: nil
                       attributes: nil];

    // get a handle to the log file and pipe output to it
    NSFileHandle *log = [NSFileHandle fileHandleForWritingAtPath: logPath];
    if (log == nil)
        NSLog(@"Failed to open %@ for output", logPath);
    [task setStandardError: log];
    [task setStandardOutput: log];

    // listen for the task being stopped
 	NSNotificationCenter *nc;
	nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
           selector:@selector(taskTerminated:)
               name:NSTaskDidTerminateNotification
             object:task];

    // Raise limit on number of open files:
    BOOL changedRLimit = NO;
    struct rlimit limits, newLimits;
    if (getrlimit(RLIMIT_NOFILE, &limits) < 0)
        NSLog(@"WARNING: getrlimit call failed, errno=%d", errno);
    else if (limits.rlim_cur < MAX_OPEN_FILES) {
        newLimits = limits;
        newLimits.rlim_cur = MAX_OPEN_FILES;
        if (setrlimit(RLIMIT_NOFILE, &newLimits) < 0)
            NSLog(@"WARNING: setrlimit call failed, errno=%d", errno);
        else
            changedRLimit = YES;
    }

  	[task launch];
  	//[fh readInBackgroundAndNotify];
    NSLog(@"Launched server task -- pid = %d", task.processIdentifier);

    // wait a second and see if we should launch the admin console
    //[self performSelector:@selector(checkForServerStart:) withObject:nil afterDelay:1.0];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(checkForServerStart:) userInfo:nil repeats:YES];
    NSLog(@"launch browser");
    if (changedRLimit) {
        if (setrlimit(RLIMIT_NOFILE, &limits) < 0)
            NSLog(@"WARNING: failed to restore previous rlimits, errno=%d", errno);
    }
}


#pragma mark - SHUTDOWN:


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	[self ensureFullCommit];

    BOOL isRunning = [task isRunning];
    if (isRunning) {
        [self stopTask];
        terminatingApp = YES;
        // Ideally we should return NSTerminateLater, but if we do so then neither -taskTerminated:
        // nor -killTask will ever be called. I think this is because the runloop ends up in a
        // weird waiting-to-terminate mode that doesn't process those notifications.
        return NSTerminateCancel;
    }
    return NSTerminateNow;
}

-(void)applicationWillTerminate:(NSNotification *)notification
{
    NSLog(@"Terminating.");
}

- (void)stopTask
{
    if (taskKiller) {
        return; // Already shutting down.
    }
    NSLog(@"Telling server task to stop...");
    NSFileHandle *writer;
    writer = [in fileHandleForWriting];
    [writer writeData:[@"q().\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [writer closeFile];
    taskKiller = [NSTimer scheduledTimerWithTimeInterval:FORCEKILL_INTERVAL
                                                  target:self
                                                selector:@selector(killTask)
                                                userInfo:nil
                                                 repeats:NO];
}

-(void)killTask {
    NSLog(@"Force terminating task");
    taskKiller = nil;   // It just fired, so it's going to go away
    [task terminate];
}

-(void)taskTerminated:(NSNotification *)note
{
    int status = [[note object] terminationStatus];
    NSLog(@"Task terminated with status %d, terminating app: %d", status, terminatingApp);
    [self cleanup];
    [self logMessage: [NSString stringWithFormat:@"Terminated with status %d\n",
                       status]];

    if (terminatingApp) {
        // I was just waiting for the task to exit before quitting
        [[NSApplication sharedApplication] terminate:nil];
    } else {
        time_t now = time(NULL);
        if (now - startTime < MIN_LIFETIME) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Problem Running Couchbase"];
            [alert setInformativeText:@"Couchbase Server doesn't seem to be operating properly.  Check Console logs for more details."];
            [alert addButtonWithTitle:@"ORetry"];
            [alert addButtonWithTitle:@"Quit"];
            [alert setAlertStyle:NSAlertStyleWarning];
        
            if ([alert runModal] == NSAlertSecondButtonReturn) {
                [NSApp terminate:self];
                return;
            }
        }
        // Relaunch the server task...
        [NSTimer scheduledTimerWithTimeInterval:1.0
                                         target:self selector:@selector(launchServer)
                                       userInfo:nil
                                        repeats:NO];
    }
}

-(void)cleanup
{
    [taskKiller invalidate];
    taskKiller = nil;

    [task release];
    task = nil;

    [in release];
    in = nil;
    [out release];
    out = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



#pragma mark - COMMANDS:


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

- (void)checkForServerStart:(NSTimer *)timer
{
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:8091/whoami"];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                if (httpResp.statusCode == 200) {
                    NSLog(@"%@ is ready.", url);
                    [timer invalidate];
                    [self openBrowserConsole];
                }
    }];
    [dataTask resume];
}

-(void)openBrowserConsole{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"browseAtStart"]) {
        [self openFuton];
    }
}


-(IBAction)setLaunchPref:(id)sender {

    NSControlStateValue stateVal = [sender state];
    stateVal = (stateVal == NSControlStateValueOn) ? NSControlStateValueOff : NSControlStateValueOn;

    NSLog(@"Setting launch pref to %s", stateVal == NSControlStateValueOn ? "on" : "off");

    [[NSUserDefaults standardUserDefaults]
     setBool:(stateVal == NSControlStateValueOn)
     forKey:@"browseAtStart"];

    [launchBrowserItem setState:([[NSUserDefaults standardUserDefaults]
                                  boolForKey:@"browseAtStart"] ? NSControlStateValueOn : NSControlStateValueOff)];

    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(IBAction)showTechSupport:(id)sender {
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *homePage = [info objectForKey:@"SupportPage"];
    NSURL *url=[NSURL URLWithString:homePage];
    [[NSWorkspace sharedWorkspace] openURL:url];

}

-(void) updateAddItemButtonState {
    LaunchAtLoginController *launchController = [[LaunchAtLoginController alloc] init];
    BOOL launch = [launchController launchAtLogin];
    [launchController release];

    [launchAtStartupItem setState:launch];
}

-(IBAction)changeLoginItems:(id)sender {
    LaunchAtLoginController *launchController = [[LaunchAtLoginController alloc] init];

    if([sender state] == NSControlStateValueOff) {
      [launchController setLaunchAtLogin:YES];
    } else {
      [launchController setLaunchAtLogin:NO];
    }
    [self updateAddItemButtonState];

    [launchController release];
}

@end
