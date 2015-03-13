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
@property (nonatomic) NSUInteger foreignCount;
@property (nonatomic) BOOL inverse;

@end

@implementation BadgeView

- (void)awakeFromNib
{
    self.layer.cornerRadius = self.frame.size.width/2;
    UIColor *c = [UIColor colorWithRed:0 green:112./256. blue:163./256. alpha:1.];
    [self.layer setBackgroundColor:c.CGColor];

    _number = [[UILabel alloc] initWithFrame:self.bounds];
    _number.textColor = [UIColor whiteColor];
    _number.textAlignment = NSTextAlignmentCenter;
    _number.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:16];
    _number.backgroundColor = [UIColor clearColor];
    [self addSubview:_number];
    self.hidden = YES;
}

- (id)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithFrame:CGRectMake(0, 0, 24, 24)];
    if (self) {
        self.image = [UIImage imageNamed:@"badge"];
        _number = [[UILabel alloc] initWithFrame:self.bounds];
        _number.textColor = [UIColor colorWithRed:28./256. green:79./256. blue:130./256. alpha:1.];
        _number.textAlignment = NSTextAlignmentCenter;
        _number.font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:16];
        _number.backgroundColor = [UIColor clearColor];
        [self addSubview:_number];
        self.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:target action:action];
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)layoutSubviews
{
    _number.frame = self.bounds;
}

- (void)setCount:(NSUInteger)count
{
    if (count <= 0) {
        _number.text = @"";
        self.hidden = YES;
    } else {
        _number.text = [[NSNumber numberWithInteger:count] stringValue];
        self.hidden = NO;
    }
}

- (void)timerFire:(NSTimer *)timer
{
    if (_inverse) {
        self.number.textColor = [UIColor whiteColor];
        self.layer.backgroundColor = [UIColor colorWithRed:28./256. green:79./256. blue:130./256. alpha:1.].CGColor;
    } else {
        self.layer.backgroundColor = [UIColor whiteColor].CGColor;
        self.number.textColor = [UIColor colorWithRed:28./256. green:79./256. blue:130./256. alpha:1.];
    }
    _inverse = !_inverse;
}

- (void)incrementCount
{
    _foreignCount++;
    [self setCount:_foreignCount];
    if (_foreignCount == 1) {
        self.image = nil;
        self.layer.cornerRadius = self.frame.size.width/2;
        [self.layer setBackgroundColor:[UIColor whiteColor].CGColor];
        _inverse = YES;
        [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(timerFire:) userInfo:nil repeats:YES];
    }
}

@end
