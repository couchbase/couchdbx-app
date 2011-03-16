/*
 *  Author: Jan Lehnardt <jan@apache.org>
 *  This is Apache 2.0 licensed free software
 */
#import "CouchDBXApplicationController.h"
#import "Sparkle/Sparkle.h"
#import "SUUpdaterDelegate.h"

@implementation CouchDBXApplicationController

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

-(void)awakeFromNib
{
    statusBar=[[NSStatusBar systemStatusBar] statusItemWithLength: 20.0];
    NSImage *statusIcon = [NSImage imageNamed:@"Couchbase-Status.png"];
    [statusBar setImage: statusIcon];
    [statusBar setMenu: statusMenu];
    [statusBar setEnabled:YES];
    [statusBar setHighlightMode:YES];
    [statusBar retain];

	[self launchCouchDB];
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
- (NSString *)applicationSupportFolder {
    NSString *applicationSupportFolder = nil;
    FSRef foundRef;
    OSErr err = FSFindFolder(kUserDomain, kApplicationSupportFolderType, kDontCreateFolder, &foundRef);
    if (err == noErr) {
        unsigned char path[PATH_MAX];
        OSStatus validPath = FSRefMakePath(&foundRef, path, sizeof(path));
        if (validPath == noErr)
        {
            applicationSupportFolder = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:path length:(NSUInteger)strlen((char*)path)];
        }
    }
	applicationSupportFolder = [applicationSupportFolder stringByAppendingPathComponent:@"CouchbaseServer"];
    return applicationSupportFolder;
}

-(void)maybeSetDataDirs
{
	// determine data dir
	NSString *dataDir = [self applicationSupportFolder];
	// create if it doesn't exist
	if(![[NSFileManager defaultManager] fileExistsAtPath:dataDir]) {
		[[NSFileManager defaultManager] createDirectoryAtPath:dataDir withIntermediateDirectories:YES attributes:nil error:NULL];
	}

	// if data dirs are not set in local.ini
	NSMutableString *iniFile = [[NSMutableString alloc] init];
	[iniFile appendString:[[NSBundle mainBundle] resourcePath]];
	[iniFile appendString:@"/couchdbx-core/etc/couchdb/local.ini"];
    NSLog(@"Loading stuff from %@", iniFile);
	NSString *ini = [NSString stringWithContentsOfFile:iniFile encoding:NSUTF8StringEncoding error:NULL];
    assert(ini);
	NSRange found = [ini rangeOfString:dataDir];
	if(found.length == 0) {
		//   set them
		NSMutableString *newIni = [[NSMutableString alloc] init];
        assert(newIni);
		[newIni appendString: ini];
		[newIni appendString:@"[couchdb]\ndatabase_dir = "];
		[newIni appendString:dataDir];
		[newIni appendString:@"\nview_index_dir = "];
		[newIni appendString:dataDir];
		[newIni appendString:@"\n\n"];
		[newIni appendString:@"[query_servers]\njavascript = bin/couchjs share/couchdb/server/main.js"];
		[newIni writeToFile:iniFile atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		[newIni release];
	}
	[iniFile release];
	// done
}

-(void)launchCouchDB
{
	[self maybeSetDataDirs];

	in = [[NSPipe alloc] init];
	out = [[NSPipe alloc] init];
	task = [[NSTask alloc] init];

	NSMutableString *launchPath = [[NSMutableString alloc] init];
	[launchPath appendString:[[NSBundle mainBundle] resourcePath]];
	[launchPath appendString:@"/couchdbx-core"];
	[task setCurrentDirectoryPath:launchPath];

	[launchPath appendString:@"/bin/couchdb"];
    NSLog(@"Launching '%@'", launchPath);
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
	sleep(1);
	[self openFuton];
}

-(void)taskTerminated:(NSNotification *)note
{
    [self cleanup];
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
    NSLog(@"%@", s);
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

@end
