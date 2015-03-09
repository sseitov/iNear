//
//  ChatController.m
//  iNear
//
//  Created by Sergey Seitov on 09.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ChatController.h"
#import "AppDelegate.h"
#import "MessageView.h"
#import "ImageView.h"
#import "ProfileController.h"

@interface ChatController () <UITextFieldDelegate, UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *messageButton;
@property (weak, nonatomic) IBOutlet UITextField *message;

@property (strong, nonatomic) NSMutableArray *messages;
- (IBAction)sendImage:(id)sender;

@end

@implementation ChatController

- (AppDelegate *)appDelegate
{
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;

    self.title = _user.displayName;
    _messages = [NSMutableArray new];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMessage:) name:XmppMessageNotification object:nil];
    
    // Listen for will show/hide notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // Stop listening for keyboard notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews
{
    _messageButton.width = self.tableView.frame.size.width - 60;
}

- (void)addMessage:(XMPPMessage*)message
{
    dispatch_async(dispatch_get_main_queue(), ^() {
        [self.tableView beginUpdates];
        [_messages addObject:message];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(_messages.count - 1) inSection:0];
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationBottom];
        [self.tableView endUpdates];
    });
}

- (void)handleMessage:(NSNotification*)note
{
    XMPPUserCoreDataStorageObject *from = note.object;
    if ([from isEqual:_user]) {
        [self addMessage:[note.userInfo objectForKey:@"message"]];
    }
}

#pragma mark - Toolbar animation helpers

// Helper method for moving the toolbar frame based on user action
- (void)moveToolBarUp:(BOOL)up forKeyboardNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    
    // Get animation info from userInfo
    NSTimeInterval animationDuration;
    UIViewAnimationCurve animationCurve;
    CGRect keyboardFrame;
    [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
    [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardFrame];
    
    // Animate up or down
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:animationDuration];
    [UIView setAnimationCurve:animationCurve];
    
    [self.navigationController.toolbar setFrame:CGRectMake(self.navigationController.toolbar.frame.origin.x, self.navigationController.toolbar.frame.origin.y + (keyboardFrame.size.height * (up ? -1 : 1)), self.navigationController.toolbar.frame.size.width, self.navigationController.toolbar.frame.size.height)];
    [UIView commitAnimations];
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    [self moveToolBarUp:YES forKeyboardNotification:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    [self moveToolBarUp:NO forKeyboardNotification:notification];
}

#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.view endEditing:YES];
    [_message resignFirstResponder];
    
    NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
    [body setStringValue:_message.text];
    
    NSXMLElement *messageElement = [NSXMLElement elementWithName:@"message"];
    [messageElement addAttributeWithName:@"type" stringValue:@"chat"];
    [messageElement addAttributeWithName:@"to" stringValue:_user.jidStr];
    [messageElement addChild:body];
    
    [[self appDelegate].xmppStream sendElement:messageElement];

    XMPPMessage *message = [XMPPMessage messageFromElement:messageElement];
    [self addMessage:message];
    
    _message.text = @"";
    return YES;
}

- (IBAction)sendImage:(id)sender
{
    // Preset an action sheet which enables the user to take a new picture or select and existing one.
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel"  destructiveButtonTitle:nil otherButtonTitles:@"Take Photo", @"Choose Existing", nil];
    
    // Show the action sheet
    [sheet showFromBarButtonItem:sender animated:YES];
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

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    // Don't block the UI when writing the image to documents
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // We only handle a still image
        UIImage *imageToSave = [ProfileController scaleImage:(UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage]
                                                toResolution:128];
        // Save the new image to the documents directory
        NSData *pngData = UIImageJPEGRepresentation(imageToSave, .5);
        
        NSString *imgStr = [pngData base64EncodedStringWithOptions:kNilOptions];
        
        NSXMLElement *ImgAttachement = [NSXMLElement elementWithName:@"attachement"];
        [ImgAttachement setStringValue:imgStr];
        
        NSXMLElement *messageElement = [NSXMLElement elementWithName:@"message"];
        [messageElement addAttributeWithName:@"type" stringValue:@"chat"];
        [messageElement addAttributeWithName:@"to" stringValue:_user.jidStr];
        [messageElement addChild:ImgAttachement];
        
        [[self appDelegate].xmppStream sendElement:messageElement];
        
        XMPPMessage *message = [XMPPMessage messageFromElement:messageElement];
        [self addMessage:message];
    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    XMPPMessage *message = [_messages objectAtIndex:indexPath.row];
    BOOL fromMe = [message.toStr isEqual:_user.jidStr];
    UITableViewCell *cell;
    
    if ([message isChatMessageWithBody]) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"MessageCell" forIndexPath:indexPath];
        MessageView *messageView = (MessageView *)[cell viewWithTag:MESSAGE_VIEW_TAG];
        [messageView setMessage:message fromMe:fromMe];
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:@"ImageCell" forIndexPath:indexPath];
        ImageView *imageView = (ImageView *)[cell viewWithTag:IMAGE_VIEW_TAG];
        [imageView setMessage:message fromMe:fromMe];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Dynamically compute the label size based on cell type (image, image progress, or text message)
    XMPPMessage *message = [_messages objectAtIndex:indexPath.row];
    if ([message isChatMessageWithBody]) {
        return [MessageView viewHeightForMessage:message];
    } else {
        return [ImageView viewHeightForMessage:message];
    }
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
