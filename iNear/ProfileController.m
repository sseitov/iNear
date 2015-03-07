//
//  ProfileController.m
//  iNear
//
//  Created by Sergey Seitov on 06.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ProfileController.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <CommonCrypto/CommonDigest.h>

@interface ProfileController () <UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UITextFieldDelegate>
{
    UITextField * activeTextField;
}

@property (weak, nonatomic) IBOutlet UITextField *displayNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *firstNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *lastNameTextField;
@property (weak, nonatomic) IBOutlet UIImageView *profileImage;

- (IBAction)done:(id)sender;
- (IBAction)takePhoto:(id)sender;

@end

@implementation ProfileController

+ (UIColor*)MD5color:(NSString*)toMd5
{
    // Create pointer to the string as UTF8
    const char *ptr = [toMd5 UTF8String];
    
    // Create byte array of unsigned chars
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    
    // Create 16 byte MD5 hash value, store in buffer
    CC_MD5(ptr, (CC_LONG)strlen(ptr), md5Buffer);
    
    float r = (float)md5Buffer[0]/256.0;
    float g = (float)md5Buffer[1]/256.0;
    float b = (float)md5Buffer[2]/256.0;
    
    // take the first decimal part to avoid the gaussian distribution in the middle
    // (most users will be blueish without this)
    r *= 10;
    int r_i = (int)r;
    r -= r_i;
    NSLog(@"R %f G %f B %f", r,g,b);
    return [UIColor colorWithHue:r saturation:1.0 brightness:1.0 alpha:1.0];
    //return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSData* imageData = [[NSUserDefaults standardUserDefaults] objectForKey:@"profileImage"];
    if (imageData) {
        self.profileImage.image = [UIImage imageWithData:imageData];
        self.profileImage.layer.cornerRadius = self.profileImage.frame.size.width/2;
        self.profileImage.clipsToBounds = YES;
    }
    _firstNameTextField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"firstNameKey"];
    _lastNameTextField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastNameKey"];
    self.displayNameTextField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"displayNameKey"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillToggle:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillToggle:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) keyboardWillToggle:(NSNotification *)aNotification
{
    CGRect frame = activeTextField.frame;
    CGRect keyboard = [[aNotification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    float offset  = keyboard.origin.y - frame.origin.y - frame.size.height - 64;
    
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

- (BOOL)isDisplayNameAndServiceTypeValid
{
    MCPeerID *peerID;
    @try {
        peerID = [[MCPeerID alloc] initWithDisplayName:self.displayNameTextField.text];
    }
    @catch (NSException *exception) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:[NSString stringWithFormat:@"Invalid display name '%@'", self.displayNameTextField.text]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return NO;
    }
    
    MCNearbyServiceAdvertiser *advertiser;
    @try {
        advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:peerID discoveryInfo:nil serviceType:self.serviceType];
    }
    @catch (NSException *exception) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:[NSString stringWithFormat:@"Invalid service type '%@'", self.serviceType]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return NO;
    }
    
    return YES;
}

- (IBAction)done:(id)sender
{
    if ([self isDisplayNameAndServiceTypeValid]) {
        [[NSUserDefaults standardUserDefaults] setObject:_firstNameTextField.text forKey:@"firstNameKey"];
        [[NSUserDefaults standardUserDefaults] setObject:_lastNameTextField.text forKey:@"lastNameKey"];
        [[NSUserDefaults standardUserDefaults] setObject:_displayNameTextField.text forKey:@"displayNameKey"];
        [self.delegate controller:self didFinish:_displayNameTextField.text];
    }
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
        }
        [self presentViewController:imagePicker animated:YES completion:nil];
    }
}

#pragma mark - UIImagePickerViewControllerDelegate

// For responding to the user tapping Cancel.
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// Override this delegate method to get the image that the user has selected and send it view Multipeer Connectivity to the connected peers.
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    // Don't block the UI when writing the image to documents
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // We only handle a still image
        UIImage *imageToSave = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage];
        // Save the new image to the documents directory
        NSData *pngData = UIImageJPEGRepresentation(imageToSave, 1.0);
        [[NSUserDefaults standardUserDefaults] setObject:pngData forKey:@"profileImage"];
        // Add the transcript to the data source and reload
        dispatch_async(dispatch_get_main_queue(), ^{
            self.profileImage.image  = imageToSave;
            self.profileImage.layer.cornerRadius = self.profileImage.frame.size.width/2;
            self.profileImage.clipsToBounds = YES;
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
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [self.view endEditing:YES];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == _firstNameTextField || textField == _lastNameTextField) {
        NSRange r = {0, 1};
        _displayNameTextField.text = [NSString stringWithFormat:@"%@%@",
                                      _firstNameTextField.text.length > 0 ? [_firstNameTextField.text substringWithRange:r].lowercaseString: @"",
                                      _lastNameTextField.text.lowercaseString];
    }
    return YES;
}

@end
