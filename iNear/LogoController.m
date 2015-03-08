//
//  LogoController.m
//  iNear
//
//  Created by Sergey Seitov on 08.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "LogoController.h"

@interface LogoController ()

@property (weak, nonatomic) IBOutlet UIImageView *logo;

@end

@implementation LogoController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _logo.layer.cornerRadius = _logo.frame.size.width/3;
    _logo.clipsToBounds = YES;
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
