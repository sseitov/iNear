//
//  BadgeView.h
//  iNear
//
//  Created by Sergey Seitov on 11.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BadgeView : UIImageView

- (id)initWithTarget:(id)target action:(SEL)action;
- (void)setCount:(NSUInteger)count;
- (void)incrementCount;

@end
