//
//  IconView.m
//  iNear
//
//  Created by Sergey Seitov on 11.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "IconView.h"
#import "AppDelegate.h"
#import <CommonCrypto/CommonDigest.h>

@interface IconView ()

@property (strong, nonatomic) UILabel* shortName;

@end

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
    //return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

@implementation IconView

- (void)awakeFromNib
{
    self.clipsToBounds = YES;

    _shortName = [[UILabel alloc] initWithFrame:self.bounds];
    _shortName.textColor = [UIColor whiteColor];
    _shortName.textAlignment = NSTextAlignmentCenter;
    _shortName.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:24];
    _shortName.backgroundColor = [UIColor clearColor];
    [self addSubview:_shortName];
}

- (void)layoutSubviews
{
    self.layer.cornerRadius = self.frame.size.width/2;
    _shortName.frame = self.bounds;
}

- (void)setIconForUser:(XMPPUserCoreDataStorageObject*)user
{
    _shortName.text = @"";
    if (user.photo) {
        self.image = user.photo;
    } else {
        NSData *photoData = [[AppDelegate sharedInstance] photoForUser:user];
        if (photoData != nil) {
            self.image = [UIImage imageWithData:photoData];
        } else {
            self.image = nil;
            NSString* displayName = [[AppDelegate sharedInstance] nickNameForUser:user];
            [self.layer setBackgroundColor:MD5color(displayName).CGColor];
            _shortName.text = [[displayName substringWithRange:NSMakeRange(0, 2)] uppercaseString];
        }
    }
}

@end
