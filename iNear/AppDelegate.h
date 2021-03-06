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

extern NSString* const XmppConnectedNotification;
extern NSString* const XmppDisconnectedNotification;
extern NSString* const XmppSubscribeNotification;
extern NSString* const XmppMessageNotification;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (weak, nonatomic) UISplitViewController *splitViewController;

+ (AppDelegate*)sharedInstance;
+ (BOOL)isPad;

- (void)connectXmppFromViewController:(UIViewController*)controller
                                login:(NSString*)login
                             password:(NSString*)password
                               result:(void (^)(BOOL))result;
- (void)disconnectXmppFromViewController:(UIViewController*)controller
                                  result:(void (^)())complete;
- (BOOL)isXMPPConnected;

@property (nonatomic, strong, readonly) XMPPStream *xmppStream;
@property (nonatomic, strong, readonly) XMPPvCardAvatarModule *xmppvCardAvatarModule;
@property (nonatomic, strong, readonly) XMPPvCardTempModule *xmppvCardTempModule;
@property (nonatomic, strong, readonly) XMPPRoster *xmppRoster;

- (NSManagedObjectContext *)managedObjectContext_roster;
- (NSManagedObjectContext *)managedObjectContext_capabilities;

- (NSString*)nickNameForUser:(XMPPUserCoreDataStorageObject*)user;
- (NSData*)photoForUser:(XMPPUserCoreDataStorageObject*)user;

- (void)pushMessageToUser:(NSString*)user;

@end

