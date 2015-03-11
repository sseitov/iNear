//
//  ProfileController.m
//  iNear
//
//  Created by Sergey Seitov on 08.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ProfileController.h"
#import "AppDelegate.h"
#import "XMPPvCardTemp.h"

@interface ProfileController () <UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>
{
    UITextField * activeTextField;
}

@property (weak, nonatomic) IBOutlet UITextField *account;
@property (weak, nonatomic) IBOutlet UITextField *password;
@property (weak, nonatomic) IBOutlet UITextField *displayName;
@property (weak, nonatomic) IBOutlet UIButton *status;
@property (weak, nonatomic) IBOutlet UIButton *upload;
@property (weak, nonatomic) IBOutlet UIButton *takeImage;

- (IBAction)takePhoto:(id)sender;
- (IBAction)connect:(id)sender;
- (IBAction)uploadCard:(id)sender;

@property (strong, nonatomic) NSMutableDictionary *profile;
@property (strong, nonatomic) UIImageView *profileImage;

@end

@implementation ProfileController

- (AppDelegate *)appDelegate
{
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.leftBarButtonItem = nil;
    
    _status.layer.borderWidth = 1.0;
    _status.layer.masksToBounds = YES;
    _status.layer.cornerRadius = 7.0;

    _upload.layer.borderWidth = 1.0;
    _upload.layer.masksToBounds = YES;
    _upload.layer.cornerRadius = 7.0;
    _upload.backgroundColor = [UIColor colorWithRed:28./256. green:79./256. blue:130./256. alpha:1.];
    _upload.layer.borderColor = _upload.backgroundColor.CGColor;

    _profileImage = [[UIImageView alloc] initWithFrame:_takeImage.bounds];
    _profileImage.layer.cornerRadius = _profileImage.frame.size.width/2;
    _profileImage.clipsToBounds = YES;
    
    NSDictionary * dict = [[NSUserDefaults standardUserDefaults] objectForKey:@"profile"];
    if (dict) {
        _profile = [NSMutableDictionary dictionaryWithDictionary:dict];
    } else {
        _profile = [NSMutableDictionary new];
    }
    
    NSData* imageData = [_profile objectForKey:@"image"];
    if (imageData) {
        _profileImage.image = [UIImage imageWithData:imageData];
        [_takeImage addSubview:_profileImage];
    }
    _account.text = [_profile objectForKey:@"account"];
    _password.text = [_profile objectForKey:@"password"];
    _displayName.text = [_profile objectForKey:@"displayName"];
    
    if ([self.appDelegate isXMPPConnected]) {
        [self handleConnected:nil];
    } else {
        [self handleDisconnected:nil];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillToggle:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillToggle:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleConnected:) name:XmppConnectedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDisconnected:) name:XmppDisconnectedNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) handleConnected:(NSNotification *)aNotification
{
    [_status setTitle:@"Reconnect" forState:UIControlStateNormal];
    _status.backgroundColor = [UIColor colorWithRed:28./256. green:79./256. blue:130./256. alpha:1.];
    _status.layer.borderColor = _status.backgroundColor.CGColor;
    _upload.enabled = YES;
}

- (void) handleDisconnected:(NSNotification *)aNotification
{
    [_status setTitle:@"Connect" forState:UIControlStateNormal];
    _status.backgroundColor = [UIColor colorWithRed:1. green:51./256. blue:51./256. alpha:1.];
    _status.layer.borderColor = _status.backgroundColor.CGColor;
    _upload.enabled = NO;
}

