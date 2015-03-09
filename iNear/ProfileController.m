//
//  ProfileController.m
//  iNear
//
//  Created by Sergey Seitov on 08.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ProfileController.h"
#import <CommonCrypto/CommonDigest.h>
#import "AppDelegate.h"

@interface ProfileController () <UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>
{
    UITextField * activeTextField;
}

@property (weak, nonatomic) IBOutlet UIImageView *profileImage;
@property (weak, nonatomic) IBOutlet UITextField *account;
@property (weak, nonatomic) IBOutlet UITextField *password;

- (IBAction)takePhoto:(id)sender;
- (IBAction)connect:(id)sender;

@property (strong, nonatomic) NSMutableDictionary *profile;

@end

@implementation ProfileController

- (AppDelegate *)appDelegate
{
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

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
    
    NSDictionary * dict = [[NSUserDefaults standardUserDefaults] objectForKey:@"profile"];
    if (dict) {
        _profile = [NSMutableDictionary dictionaryWithDictionary:dict];
    } else {
        _profile = [NSMutableDictionary new];
    }
    NSData* imageData = [_profile objectForKey:@"image"];
    if (imageData) {
        _profileImage.image = [UIImage imageWithData:imageData];
        _profileImage.layer.cornerRadius = self.profileImage.frame.size.width/2;
        _profileImage.clipsToBounds = YES;
    }
    _account.text = [_profile objectForKey:@"account"];
    _password.text = [_profile objectForKey:@"password"];
    
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

- (IBAction)connect:(id)sender
{
    [[self appDelegate] disconnect];
    
    [_profile setObject:_account.text forKey:@"account"];
    [_profile setObject:_password.text forKey:@"password"];
    [[NSUserDefaults standardUserDefaults] setObject:_profile forKey:@"profile"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [[self appDelegate] connect];
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

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    // Don't block the UI when writing the image to documents
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // We only handle a still image
        UIImage *imageToSave = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage];
        // Save the new image to the documents directory
        NSData *pngData = UIImageJPEGRepresentation(imageToSave, 1.0);
        [_profile setObject:pngData forKey:@"image"];
        [[NSUserDefaults standardUserDefaults] setObject:_profile forKey:@"profile"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            _profileImage.image  = imageToSave;
            _profileImage.layer.cornerRadius = self.profileImage.frame.size.width/2;
            _profileImage.clipsToBounds = YES;
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

@end
