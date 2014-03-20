//
//  ARTAppDelegate.h
//  ARTurrets
//
//  Created by Marcin Pędzimąż on 04.03.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ObjectAL.h"

@interface ARTAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, strong) ALDevice* device;
@property (nonatomic, strong) ALContext* context;

@end
