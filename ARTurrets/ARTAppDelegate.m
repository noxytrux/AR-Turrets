//
//  ARTAppDelegate.m
//  ARTurrets
//
//  Created by Marcin Pędzimąż on 04.03.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

#import "ARTAppDelegate.h"

@implementation ARTAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{

    self.device = [ALDevice deviceWithDeviceSpecifier:nil];
    self.context = [ALContext contextOnDevice:_device attributes:nil];
    
    [OpenALManager sharedInstance].currentContext = _context;
    
    [OALAudioSession sharedInstance].handleInterruptions = YES;
    [OALAudioSession sharedInstance].allowIpod = NO;
    [OALAudioSession sharedInstance].honorSilentSwitch = YES;
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{

}

- (void)applicationDidEnterBackground:(UIApplication *)application
{

}

- (void)applicationWillEnterForeground:(UIApplication *)application
{

}

- (void)applicationDidBecomeActive:(UIApplication *)application
{

}

- (void)applicationWillTerminate:(UIApplication *)application
{

}

@end
