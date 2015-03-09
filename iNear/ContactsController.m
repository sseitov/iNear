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

#import "XMPPFramework.h"

#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

@interface ContactsController () {
    NSFetchedResultsController *fetchedResultsController;
}

- (IBAction)addContact:(id)sender;

@end

@implementation ContactsController

- (AppDelegate *)appDelegate
{
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSubscribe:) name:XmppSubscribeNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (![self.appDelegate isXMPPConnected]) {
        [self.appDelegate connectXmppFromViewController:self result:^(BOOL result) {
            if (!result) {
                [self performSegueWithIdentifier:@"MyProfile" sender:self];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:XmppConnectedNotification object:nil];
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
        NSManagedObjectContext *moc = [[self appDelegate] managedObjectContext_roster];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"XMPPUserCoreDataStorageObject"
                                                  inManagedObjectContext:moc];
        
        NSSortDescriptor *sd1 = [[NSSortDescriptor alloc] initWithKey:@"sectionNum" ascending:YES];
        NSSortDescriptor *sd2 = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
        
        NSArray *sortDescriptors = @[sd1, sd2];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        [fetchRequest setSortDescriptors:sortDescriptors];
        [fetchRequest setFetchBatchSize:10];
        
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

    UILabel *displayName = (UILabel*)[cell.contentView viewWithTag:1];
    displayName.text = user.displayName;
    
    UILabel *shortName = (UILabel*)[cell.contentView viewWithTag:2];
    shortName.text = @"";
    
    UIImageView *icon = (UIImageView*)[cell.contentView viewWithTag:3];
    if (user.photo) {
        icon.image = user.photo;
    } else {
        NSData *photoData = [[[self appDelegate] xmppvCardAvatarModule] photoDataForJID:user.jid];
        if (photoData != nil) {
            icon.image = [UIImage imageWithData:photoData];
        } else {
            icon.image = nil;
            [icon.layer setBackgroundColor:[ProfileController MD5color:user.displayName].CGColor];
            shortName.text = [[displayName.text substringWithRange:NSMakeRange(0, 2)] uppercaseString];
        }
    }
    icon.layer.cornerRadius = icon.frame.size.width/2;
    icon.clipsToBounds = YES;
    
    return cell;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Chat"]) {
        UITableViewCell* cell = sender;
        NSIndexPath* indexPath = [self.tableView indexPathForCell:cell];
        UINavigationController *vc = [segue destinationViewController];
        ChatController *chat = (ChatController*)vc.topViewController;
        chat.user = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    }
}

#pragma mark - XMPP notifications

- (void)handleSubscribe:(NSNotification*)note
{
    XMPPPresence* presence = note.object;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"User subscribe request"
                                                                             message:[presence from].user
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *accept = [UIAlertAction actionWithTitle:@"Accept"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action) {
                                                       [self.appDelegate.xmppRoster acceptPresenceSubscriptionRequestFrom:[presence from] andAddToRoster:YES];
                                                   }];
    [alertController addAction:accept];
    UIAlertAction *reject = [UIAlertAction actionWithTitle:@"Reject"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction *action) {
                                                       [self.appDelegate.xmppRoster rejectPresenceSubscriptionRequestFrom:[presence from]];
                                                   }];
    [alertController addAction:reject];

    if(IS_PAD) {
        UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:alertController];
        [popover presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    UITextField* textField = [alertView textFieldAtIndex:0];
    XMPPJID *jid = [XMPPJID jidWithString:[NSString stringWithFormat:@"%@", textField.text]];
    [self.appDelegate.xmppRoster addUser:jid withNickname:textField.text];
}

- (IBAction)addContact:(id)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Add user"
                                                    message:@"Input user jid:"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel" otherButtonTitles:@"Ok", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

@end
