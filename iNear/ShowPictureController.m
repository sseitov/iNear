//
//  ShowPictureController.m
//  iNear
//
//  Created by Sergey Seitov on 11.04.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "ShowPictureController.h"

@interface ShowPictureController ()

@property (weak, nonatomic) IBOutlet UIImageView *picture;

@end

@implementation ShowPictureController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Image";
    _picture.image = [UIImage imageWithData:_message.attachment];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:YES animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:NO animated:YES];
}

@end