- (void) keyboardWillToggle:(NSNotification *)aNotification
{
    CGRect frame = activeTextField.frame;
    CGRect keyboard = [[aNotification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    float offset  = keyboard.origin.y - frame.origin.y - frame.size.height - 64 - 20;
    
    CGRect rect = self.view.frame;
    if ([aNotification.name  isEqualToString:@"UIKeyboardWillShowNotification"]) {
        if (offset > 0) {
            return;
        }
        rect.origin.y += offset;
    } else {
        if (rect.origin.y == 64) {
            return;
        }
        rect.origin.y = 64;
    }
    
    float duration = [[aNotification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    [UIView animateWithDuration:duration animations:^() {
        self.view.frame = rect;
    }];
}

- (void)connectionError
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connection Error!"
                                                    message:@"Check your login and password."
                                                   delegate:nil
                                          cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
    [alert show];
}

- (void)doConnect
{
    if (_account.text && _password.text) {
        [_profile setObject:_account.text forKey:@"account"];
        [_profile setObject:_password.text forKey:@"password"];
    } else {
        [self connectionError];
        return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:_profile forKey:@"profile"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    
    [self.appDelegate connectXmppFromViewController:self result:^(BOOL result) {
        if (!result) {
            [self connectionError];
        } else {
            
            XMPPvCardTemp *myVcardTemp = [self.appDelegate.xmppvCardTempModule myvCardTemp];
            if (myVcardTemp) {
                NSData* imageData = myVcardTemp.photo;
                if (imageData && [_profile objectForKey:@"image"] == nil) {
                    _profileImage.image = [UIImage imageWithData:imageData];
                    if (!_profileImage.superview) {
                        [_takeImage addSubview:_profileImage];
                    }
                    [_profile setObject:imageData forKey:@"image"];
                }
                NSString* nick = myVcardTemp.nickname;
                if (nick && [_profile objectForKey:@"displayName"] == nil) {
                    _displayName.text = nick;
                    [_profile setObject:nick forKey:@"displayName"];
                }
                [[NSUserDefaults standardUserDefaults] setObject:_profile forKey:@"profile"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
    }];
}

- (IBAction)connect:(id)sender
{
    if ([self.appDelegate isXMPPConnected]) {
        [[self appDelegate] disconnectXmppFromViewController:self result:^() {
            [self doConnect];
        }];
    } else {
        [self doConnect];
    }
}

- (IBAction)uploadCard:(id)sender
{
    dispatch_queue_t queue = dispatch_queue_create("queue", DISPATCH_QUEUE_PRIORITY_DEFAULT);
    dispatch_async(queue, ^{
        XMPPvCardTemp *myVcardTemp = [self.appDelegate.xmppvCardTempModule myvCardTemp];
        if (!myVcardTemp) {
            NSXMLElement *vCardXML = [NSXMLElement elementWithName:@"vCard" xmlns:@"vcard-temp"];
            myVcardTemp = [XMPPvCardTemp vCardTempFromElement:vCardXML];
        }
        if ([_profile objectForKey:@"image"]) {
            [myVcardTemp setPhoto:[_profile objectForKey:@"image"]];
        }
        if ([_profile objectForKey:@"displayName"]) {
            [myVcardTemp setNickname:[_profile objectForKey:@"displayName"]];
        }
        [self.appDelegate.xmppvCardTempModule updateMyvCardTemp:myVcardTemp];
        [[NSUserDefaults standardUserDefaults] setObject:_profile forKey:@"profile"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
}

- (IBAction)takePhoto:(id)sender
{
    // Preset an action sheet which enables the user to take a new picture or select and existing one.
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel"  destructiveButtonTitle:nil otherButtonTitles:@"Take Photo", @"Choose Existing", nil];
    
    // Show the action sheet
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 2) {
        return;
    }
    
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    
    if (imagePicker) {
        // set the delegate and source type, and present the image picker
        imagePicker.delegate = self;
        if (0 == buttonIndex) {
            if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
            } else {
                // Problem with camera, alert user
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Camera" message:@"Please use a camera enabled device" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
                return;
            }
        }
        else if (1 == buttonIndex) {
            imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            imagePicker.modalPresentationStyle = UIModalPresentationFormSheet;
        }
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
}

#pragma mark - UIImagePickerViewControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// Change image resolution (auto-resize to fit)
+ (UIImage *)scaleImage:(UIImage*)image toResolution:(int)resolution
{
    CGImageRef imgRef = [image CGImage];
    CGFloat width = CGImageGetWidth(imgRef);
    CGFloat height = CGImageGetHeight(imgRef);
    CGRect bounds = CGRectMake(0, 0, width, height);
    
    //if already at the minimum resolution, return the orginal image, otherwise scale
    if (width <= resolution && height <= resolution) {
        return image;
        
    } else {
        CGFloat ratio = width/height;
        
        if (ratio > 1) {
            bounds.size.width = resolution;
            bounds.size.height = bounds.size.width / ratio;
        } else {
            bounds.size.height = resolution;
            bounds.size.width = bounds.size.height * ratio;
        }
    }
    
    UIGraphicsBeginImageContext(bounds.size);
    [image drawInRect:CGRectMake(0.0, 0.0, bounds.size.width, bounds.size.height)];
    UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return imageCopy;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    // Don't block the UI when writing the image to documents
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // We only handle a still image
        UIImage *imageToSave = [ProfileController scaleImage:(UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage]
                                                toResolution:128];
        NSData *pngData = UIImageJPEGRepresentation(imageToSave, .5);
        [_profile setObject:pngData forKey:@"image"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            _profileImage.image = imageToSave;
            if (!_profileImage.superview) {
                [_takeImage addSubview:_profileImage];
            }
        });
    });
}

#pragma mark - UITextFieldDelegate methods

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    activeTextField = textField;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.view endEditing:YES];
    if (textField == _displayName) {
        [_profile setObject:_displayName.text forKey:@"displayName"];
    }
    return YES;
}

@end
