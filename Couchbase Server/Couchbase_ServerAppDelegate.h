/*
 Author: Jan Lehnardt <jan@apache.org>
 This is Apache 2.0 licensed free software
 */
#import <Cocoa/Cocoa.h>

@class SUUpdaterDelegate;

#define MIN_LIFETIME 10

@interface Couchbase_ServerAppDelegate : NSObject{
    NSStatusItem *statusBar;
    IBOutlet NSMenu *statusMenu;
    
    IBOutlet NSMenuItem *launchBrowserItem;
    IBOutlet NSMenuItem *launchAtStartupItem;
    
    NSTask *task;
    NSPipe *in, *out;
    
    BOOL hasSeenStart;
    time_t startTime;

    BOOL terminatingApp;
    NSTimer *taskKiller;

    NSString *logPath;
    FILE *logFile;

    SUUpdaterDelegate *updaterDelegate;
}

-(IBAction)start:(id)sender;
-(IBAction)browse:(id)sender;

-(BOOL)isSingle;

-(void)launchServer;
-(void)stop;
-(void)openFuton;
-(void)taskTerminated:(NSNotification *)note;
-(void)cleanup;
-(void)ensureFullCommit;
-(NSString *)applicationSupportFolder;

-(void)updateAddItemButtonState;

-(IBAction)setLaunchPref:(id)sender;
-(IBAction)changeLoginItems:(id)sender;

-(IBAction)showAboutPanel:(id)sender;
//-(IBAction)showLogs:(id)sender;
//-(IBAction)showImportWindow:(id)sender;
-(IBAction)showTechSupport:(id)sender;
//-(IBAction)showToolInstaller:(id)sender;


@end
