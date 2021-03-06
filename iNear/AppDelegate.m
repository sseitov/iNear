//
//  AppDelegate.m
//  iNear
//
//  Created by Sergey Seitov on 05.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "AppDelegate.h"
#import "MBProgressHUD.h"
#import "Storage.h"
#import "ChatController.h"

#import "XMPPLogging.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "XMPPvCardTemp.h"

#import <Parse/Parse.h>
#import <GoogleMaps/GoogleMaps.h>
#import <CoreLocation/CoreLocation.h>

#include "ApiKeys.h"

#define WAIT(a) [a lock]; [a wait]; [a unlock]
#define SIGNAL(a) [a lock]; [a signal]; [a unlock]

@interface AppDelegate () <UISplitViewControllerDelegate, XMPPRosterDelegate, CLLocationManagerDelegate> {
    NSString *xmppPassword;
    BOOL customCertEvaluation;
    BOOL isXmppConnected;
    NSCondition *connectCondition;
}

@property (nonatomic, strong, readonly) XMPPReconnect *xmppReconnect;
@property (nonatomic, strong, readonly) XMPPRosterCoreDataStorage *xmppRosterStorage;
@property (nonatomic, strong, readonly) XMPPvCardCoreDataStorage *xmppvCardStorage;
@property (nonatomic, strong, readonly) XMPPCapabilities *xmppCapabilities;
@property (nonatomic, strong, readonly) XMPPCapabilitiesCoreDataStorage *xmppCapabilitiesStorage;

@property (nonatomic, strong) CLLocationManager *locationManager;

- (void)setupStream;
- (void)teardownStream;

- (void)goOnline;
- (void)goOffline;

@end

NSString* const XmppConnectedNotification = @"XmppConnectedNotification";
NSString* const XmppDisconnectedNotification = @"XmppDisconnectedNotification";
NSString* const XmppSubscribeNotification = @"XmppSubscribeNotification";
NSString* const XmppMessageNotification = @"XmppMessageNotification";

@implementation AppDelegate

- (BOOL)isXMPPConnected
{
    return isXmppConnected;
}

+ (AppDelegate*)sharedInstance
{
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

+ (BOOL)isPad
{
    return ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{    
    [[Storage sharedInstance] saveContext];
    
    [Parse setApplicationId:ParseApplicationId clientKey:ParseClientKey];
    
    // Register for Push Notitications
    UIUserNotificationType userNotificationTypes = (UIUserNotificationTypeAlert |
                                                    UIUserNotificationTypeBadge |
                                                    UIUserNotificationTypeSound);
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:userNotificationTypes
                                                                             categories:nil];
    
    [application registerUserNotificationSettings:settings];
    [application registerForRemoteNotifications];
    
    
    [GMSServices provideAPIKey:GoolgleMapAPIKey];
    if ([CLLocationManager locationServicesEnabled])
    {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _locationManager.distanceFilter = 10;
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        if (status != kCLAuthorizationStatusAuthorizedAlways) {
            [_locationManager requestAlwaysAuthorization];
        }
        status = [CLLocationManager authorizationStatus];
        [_locationManager startUpdatingLocation];
    }

    // Configure logging framework
//    [DDLog addLogger:[DDTTYLogger sharedInstance] withLogLevel:XMPP_LOG_FLAG_SEND_RECV];
    // Setup the XMPP stream
    [self setupStream];

    _splitViewController = (UISplitViewController *)self.window.rootViewController;
    _splitViewController.presentsWithGesture = NO;
    _splitViewController.delegate = self;

    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    // Store the deviceToken in the current installation and save it to Parse.
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:deviceToken];
    [currentInstallation addUniqueObject:@"iNear" forKey:@"channels"];
    [currentInstallation saveInBackground];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    [PFPush handlePush:userInfo];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [self goOffline];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self goOnline];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    if (currentInstallation.badge != 0) {
        currentInstallation.badge = 0;
        [currentInstallation saveEventually];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [self disconnect];
    [self teardownStream];
    [[Storage sharedInstance] saveContext];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Core Data
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSManagedObjectContext *)managedObjectContext_roster
{
    return [_xmppRosterStorage mainThreadManagedObjectContext];
}

