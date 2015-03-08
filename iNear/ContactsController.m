//
//  ContactsController.m
//  iNear
//
//  Created by Sergey Seitov on 06.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ContactsController.h"

@interface ContactsController ()

@end

@implementation ContactsController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)dealloc
{
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Contact" forIndexPath:indexPath];
/*
    UILabel *displayName = (UILabel*)[cell.contentView viewWithTag:1];

    UILabel *shortName = (UILabel*)[cell.contentView viewWithTag:2];
    NSRange r = {0, 2};
    shortName.text = [[displayName.text substringWithRange:r] uppercaseString];

    UIImageView *icon = (UIImageView*)[cell.contentView viewWithTag:3];
    [icon.layer setBackgroundColor:MD5color(peer.displayName).CGColor];
    icon.layer.cornerRadius = icon.frame.size.width/2;
    icon.clipsToBounds = YES;
*/
    return cell;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
/*    if ([[segue identifier] isEqualToString:@"CreateChat"]) {
        UITableViewCell* cell = sender;
        NSIndexPath* indexPath = [self.tableView indexPathForCell:cell];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        [cell setSelected:NO animated:YES];
    }*/
}

@end
