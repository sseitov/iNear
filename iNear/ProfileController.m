//
//  ProfileController.m
//  iNear
//
//  Created by Sergey Seitov on 06.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ProfileController.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <CommonCrypto/CommonDigest.h>

@interface ProfileController ()

@property (weak, nonatomic) IBOutlet UITextField *displayNameTextField;

- (IBAction)done:(id)sender;

@end

@implementation ProfileController

+ (UIColor*)MD5color:(NSString*)toMd5
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
    //return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (BOOL)isDisplayNameAndServiceTypeValid
{
    MCPeerID *peerID;
    @try {
        peerID = [[MCPeerID alloc] initWithDisplayName:self.displayNameTextField.text];
    }
    @catch (NSException *exception) {
        NSLog(@"Invalid display name [%@]", self.displayNameTextField.text);
        return NO;
    }
    
    MCNearbyServiceAdvertiser *advertiser;
    @try {
        advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:peerID discoveryInfo:nil serviceType:self.serviceType];
    }
    @catch (NSException *exception) {
        NSLog(@"Invalid service type [%@]", self.serviceType);
        return NO;
    }
    
    NSLog(@"Room Name [%@] (aka service type) and display name [%@] are valid", advertiser.serviceType, peerID.displayName);
    return YES;
}

- (IBAction)done:(id)sender
{
    if ([self isDisplayNameAndServiceTypeValid]) {
        NSDictionary *profile = @{@"displayName" : self.displayNameTextField.text};
        [self.delegate controller:self didFinishProfile:profile];
    } else {
        
    }
}

@end