- (NSManagedObjectContext *)managedObjectContext_capabilities
{
    return [_xmppCapabilitiesStorage mainThreadManagedObjectContext];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setupStream
{
    NSAssert(_xmppStream == nil, @"Method setupStream invoked multiple times");
    
    // Setup xmpp stream
    //
    // The XMPPStream is the base class for all activity.
    // Everything else plugs into the xmppStream, such as modules/extensions and delegates.
    
    _xmppStream = [[XMPPStream alloc] init];
    _xmppStream.enableBackgroundingOnSocket = YES;
    
    // Setup reconnect
    //
    // The XMPPReconnect module monitors for "accidental disconnections" and
    // automatically reconnects the stream for you.
    // There's a bunch more information in the XMPPReconnect header file.
    
    _xmppReconnect = [[XMPPReconnect alloc] init];
    
    // Setup roster
    //
    // The XMPPRoster handles the xmpp protocol stuff related to the roster.
    // The storage for the roster is abstracted.
    // So you can use any storage mechanism you want.
    // You can store it all in memory, or use core data and store it on disk, or use core data with an in-memory store,
    // or setup your own using raw SQLite, or create your own storage mechanism.
    // You can do it however you like! It's your application.
    // But you do need to provide the roster with some storage facility.
    
    _xmppRosterStorage = [[XMPPRosterCoreDataStorage alloc] init];
    _xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:_xmppRosterStorage];
    
    _xmppRoster.autoFetchRoster = YES;
    _xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
    
    // Setup vCard support
    //
    // The vCard Avatar module works in conjuction with the standard vCard Temp module to download user avatars.
    // The XMPPRoster will automatically integrate with XMPPvCardAvatarModule to cache roster photos in the roster.
    
    _xmppvCardStorage = [XMPPvCardCoreDataStorage sharedInstance];
    _xmppvCardTempModule = [[XMPPvCardTempModule alloc] initWithvCardStorage:_xmppvCardStorage];
    
    _xmppvCardAvatarModule = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:_xmppvCardTempModule];
    
    // Setup capabilities
    //
    // The XMPPCapabilities module handles all the complex hashing of the caps protocol (XEP-0115).
    // Basically, when other clients broadcast their presence on the network
    // they include information about what capabilities their client supports (audio, video, file transfer, etc).
    // But as you can imagine, this list starts to get pretty big.
    // This is where the hashing stuff comes into play.
    // Most people running the same version of the same client are going to have the same list of capabilities.
    // So the protocol defines a standardized way to hash the list of capabilities.
    // Clients then broadcast the tiny hash instead of the big list.
    // The XMPPCapabilities protocol automatically handles figuring out what these hashes mean,
    // and also persistently storing the hashes so lookups aren't needed in the future.
    //
    // Similarly to the roster, the storage of the module is abstracted.
    // You are strongly encouraged to persist caps information across sessions.
    //
    // The XMPPCapabilitiesCoreDataStorage is an ideal solution.
    // It can also be shared amongst multiple streams to further reduce hash lookups.
    
    _xmppCapabilitiesStorage = [XMPPCapabilitiesCoreDataStorage sharedInstance];
    _xmppCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage:_xmppCapabilitiesStorage];
    
    _xmppCapabilities.autoFetchHashedCapabilities = YES;
    _xmppCapabilities.autoFetchNonHashedCapabilities = NO;
    
    // Activate xmpp modules
    
    [_xmppReconnect         activate:_xmppStream];
    [_xmppRoster            activate:_xmppStream];
    [_xmppvCardTempModule   activate:_xmppStream];
    [_xmppvCardAvatarModule activate:_xmppStream];
    [_xmppCapabilities      activate:_xmppStream];
    
    // Add ourself as a delegate to anything we may be interested in
    
    [_xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [_xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    // Optional:
    //
    // Replace me with the proper domain and port.
    // The example below is setup for a typical google talk account.
    //
    // If you don't supply a hostName, then it will be automatically resolved using the JID (below).
    // For example, if you supply a JID like 'user@quack.com/rsrc'
    // then the xmpp framework will follow the xmpp specification, and do a SRV lookup for quack.com.
    //
    // If you don't specify a hostPort, then the default (5222) will be used.
    
    //[_xmppStream setHostName:@"googlemail.com"];
    //[_xmppStream setHostPort:5222];
    
    
    // You may need to alter these settings depending on the server you're connecting to
    customCertEvaluation = YES;
}

- (void)teardownStream
{
    [_xmppStream removeDelegate:self];
    [_xmppRoster removeDelegate:self];
    
    [_xmppReconnect         deactivate];
    [_xmppRoster            deactivate];
    [_xmppvCardTempModule   deactivate];
    [_xmppvCardAvatarModule deactivate];
    [_xmppCapabilities      deactivate];
    
    [_xmppStream disconnect];
    
    _xmppStream = nil;
    _xmppReconnect = nil;
    _xmppRoster = nil;
    _xmppRosterStorage = nil;
    _xmppvCardStorage = nil;
    _xmppvCardTempModule = nil;
    _xmppvCardAvatarModule = nil;
    _xmppCapabilities = nil;
    _xmppCapabilitiesStorage = nil;
}

// It's easy to create XML elments to send and to read received XML elements.
// You have the entire NSXMLElement and NSXMLNode API's.
//
// In addition to this, the NSXMLElement+XMPP category provides some very handy methods for working with XMPP.
//
// On the iPhone, Apple chose not to include the full NSXML suite.
// No problem - we use the KissXML library as a drop in replacement.
//
// For more information on working with XML elements, see the Wiki article:
// https://github.com/robbiehanson/XMPPFramework/wiki/WorkingWithElements

- (void)goOnline
{
    XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
    
    NSString *domain = [_xmppStream.myJID domain];
    
    //Google set their presence priority to 24, so we do the same to be compatible.
    
    if([domain isEqualToString:@"gmail.com"] ||
       [domain isEqualToString:@"gtalk.com"] ||
       [domain isEqualToString:@"talk.google.com"])
    {
        NSXMLElement *priority = [NSXMLElement elementWithName:@"priority" stringValue:@"24"];
        [presence addChild:priority];
    }
    
    [[self xmppStream] sendElement:presence];
}

- (void)goOffline
{
    XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
    
    [[self xmppStream] sendElement:presence];
}
/*
- (BOOL)connect
{
    if (![_xmppStream isDisconnected]) {
        return YES;
    }
    
    [_xmppStream setMyJID:[XMPPJID jidWithString:xmppLogin]];
    
    return [_xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:nil];
}
*/
- (void)disconnect
{
    [self goOffline];
    [_xmppStream disconnect];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)connectXmppFromViewController:(UIViewController*)controller login:(NSString*)login password:(NSString*)password result:(void (^)(BOOL))result
{
    [MBProgressHUD showHUDAddedTo:controller.view animated:YES];
    [_xmppStream setMyJID:[XMPPJID jidWithString:login]];
    xmppPassword = password;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        connectCondition = [NSCondition new];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![_xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:nil]) {
                SIGNAL(connectCondition);
            }
        });
        WAIT(connectCondition);
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:controller.view animated:YES];
            if (isXmppConnected) {
                [[NSNotificationCenter defaultCenter] postNotificationName:XmppConnectedNotification object:nil];
            }
