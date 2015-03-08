//
//  ContactsController.m
//  iNear
//
//  Created by Sergey Seitov on 06.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ContactsController.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <CommonCrypto/CommonDigest.h>

#define kAppServiceType @"iNearApp"
#define kDisplayNameKey @"displayNameKey"

UIColor* MD5color(NSString *toMd5)
{
    // Create pointer to the string as UTF8
    const char *ptr = [toMd5 UTF8String];
    
    // Create byte array of unsigned chars
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    
    // Create 16 byte MD5 hash value, store in buffer
    CC_MD5(ptr, (CC_LONG)strlen(ptr), md5Buffer);
    
    float r = (float)md5Buffer[0]/256.0;
    float g = (float)md5Buffer[1]/256.0;
    float b = (float)md5Buffer[2]/256.0;
    
    // take the first decimal part to avoid the gaussian distribution in the middle
    // (most users will be blueish without this)
    r *= 10;
    int r_i = (int)r;
    r -= r_i;
    NSLog(@"R %f G %f B %f", r,g,b);
    return [UIColor colorWithHue:r saturation:1.0 brightness:1.0 alpha:1.0];
//    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

@interface ContactsController () <MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate>

@property (strong, nonatomic) MCPeerID *selfPeer;
@property (strong, nonatomic) MCSession *session;

@property (strong, nonatomic) NSMutableArray *peers;

@property (strong, nonatomic) MCNearbyServiceBrowser* browser;
@property (strong, nonatomic) MCNearbyServiceAdvertiser* advertiser;

@end

@implementation ContactsController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _peers = [NSMutableArray new];
}

- (void)dealloc
{
    [_browser stopBrowsingForPeers];
    [_advertiser stopAdvertisingPeer];
    [_session disconnect];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (!_session) {
        if (![self openSession:[[NSUserDefaults standardUserDefaults] objectForKey:kDisplayNameKey]]) {
            [self doCreateDisplayName];
        } else {
            [_browser startBrowsingForPeers];
            [_advertiser startAdvertisingPeer];
        }
    }
    [self.tableView reloadData];
}

- (void)doCreateDisplayName
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Create display name"
                                                    message:nil
                                                   delegate:self
                                          cancelButtonTitle:@"OK" otherButtonTitles:nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    UITextField *textField = [alertView textFieldAtIndex:0];
    if ([self openSession:textField.text]) {
        [[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:kDisplayNameKey];
        [_browser startBrowsingForPeers];
        [_advertiser startAdvertisingPeer];
    } else {
        [self doCreateDisplayName];
    }
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
    
    UILabel *displayName = (UILabel*)[cell.contentView viewWithTag:1];
    displayName.text = peer.displayName;

    UILabel *shortName = (UILabel*)[cell.contentView viewWithTag:2];
    NSRange r = {0, 2};
    shortName.text = [[peer.displayName substringWithRange:r] uppercaseString];

    UIImageView *icon = (UIImageView*)[cell.contentView viewWithTag:3];
    [icon.layer setBackgroundColor:MD5color(peer.displayName).CGColor];
    icon.layer.cornerRadius = icon.frame.size.width/2;
    icon.clipsToBounds = YES;
   
    return cell;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"CreateChat"]) {
        UITableViewCell* cell = sender;
        NSIndexPath* indexPath = [self.tableView indexPathForCell:cell];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        [cell setSelected:NO animated:YES];
    }
}

#pragma mark - MCNearbyServiceBrowserDelegate

// Found a nearby advertising peer
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    if (![_peers containsObject:peerID]) {
        [browser invitePeer:peerID toSession:_session withContext:nil timeout:-1];
    }
}

// A nearby peer has stopped advertising
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    if ([_peers containsObject:peerID]) {
        NSLog(@"%@ disconnected", peerID.displayName);
        [_peers removeObject:peerID];
        [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
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
    invitationHandler(YES, _session);
}

#pragma mark - MCSessionDelegate

// Remote peer changed state
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    NSLog(@"%@ change state %d", peerID.displayName, (int)state);
    switch (state) {
        case MCSessionStateConnected:
            if (![_peers containsObject:peerID]) {
                [_peers addObject:peerID];
                [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
            }
            break;
        case MCSessionStateNotConnected:
            if ([_peers containsObject:peerID]) {
                [_peers removeObject:peerID];
                [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
            }
            break;
        default:
            break;
    }
}

// Received data from remote peer
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
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

// Received a byte stream from remote peer
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
}

@end
