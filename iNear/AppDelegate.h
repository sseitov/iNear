//
//  AppDelegate.h
//  iNear
//
//  Created by Sergey Seitov on 05.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "XMPPFramework.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

- (void)connect:(void (^)(BOOL))result;
- (void)disconnect;

@property (nonatomic, strong, readonly) XMPPvCardAvatarModule *xmppvCardAvatarModule;

- (NSManagedObjectContext *)managedObjectContext_roster;
- (NSManagedObjectContext *)managedObjectContext_capabilities;

@end

