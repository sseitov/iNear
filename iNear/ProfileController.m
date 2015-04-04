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
#import <Parse/Parse.h>

@interface ProfileController () <UITextFieldDelegate, UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UITextField *account;
@property (weak, nonatomic) IBOutlet UITextField *password;
@property (weak, nonatomic) IBOutlet UITextField *displayName;

@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UIButton *takeImageButton;
@property (weak, nonatomic) IBOutlet UISwitch *storePasswordSwitch;

- (IBAction)takePhoto:(id)sender;
- (IBAction)connect:(id)sender;
- (IBAction)storePassword:(UISwitch *)sender;

@property (strong, nonatomic) UIImageView *profileImage;

@end

@implementation ProfileController

+ (UIColor*)connectedColor
{
    return [UIColor colorWithRed:28./255. green:79./255. blue:130./255. alpha:1.];

}

+ (UIColor*)disconnectedColor
{
    return [UIColor colorWithRed:1. green:102./255. blue:102./255. alpha:1.];
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (![AppDelegate isPad]) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                                                 style:UIBarButtonItemStylePlain
                                                                                target:self
                                                                                action:@selector(goBack)];
    }
    
    _takeImageButton.layer.borderWidth = 1.0;
    _takeImageButton.layer.masksToBounds = YES;
    _takeImageButton.layer.cornerRadius = 20.0;

    _actionButton.layer.borderWidth = 1.0;
    _actionButton.layer.masksToBounds = YES;
    _actionButton.layer.cornerRadius = 7.0;

    _profileImage = [[UIImageView alloc] initWithFrame:_takeImageButton.bounds];
    _profileImage.layer.cornerRadius = _profileImage.frame.size.width/2;
    _profileImage.clipsToBounds = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleConnected:) name:XmppConnectedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleConnected:) name:XmppDisconnectedNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (![PFUser currentUser]) {
        [self performSegueWithIdentifier:@"SignUp" sender:self];
    } else {
        [self updateUI];
    }
}

- (void)goBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleConnected:(NSNotification *)aNotification
{
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self updateUI];
    });
}

- (void)updateUI
{
    PFUser* user = [PFUser currentUser];
    if (user) {
        _account.text = user[@"jabber"];
        _displayName.text = user[@"displayName"];
        _storePasswordSwitch.on = [user[@"storePassword"] boolValue];
        if (_storePasswordSwitch.on) {
            _password.text = user[@"jabberPassword"];
        }
        if (user[@"photo"]) {
            _profileImage.image = [UIImage imageWithData:user[@"photo"]];
            [_takeImageButton addSubview:_profileImage];
        }
    }

    if ([[AppDelegate sharedInstance] isXMPPConnected]) {
        _actionButton.backgroundColor = [ProfileController connectedColor];
        [_actionButton setTitle:@"Update photo & nick" forState:UIControlStateNormal];
    } else {
        _actionButton.backgroundColor = [ProfileController disconnectedColor];
        [_actionButton setTitle:@"Connect to Jabber" forState:UIControlStateNormal];
    }
    _actionButton.layer.borderColor = _actionButton.backgroundColor.CGColor;
}

- (void)connectionError:(NSString*)message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connection Error!"
                                                    message:message //
                                                   delegate:nil
                                          cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
    [alert show];
}

- (void)doConnect
{
    if (!_account.text || !_password.text) {
        [self connectionError:@"Check your jabber login and password."];
        return;
    }
    
    [[AppDelegate sharedInstance] connectXmppFromViewController:self
                                                          login:_account.text
                                                       password:_password.text
                                                         result:^(BOOL result)
    {
        if (!result) {
            [self connectionError:@"Check your jabber login and password."];
        } else {
            [PFUser currentUser][@"jabber"] = _account.text;
            [PFUser currentUser][@"storePassword"] = [NSNumber numberWithBool:_storePasswordSwitch.on];
            if (_storePasswordSwitch.on) {
                [PFUser currentUser][@"jabberPassword"] = _password.text;
            } else {
                [PFUser currentUser][@"jabberPassword"] = @"";
            }
            [[PFUser currentUser] saveInBackground];
            
            [PFInstallation currentInstallation][@"jabber"] = _account.text;
            [[PFInstallation currentInstallation] saveInBackground];
            
            XMPPvCardTemp *myVcardTemp = [[AppDelegate sharedInstance].xmppvCardTempModule myvCardTemp];
            if (myVcardTemp) {
                NSData* imageData = myVcardTemp.photo;
                if (imageData) {
                    [PFUser currentUser][@"photo"] = imageData;
                    _profileImage.image = [UIImage imageWithData:imageData];
                    if (!_profileImage.superview) {
                        [_takeImageButton addSubview:_profileImage];
                    }
                }
                NSString* nick = myVcardTemp.nickname;
                if (nick) {
                    [PFUser currentUser][@"displayName"] = nick;
                    _displayName.text = nick;
                }
            }
        }
    }];
}

- (IBAction)connect:(id)sender
{
    if ([[AppDelegate sharedInstance] isXMPPConnected]) {
        [self uploadInfo];
    } else {
        [self doConnect];
    }
}

- (IBAction)storePassword:(UISwitch *)sender {
}

- (void)uploadInfo
{
    if (_profileImage.image) {
        NSData *pngData = UIImageJPEGRepresentation(_profileImage.image, .5);
        [PFUser currentUser][@"photo"] = pngData;
    }
    if (_displayName.text) {
        [PFUser currentUser][@"displayName"] = _displayName.text;
    }
    [[PFUser currentUser] saveInBackground];
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
- (UIImage *)scaleImage:(UIImage*)image toResolution:(int)resolution
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
        UIImage *imageToSave = [self scaleImage:(UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage]
                                   toResolution:128];
        dispatch_async(dispatch_get_main_queue(), ^{
            _profileImage.image = imageToSave;
            if (!_profileImage.superview) {
                [_takeImageButton addSubview:_profileImage];
            }
        });
    });
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

@end
