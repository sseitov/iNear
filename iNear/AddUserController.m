//
//  AddUserController.m
//  iNear
//
//  Created by Sergey Seitov on 11.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "AddUserController.h"

#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

@interface AddUserController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *userField;

@end

@implementation AddUserController

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (!IS_PAD) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                              target:self
                                                                                              action:@selector(cancel)];
    }
    [_userField becomeFirstResponder];
}

- (void)cancel
{
    [_userField resignFirstResponder];
    [self.delegate addUserController:self addUser:nil];
}

#pragma mark - UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.view endEditing:YES];
    [self.delegate addUserController:self addUser:textField.text];
    return YES;
}

@end
