//
//  AddUserController.m
//  iNear
//
//  Created by Sergey Seitov on 11.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "AddUserController.h"
#import "AppDelegate.h"

enum FindError {
    UserNotFound,
    UserWithoutJabber
};

@interface AddUserController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *photo;
@property (weak, nonatomic) IBOutlet UILabel *nick;
@property (weak, nonatomic) IBOutlet UITextField *userEmail;

- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;

@property (strong, nonatomic) PFUser* friend;

@end

@implementation AddUserController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

#pragma mark - UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.view endEditing:YES];
    return YES;
}

- (void)error:(enum FindError)error findUser:(NSString*)email
{
    NSString* message;
    if (error == UserNotFound) {
        message = @"User not registered in iNear";
    } else {
        message = @"User not connected to jabber";
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:email
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"Ok"
                                          otherButtonTitles:nil, nil];
    [alert show];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField.text.length < 1) {
        return;
    }
    [textField resignFirstResponder];
    PFQuery *query = [PFUser query];
    [query whereKey:@"email" equalTo:textField.text];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError* error) {
        if (!error) {
            _friend =  [objects firstObject];
            if (_friend) {
                if (_friend[@"jabber"]) {
                    _nick.text = _friend[@"displayName"];
                    NSData* photoData = _friend[@"photo"];
                    if (photoData) {
                        _photo.image = [UIImage imageWithData:photoData];
                        _photo.layer.cornerRadius = _photo.frame.size.width/2;
                        _photo.clipsToBounds = YES;
                    }
                } else {
                    _friend = nil;
                    [self error:UserWithoutJabber findUser:textField.text];
                }
            } else {
                [self error:UserNotFound findUser:textField.text];
            }
        } else {
            [self error:UserNotFound findUser:textField.text];
        }
    }];
}

- (IBAction)cancel:(id)sender
{
    _userEmail.text = @"";
    [_userEmail resignFirstResponder];
    [self.delegate addUserController:self addUser:nil];
}

- (IBAction)done:(id)sender
{
    [self.delegate addUserController:self addUser:_friend];
}

@end
