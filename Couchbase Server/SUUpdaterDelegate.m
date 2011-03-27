/*
 Author: Jan Lehnardt <jan@apache.org>
 This is Apache 2.0 licensed free software
 */

#import "SUUpdaterDelegate.h"
#import "Sparkle/Sparkle.h"

@implementation SUUpdaterDelegate

-(void)willInstallUpdate:(SUAppcastItem *)update
{
	[[[NSApplication sharedApplication] delegate] ensureFullCommit];
}

// Place our UUID into each request.
- (NSArray *)feedParametersForUpdater:(SUUpdater *)updater
                 sendingSystemProfile:(BOOL)sendingProfile {

    NSString *uuid = [[NSUserDefaults standardUserDefaults]
                      valueForKey:@"uniqueness"];

    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                uuid, @"value",
                                @"uuid", @"key",
                                uuid, @"displayValue",
                                @"uuid", @"displayKey",
                                nil];

    return [NSArray arrayWithObject: dictionary];
}


@end
