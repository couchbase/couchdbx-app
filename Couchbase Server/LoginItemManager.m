//
//  LoginItemManager.m
//  AppHider
//
//  Created by Dustin Sallings on 3/23/11.
//

#import "LoginItemManager.h"


@implementation LoginItemManager

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }

    return self;
}

- (void)dealloc
{
    [super dealloc];
}

-(BOOL) inLoginItems {
    BOOL rv = NO;

    NSArray *loginItems=[[[NSUserDefaults standardUserDefaults]
                                  persistentDomainForName:@"loginwindow"]
                                 objectForKey:@"AutoLaunchedApplicationDictionary"];

    // Remove anything that looks like the current login item.
    NSString *myName=[[[NSBundle mainBundle] bundlePath] lastPathComponent];
    NSEnumerator *e=[loginItems objectEnumerator];
    id current=nil;
    while( (current=[e nextObject]) != nil) {
        if([[current valueForKey:@"Path"] hasSuffix:myName]) {
            rv = YES;
        }
    }

    return rv;
}

-(void) removeLoginItem:(id)sender {
    NSMutableArray *loginItems=[[[[NSUserDefaults standardUserDefaults]
                                  persistentDomainForName:@"loginwindow"]
                                 objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy];

    // Remove anything that looks like the current login item.
    NSString *myName=[[[NSBundle mainBundle] bundlePath] lastPathComponent];
    NSEnumerator *e=[loginItems objectEnumerator];
    id current=nil;
    while( (current=[e nextObject]) != nil) {
        if([[current valueForKey:@"Path"] hasSuffix:myName]) {
            NSLog(@"Removing login item: %@", [current valueForKey:@"Path"]);
            [loginItems removeObject:current];
            break;
        }
    }

    // Use the corefoundation API since I can't figure out the other one.
    CFPreferencesSetValue((CFStringRef)@"AutoLaunchedApplicationDictionary",
                          loginItems, (CFStringRef)@"loginwindow", kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSynchronize((CFStringRef) @"loginwindow", kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    [loginItems release];
}

-(void)addToLoginItems:(id)sender {

    [self removeLoginItem: self];

    NSMutableDictionary *myDict=[[NSMutableDictionary alloc] init];

    NSLog(@"Adding login item: %@", [[NSBundle mainBundle] bundlePath]);
    [myDict setObject:[NSNumber numberWithBool:NO] forKey:@"Hide"];
    [myDict setObject:[[NSBundle mainBundle] bundlePath]
               forKey:@"Path"];

    NSMutableArray *loginItems=[[[[NSUserDefaults standardUserDefaults]
                                  persistentDomainForName:@"loginwindow"]
                                 objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy];

    [loginItems addObject:myDict];

    // Use the corefoundation API since I can't figure out the other one.
    CFPreferencesSetValue((CFStringRef)@"AutoLaunchedApplicationDictionary",
                          loginItems, (CFStringRef)@"loginwindow", kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSynchronize((CFStringRef) @"loginwindow", kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

    [myDict release];
    [loginItems release];
}

@end