/*            if (isXmppConnected) {
            }*/
            result(isXmppConnected);
        });
    });
}

- (void)disconnectXmppFromViewController:(UIViewController*)controller result:(void (^)())complete
{
    [MBProgressHUD showHUDAddedTo:controller.view animated:YES];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        connectCondition = [NSCondition new];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self disconnect];
        });
        WAIT(connectCondition);
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:controller.view animated:YES];
            [[NSNotificationCenter defaultCenter] postNotificationName:XmppDisconnectedNotification object:nil];
            complete();
        });
    });
}

- (NSString*)nickNameForUser:(XMPPUserCoreDataStorageObject*)user
{
    XMPPvCardTemp *temp = [_xmppvCardTempModule vCardTempForJID:user.jid shouldFetch:YES];
    if (temp && temp.nickname && temp.nickname.length > 0) {
        return temp.nickname;
    } else {
        return user.displayName;
    }
}

- (NSData*)photoForUser:(XMPPUserCoreDataStorageObject*)user
{
    return [_xmppvCardAvatarModule photoDataForJID:user.jid];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket
{
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
    NSString *expectedCertName = [_xmppStream.myJID domain];
    if (expectedCertName)
    {
        settings[(NSString *) kCFStreamSSLPeerName] = expectedCertName;
    }
    
    if (customCertEvaluation)
    {
        settings[GCDAsyncSocketManuallyEvaluateTrust] = @(YES);
    }
}

- (void)xmppStream:(XMPPStream *)sender didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler
{
    // The delegate method should likely have code similar to this,
    // but will presumably perform some extra security code stuff.
    // For example, allowing a specific self-signed certificate that is known to the app.
    
    dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(bgQueue, ^{
        
        SecTrustResultType result = kSecTrustResultDeny;
        OSStatus status = SecTrustEvaluate(trust, &result);
        
        if (status == noErr && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
            completionHandler(YES);
        }
        else {
            completionHandler(NO);
        }
    });
}

- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    isXmppConnected = YES;
    NSError *error = nil;
    if (![[self xmppStream] authenticateWithPassword:xmppPassword error:&error])
    {
        NSLog(@"Error authenticating: %@", error);
    }
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    [self goOnline];
    isXmppConnected = YES;
    SIGNAL(connectCondition);
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
    NSLog(@"Error didNotAuthenticate: %@", error);
    isXmppConnected = NO;
    SIGNAL(connectCondition);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    if ([message isChatMessage])
    {
        dispatch_async(dispatch_get_main_queue(), ^() {
            [[Storage sharedInstance] addMessage:message toChat:message.from.bare fromMe:NO];
            [[NSNotificationCenter defaultCenter] postNotificationName:XmppMessageNotification object:message.from];
        });
    }
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    if  ([presence.type isEqualToString:@"subscribe"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:XmppSubscribeNotification object:presence];
    }
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    if (!isXmppConnected)
    {
        NSLog(@"Unable to connect to server. Check xmppStream.hostName");
    }
    isXmppConnected = NO;
    SIGNAL(connectCondition);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - XMPPRosterDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppRoster:(XMPPRoster *)sender didReceiveBuddyRequest:(XMPPPresence *)presence
{
    XMPPUserCoreDataStorageObject *user = [_xmppRosterStorage userForJID:[presence from]
                                                              xmppStream:_xmppStream
                                                    managedObjectContext:[self managedObjectContext_roster]];
    
    NSString *displayName = [user displayName];
    NSString *jidStrBare = [presence fromStr];
    NSString *body = nil;
    
    if (![displayName isEqualToString:jidStrBare])
    {
        body = [NSString stringWithFormat:@"Buddy request from %@ <%@>", displayName, jidStrBare];
    }
    else
    {
        body = [NSString stringWithFormat:@"Buddy request from %@", displayName];
    }
    
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:displayName
                                                            message:body
                                                           delegate:nil
                                                  cancelButtonTitle:@"Not implemented"
                                                  otherButtonTitles:nil];
        [alertView show];
    }
    else
    {
        // We are not active, so use a local notification instead
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.alertAction = @"Not implemented";
        localNotification.alertBody = body;
        
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
    }
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Split view
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)splitViewController:(UISplitViewController*)svc shouldHideViewController:(UIViewController *)vc inOrientation:(UIInterfaceOrientation)orientation
{
    return NO;
}

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController
{
    return YES;
}

