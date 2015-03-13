//
//  ContactsController.m
//  iNear
//
//  Created by Sergey Seitov on 06.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ContactsController.h"
#import "AppDelegate.h"
#import "ProfileController.h"
#import "ChatController.h"
#import "BadgeView.h"
#import "IconView.h"
#import "AddUserController.h"
#import "Storage.h"

#import "XMPPFramework.h"

@interface ContactsController () <AddUserControllerDelegate> {
    NSFetchedResultsController *fetchedResultsController;
}

- (IBAction)addContact:(id)sender;

@end

@implementation ContactsController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSubscribe:) name:XmppSubscribeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMessage:) name:XmppMessageNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (![[AppDelegate sharedInstance] isXMPPConnected]) {
        [[AppDelegate sharedInstance] connectXmppFromViewController:self result:^(BOOL result) {
            if (!result) {
                [self performSegueWithIdentifier:@"MyProfile" sender:self];
            }
        }];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSFetchedResultsController
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSFetchedResultsController *)fetchedResultsController
{
    if (fetchedResultsController == nil)
    {
        NSManagedObjectContext *moc = [[AppDelegate sharedInstance] managedObjectContext_roster];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
                                                  inManagedObjectContext:moc];
        
        NSSortDescriptor *sd1 = [[NSSortDescriptor alloc] initWithKey:@"sectionNum" ascending:YES];
        NSSortDescriptor *sd2 = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
        
        NSArray *sortDescriptors = @[sd1, sd2];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        [fetchRequest setSortDescriptors:sortDescriptors];
        [fetchRequest setFetchBatchSize:10];
        [fetchRequest setPropertiesToFetch:@[]];
        
        fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                       managedObjectContext:moc
                                                                         sectionNameKeyPath:@"sectionNum"
                                                                                  cacheName:nil];
        [fetchedResultsController setDelegate:self];
        
        
        NSError *error = nil;
        if (![fetchedResultsController performFetch:&error])
        {
            NSLog(@"Error performing fetch: %@", error);
        }
        
    }
    
    return fetchedResultsController;
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [[self tableView] reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[[self fetchedResultsController] sections] count];
}

- (NSString *)tableView:(UITableView *)sender titleForHeaderInSection:(NSInteger)sectionIndex
{
    NSArray *sections = [[self fetchedResultsController] sections];
    
    if (sectionIndex < [sections count])
    {
        id <NSFetchedResultsSectionInfo> sectionInfo = sections[sectionIndex];
        
        int section = [sectionInfo.name intValue];
        switch (section)
        {
            case 0  : return @"Available";
            case 1  : return @"Away";
            default : return @"Offline";
        }
    }
    
    return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
    NSArray *sections = [[self fetchedResultsController] sections];
    
    if (sectionIndex < sections.count)
    {
        id <NSFetchedResultsSectionInfo> sectionInfo = sections[sectionIndex];
        return sectionInfo.numberOfObjects;
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Contact" forIndexPath:indexPath];
    
    XMPPUserCoreDataStorageObject *user = [[self fetchedResultsController] objectAtIndexPath:indexPath];

    UILabel *name = (UILabel*)[cell.contentView viewWithTag:1];
    name.text = [[AppDelegate sharedInstance] nickNameForUser:user];
    
    IconView* icon = (IconView*)[cell.contentView viewWithTag:2];
    [icon setIconForUser:user];
    
    BadgeView* badge = (BadgeView*)[cell.contentView viewWithTag:3];
    [badge setCount:[[Storage sharedInstance] newMessagesCountForUser:user.displayName]];
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        XMPPUserCoreDataStorageObject *user = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        [[AppDelegate sharedInstance].xmppRoster removeUser:user.jid];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Chat"]) {
        UITableViewCell* cell = sender;
        NSIndexPath* indexPath = [self.tableView indexPathForCell:cell];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        UINavigationController *vc = [segue destinationViewController];
        ChatController *chat = (ChatController*)vc.topViewController;
        chat.user = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    } else if ([[segue identifier] isEqualToString:@"AddUser"]) {
        UINavigationController *vc = [segue destinationViewController];
        AddUserController* next = (AddUserController*)vc.topViewController;
        next.delegate = self;
        if ([AppDelegate isPad]) {
            next.preferredContentSize = CGSizeMake(320, 120);
        }
    }
}

- (void)addUserController:(AddUserController*)controller addUser:(NSString*)user
{
    if (user.length > 0) {
        XMPPJID *jid = [XMPPJID jidWithString:[NSString stringWithFormat:@"%@", user]];
        [[AppDelegate sharedInstance].xmppRoster addUser:jid withNickname:[NSString stringWithFormat:@"%@", user]];
    }
    [controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - XMPP notifications

- (void)handleMessage:(NSNotification*)note
{
    [self.tableView reloadData];
}

- (void)handleSubscribe:(NSNotification*)note
{
    XMPPPresence* presence = note.object;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"User subscribe request"
                                                                             message:[presence from].user
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *accept = [UIAlertAction actionWithTitle:@"Accept"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action) {
                                                       [[AppDelegate sharedInstance].xmppRoster acceptPresenceSubscriptionRequestFrom:[presence from] andAddToRoster:YES];
                                                   }];
    [alertController addAction:accept];
    UIAlertAction *reject = [UIAlertAction actionWithTitle:@"Reject"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action) {
                                                       [[AppDelegate sharedInstance].xmppRoster rejectPresenceSubscriptionRequestFrom:[presence from]];
                                                   }];
    [alertController addAction:reject];

    if([AppDelegate isPad]) {
        UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:alertController];
        [popover presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (IBAction)addContact:(id)sender
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:@"Add user with account:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeEmailAddress;
        textField.placeholder = @"user@jabber-server.com";
        textField.textAlignment = NSTextAlignmentCenter;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Ok"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action)
                               {
                                   UITextField *user = alert.textFields.firstObject;
                                   XMPPJID *jid = [XMPPJID jidWithString:[NSString stringWithFormat:@"%@", user.text]];
                                   [[AppDelegate sharedInstance].xmppRoster addUser:jid withNickname:[NSString stringWithFormat:@"%@", user.text]];
                               }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {}];
    [alert addAction:cancelAction];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
