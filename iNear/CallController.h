//
//  CallController.h
//  iNear
//
//  Created by Sergey Seitov on 07.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XMPPFramework.h"

@interface CallController : UIViewController

@property (strong, nonatomic) XMPPUserCoreDataStorageObject *peer;

@end
