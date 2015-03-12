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
#import "Storage.h"

@interface ProfileController () <UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UITextField *account;
@property (weak, nonatomic) IBOutlet UITextField *password;
@property (weak, nonatomic) IBOutlet UITextField *displayName;
@property (weak, nonatomic) IBOutlet UIButton *status;
@property (weak, nonatomic) IBOutlet UIButton *upload;
@property (weak, nonatomic) IBOutlet UIButton *takeImage;

- (IBAction)takePhoto:(id)sender;
- (IBAction)connect:(id)sender;
- (IBAction)uploadCard:(id)sender;

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
    
    NSData* imageData = [Storage myImage];
    if (imageData) {
        _profileImage.image = [UIImage imageWithData:imageData];
        [_takeImage addSubview:_profileImage];
    }
    _account.text = [Storage myJid];
    _password.text = [Storage myPassword];
    _displayName.text = [Storage myNick];
    
    if ([self.appDelegate isXMPPConnected]) {
        [self handleConnected:nil];
    } else {
        [self handleDisconnected:nil];
    }
    
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
        [Storage setMyJid:_account.text];
        [Storage setMyPassword:_password.text];
    } else {
        [self connectionError];
        return;
    }
    
    
    [self.appDelegate connectXmppFromViewController:self result:^(BOOL result) {
        if (!result) {
            [self connectionError];
        } else {
            XMPPvCardTemp *myVcardTemp = [self.appDelegate.xmppvCardTempModule myvCardTemp];
            if (myVcardTemp) {
                NSData* imageData = myVcardTemp.photo;
                if (imageData && [Storage myImage] == nil) {
                    _profileImage.image = [UIImage imageWithData:imageData];
                    if (!_profileImage.superview) {
                        [_takeImage addSubview:_profileImage];
                    }
                    [Storage setMyImage:imageData];
                }
                NSString* nick = myVcardTemp.nickname;
                if (nick && [[Storage myNick] isEqual:@""]) {
                    _displayName.text = nick;
                    [Storage setMyNick:nick];
                }
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
    [Storage setMyNick:_displayName.text];
    dispatch_queue_t queue = dispatch_queue_create("queue", DISPATCH_QUEUE_PRIORITY_DEFAULT);
    dispatch_async(queue, ^{
        XMPPvCardTemp *myVcardTemp = [self.appDelegate.xmppvCardTempModule myvCardTemp];
        if (!myVcardTemp) {
            NSXMLElement *vCardXML = [NSXMLElement elementWithName:@"vCard" xmlns:@"vcard-temp"];
            myVcardTemp = [XMPPvCardTemp vCardTempFromElement:vCardXML];
        }
        if ([Storage myImage]) {
            [myVcardTemp setPhoto:[Storage myImage]];
        }
        [myVcardTemp setNickname:[Storage myNick]];
        [self.appDelegate.xmppvCardTempModule updateMyvCardTemp:myVcardTemp];
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
        NSData *pngData = UIImageJPEGRepresentation(imageToSave, .5);
        [Storage setMyImage:pngData];
        dispatch_async(dispatch_get_main_queue(), ^{
            _profileImage.image = imageToSave;
            if (!_profileImage.superview) {
                [_takeImage addSubview:_profileImage];
            }
        });
    });
}

@end
