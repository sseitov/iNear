//
//  SignUpController.m
//  iNear
//
//  Created by Sergey Seitov on 04.04.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "SignUpController.h"
#import <Parse/Parse.h>
#import <MBProgressHUD/MBProgressHUD.h>

@interface SignUpController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *email;
@property (weak, nonatomic) IBOutlet UITextField *password;
@property (weak, nonatomic) IBOutlet UIButton *signUpButton;
@property (weak, nonatomic) IBOutlet UIButton *resetPasswordButton;

- (IBAction)signUp:(id)sender;
- (IBAction)resetPassword:(id)sender;

@end

@implementation SignUpController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"iNear SignUp";
    
    _signUpButton.layer.borderWidth = 1.0;
    _signUpButton.layer.masksToBounds = YES;
    _signUpButton.layer.cornerRadius = 7.0;
    _signUpButton.layer.borderColor = _signUpButton.backgroundColor.CGColor;

    _resetPasswordButton.layer.borderWidth = 1.0;
    _resetPasswordButton.layer.masksToBounds = YES;
    _resetPasswordButton.layer.cornerRadius = 7.0;
    _resetPasswordButton.layer.borderColor = _resetPasswordButton.backgroundColor.CGColor;
}

- (void)printMessage:(NSString*)title message:(NSString*)message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
    [alert show];
}

- (IBAction)signUp:(id)sender
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [PFUser logInWithUsernameInBackground:_email.text password:_password.text
                                    block:^(PFUser *user, NSError *error) {
                                        if (user) {
                                            [MBProgressHUD hideHUDForView:self.view animated:YES];
                                            [self.navigationController popViewControllerAnimated:YES];
                                        } else {
                                            user = [PFUser user];
                                            user.username = _email.text;
                                            user.password = _password.text;
                                            user.email = _email.text;
                                            [user signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                                                [MBProgressHUD hideHUDForView:self.view animated:YES];
                                                if (!error) {
                                                    [self.navigationController popViewControllerAnimated:YES];
                                                } else {
                                                    [self printMessage:@"SignUp error" message:[error userInfo][@"error"]];
                                                }
                                            }];                                                    }
                                    }];
}

- (IBAction)resetPassword:(id)sender
{
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [PFUser requestPasswordResetForEmailInBackground:_email.text block:^(BOOL succeeded, NSError *error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        if (!succeeded) {
            [self printMessage:@"Reset password error" message:[error userInfo][@"error"]];
        } else {
            [self printMessage:@"Reset password done" message:@"Check your email and follow instructions."];
        }
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

@end
