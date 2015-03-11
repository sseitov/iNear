//
//  AddUserController.h
//  iNear
//
//  Created by Sergey Seitov on 11.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AddUserController;

@protocol AddUserControllerDelegate <NSObject>

- (void)addUserController:(AddUserController*)controller addUser:(NSString*)user;

@end

@interface AddUserController : UIViewController

@property (weak, nonatomic) id<AddUserControllerDelegate> delegate;

@end
