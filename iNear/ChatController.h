//
//  ChatController.h
//  iNear
//
//  Created by Sergey Seitov on 09.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XMPPFramework.h"

@interface ChatController : UITableViewController

@property (strong, nonatomic) XMPPUserCoreDataStorageObject *user;

@end
