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
#import "Storage.h"

@interface ChatController () <UITextFieldDelegate, UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIContentContainer>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *messageButton;
@property (weak, nonatomic) IBOutlet UITextField *message;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

- (IBAction)sendImage:(id)sender;
- (IBAction)clearChat:(id)sender;

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

    self.title = @"Chat";
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:_message action:@selector(resignFirstResponder)];
    [self.view addGestureRecognizer:tap];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    _messageButton.width = self.tableView.frame.size.width - 60;
}

- (void)scrollToBottom
{
    if (self.tableView.contentSize.height > self.tableView.frame.size.height)
    {
        CGPoint offset = CGPointMake(0, self.tableView.contentSize.height - self.tableView.frame.size.height + 44);
        [self.tableView setContentOffset:offset animated:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Listen for will show/hide notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    [self.tableView reloadData];
    [self scrollToBottom];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Stop listening for keyboard notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [_message resignFirstResponder];
    [self.navigationController.toolbar setFrame:CGRectMake(self.navigationController.toolbar.frame.origin.x,
                                                           size.height - self.navigationController.toolbar.frame.size.height,
                                                           self.navigationController.toolbar.frame.size.width,
                                                           self.navigationController.toolbar.frame.size.height)];
}

#pragma mark - Toolbar animation helpers

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
    
    [self.navigationController.toolbar setFrame:CGRectMake(self.navigationController.toolbar.frame.origin.x,
                                                           self.navigationController.toolbar.frame.origin.y + (keyboardFrame.size.height * (up ? -1 : 1)),
                                                           self.navigationController.toolbar.frame.size.width,
                                                           self.navigationController.toolbar.frame.size.height)];
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
    [[Storage sharedInstance] addMessage:message toChat:_user.displayName fromMe:YES];
    
    _message.text = @"";
    return YES;
}

- (IBAction)sendImage:(id)sender
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel"  destructiveButtonTitle:nil otherButtonTitles:@"Take Photo", @"Choose Existing", nil];
    [sheet showFromBarButtonItem:sender animated:YES];
}

- (IBAction)clearChat:(id)sender
{
    [[Storage sharedInstance] clearChat:_user.displayName];
    [[NSNotificationCenter defaultCenter] postNotificationName:XmppMessageNotification object:nil];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 2) {
        return;
    }
    
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    
    if (imagePicker) {
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
        [[Storage sharedInstance] addMessage:message toChat:_user.displayName fromMe:YES];
    });
}

#pragma mark - NSFetchedResultsController

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController == nil)
    {
        NSManagedObjectContext *moc = [[Storage sharedInstance] managedObjectContext];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        fetchRequest.entity = [NSEntityDescription entityForName:@"StoreMessage" inManagedObjectContext:moc];
        fetchRequest.sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES]];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"displayName == %@", _user.displayName];
        fetchRequest.fetchBatchSize = 50;
//        fetchRequest.propertiesToFetch = @[@"message", @"attachment", @"isNew", @"fromMe"];
        
        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                       managedObjectContext:moc
                                                                         sectionNameKeyPath:nil
                                                                                  cacheName:nil];
        _fetchedResultsController.delegate = self;
        
        NSError *error = nil;
        if (![_fetchedResultsController performFetch:&error])
        {
            NSLog(@"Error performing fetch: %@", error);
        }
        
    }
    
    return _fetchedResultsController;
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView reloadData];
    [self scrollToBottom];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray *sections = [self.fetchedResultsController sections];
    if (section < sections.count)
    {
        id <NSFetchedResultsSectionInfo> sectionInfo = sections[section];
        return sectionInfo.numberOfObjects;
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    StoreMessage *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    UITableViewCell *cell;
    
    if ([message.isNew boolValue]) {
        message.isNew = [NSNumber numberWithBool:NO];
        [[Storage sharedInstance] saveContext];
        [[NSNotificationCenter defaultCenter] postNotificationName:XmppMessageNotification object:nil];
    }
    if (message.message != nil) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"MessageCell" forIndexPath:indexPath];
        MessageView *messageView = (MessageView *)[cell viewWithTag:MESSAGE_VIEW_TAG];
        [messageView setMessage:message fromMe:[message.fromMe boolValue]];
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:@"ImageCell" forIndexPath:indexPath];
        ImageView *imageView = (ImageView *)[cell viewWithTag:IMAGE_VIEW_TAG];
        [imageView setMessage:message fromMe:[message.fromMe boolValue]];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Dynamically compute the label size based on cell type (image, image progress, or text message)
    StoreMessage *message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (message.message != nil) {
        return [MessageView viewHeightForMessage:message];
    } else {
        return [ImageView viewHeightForMessage:message];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
