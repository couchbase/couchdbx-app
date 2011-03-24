/*
    Author: Jan Lehnardt <jan@apache.org>
    This is Apache 2.0 licensed free software
*/
#import <Cocoa/Cocoa.h>

#import "LoginItemManager.h"

#define MIN_LIFETIME 10

@interface CouchDBXApplicationController : NSObject{
    NSStatusItem *statusBar;
    IBOutlet NSMenu *statusMenu;

    IBOutlet NSMenuItem *launchBrowserItem;
    IBOutlet NSMenuItem *launchAtStartupItem;
    IBOutlet LoginItemManager *loginItems;

    NSTask *task;
    NSPipe *in, *out;

    BOOL hasSeenStart;
    time_t startTime;
}

-(IBAction)start:(id)sender;
-(IBAction)browse:(id)sender;

-(void)launchCouchDB;
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
-(IBAction)showImportWindow:(id)sender;
-(IBAction)showTechSupport:(id)sender;


@end
