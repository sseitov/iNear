//
//  IconView.h
//  iNear
//
//  Created by Sergey Seitov on 11.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XMPPFramework.h"

@interface IconView : UIImageView

- (void)setIconForUser:(XMPPUserCoreDataStorageObject*)user;

@end
