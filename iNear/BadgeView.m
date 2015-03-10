//
//  BadgeView.m
//  iNear
//
//  Created by Sergey Seitov on 11.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import "BadgeView.h"

@interface BadgeView ()

@property (strong, nonatomic) UILabel* number;

@end

@implementation BadgeView

- (void)awakeFromNib
{
    self.image = [UIImage imageNamed:@"badge"];
    _number = [[UILabel alloc] initWithFrame:self.bounds];
    _number.textColor = [UIColor whiteColor];
    _number.textAlignment = NSTextAlignmentCenter;
    _number.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:16];
    _number.backgroundColor = [UIColor clearColor];
    [self addSubview:_number];
    self.hidden = YES;
}

- (void)layoutSubviews
{
    _number.frame = self.bounds;
}

- (void)setCount:(int)count
{
    if (count <= 0) {
        _number.text = @"";
        self.hidden = YES;
    } else {
        _number.text = [NSString stringWithFormat:@"%d", count];
        self.hidden = NO;
    }
}

@end
