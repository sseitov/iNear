//
//  ContactsController.m
//  iNear
//
//  Created by Sergey Seitov on 06.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ContactsController.h"
#import "ProfileController.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

NSString * const kNSDefaultDisplayNameKey = @"displayNameKey";
NSString * const kAppServiceType = @"iNearApp";

@interface ContactsController () <MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, ProfileControllerDelegate>

@property (strong, nonatomic) MCPeerID *selfPeer;
@property (strong, nonatomic) MCSession *session;
@property (strong, nonatomic) NSMutableArray *peers;
@property (strong, nonatomic) MCNearbyServiceBrowser* browser;
@property (strong, nonatomic) MCNearbyServiceAdvertiser* advertiser;

- (IBAction)showProfile:(id)sender;

@end

@implementation ContactsController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    _peers = [NSMutableArray new];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (_session) {
        [_browser startBrowsingForPeers];
        [_advertiser startAdvertisingPeer];
    } else {
        if (![self openSession:[[NSUserDefaults standardUserDefaults] objectForKey:kNSDefaultDisplayNameKey]]) {
            [self performSegueWithIdentifier:@"CreateProfile" sender:self];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (_session) {
        [_browser stopBrowsingForPeers];
        [_advertiser stopAdvertisingPeer];
    }
}

- (IBAction)showProfile:(id)sender
{
    [self performSegueWithIdentifier:@"CreateProfile" sender:self];
}

- (BOOL)openSession:(NSString*)displayName
{
    @try {
        _selfPeer = [[MCPeerID alloc] initWithDisplayName:displayName];
    }
    @catch (NSException *exception) {
        NSLog(@"Invalid display name [%@]", displayName);
        return NO;
    }
    _session = [[MCSession alloc] initWithPeer:_selfPeer securityIdentity:nil encryptionPreference:MCEncryptionNone];
    _session.delegate = self;
    
    _browser = [[MCNearbyServiceBrowser alloc] initWithPeer:_selfPeer serviceType:kAppServiceType];
    _browser.delegate = self;
    
    _advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:_selfPeer discoveryInfo:nil serviceType:kAppServiceType];
    _advertiser.delegate = self;

    return YES;
}

- (void)closeSession
{
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _peers.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Contact" forIndexPath:indexPath];
    MCPeerID *peer = [_peers objectAtIndex:indexPath.row];
    
    UILabel* name = (UILabel*)[cell.contentView viewWithTag:2];
    name.text = peer.displayName;

    UIImageView* icon = (UIImageView*)[cell.contentView viewWithTag:1];
    [icon.layer setBackgroundColor:[[ProfileController MD5color:peer.displayName] CGColor]];
    icon.layer.cornerRadius = icon.frame.size.width/2;
    icon.clipsToBounds = YES;

    UILabel* sign = (UILabel*)[cell.contentView viewWithTag:3];
    NSRange r = {0, 2};
    sign.text = [[peer.displayName substringWithRange:r] uppercaseString];
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"CreateProfile"]) {
        UINavigationController *vc = [segue destinationViewController];
        ProfileController *next = (ProfileController*)vc.topViewController;
        next.serviceType = kAppServiceType;
        next.delegate = self;
    }
}

#pragma mark - ProfileControllerDelegate

- (void)controller:(ProfileController*)controller didFinishProfile:(NSDictionary*)profile;
{
    NSString* displayName = [profile valueForKey:@"displayName"];
    [[NSUserDefaults standardUserDefaults] setObject:displayName forKey:kNSDefaultDisplayNameKey];
    [self openSession:displayName];
    [controller dismissViewControllerAnimated:YES completion:^() {}];
}

#pragma mark - MCNearbyServiceBrowserDelegate

// Found a nearby advertising peer
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    NSLog(@"foundPeer %@", peerID);
    if (![_peers containsObject:peerID]) {
        [_peers addObject:peerID];
        [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
    }
}

// A nearby peer has stopped advertising
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    NSLog(@"lostPeer %@", peerID.displayName);
    if ([_peers containsObject:peerID]) {
        [_peers removeObject:peerID];
        [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
    }
}

// Browsing did not start due to an error
- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    NSLog(@"ERROR: didNotStartBrowsingForPeers: %@", error);
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
    NSLog(@"ERROR: didNotStartAdvertisingPeer: %@", error);
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler
{
    NSLog(@"didReceiveInvitationFromPeer %@", peerID.displayName);
}

#pragma mark - MCSessionDelegate

// Remote peer changed state
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    
}

// Received data from remote peer
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    
}

// Received a byte stream from remote peer
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    
}

// Start receiving a resource from remote peer
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    
}

// Finished receiving a resource from remote peer and saved the content in a temporary location - the app is responsible for moving the file to a permanent location within its sandbox
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    
}
@end
