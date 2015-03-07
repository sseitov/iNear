//
//  ProfileController.h
//  iNear
//
//  Created by Sergey Seitov on 06.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ProfileController;

@protocol ProfileControllerDelegate <NSObject>

- (void)controller:(ProfileController*)controller didFinish:(NSString*)displayName;

@end

@interface ProfileController : UIViewController

+ (UIColor*)MD5color:(NSString*)toMd5;

@property (weak, nonatomic) id<ProfileControllerDelegate> delegate;
@property (strong, nonatomic) NSString* serviceType;

@end