- (UIBarButtonItem*)displayModeButton
{
    return _splitViewController.displayModeButtonItem;
}

- (BOOL)splitViewController:(UISplitViewController *)splitViewController
   showDetailViewController:(UIViewController *)vc
                     sender:(id)sender
{
    if (splitViewController.collapsed) {
        UIViewController *secondViewController =  nil;
        if([vc isKindOfClass:[UINavigationController class]]) {
            UINavigationController *secondNavigationController = (UINavigationController*)vc;
            secondViewController = [secondNavigationController topViewController];
        } else {
            secondViewController = vc;
        }
        UINavigationController* master = (UINavigationController*)splitViewController.viewControllers[0];
        [master pushViewController:secondViewController animated:YES];
        return YES;
    }
    return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Push notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *location = [locations lastObject];
    if (location) {
        PFUser *user = [PFUser currentUser];
        if (user) {
//            NSLog(@"%f - %f", location.coordinate.latitude, location.coordinate.longitude);
            NSDictionary *locObject = @{@"latitude" : [NSNumber numberWithDouble:location.coordinate.latitude],
                                        @"longitude": [NSNumber numberWithDouble:location.coordinate.longitude],
                                        @"time" : [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]]};
            user[@"location"] = locObject;
            [user saveInBackground];
        }
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Push notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)pushMessageToUser:(NSString*)user
{
    // Build a query to match user
    PFQuery *query = [PFUser query];
    [query whereKey:@"jabber" equalTo:user];
    NSString *message = [NSString stringWithFormat:@"You have received a message from %@", [PFUser currentUser].email];
    NSDictionary *data = @{@"alert" : message, @"badge" : @"Increment", @"sound": @"default"};
    PFPush *push = [[PFPush alloc] init];
    [push setQuery:query];
    [push setData:data];
    [push sendPushInBackground];
}

@end
