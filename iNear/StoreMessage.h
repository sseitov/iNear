//
//  StoreMessage.h
//  iNear
//
//  Created by Sergey Seitov on 11.03.15.
//  Copyright (c) 2015 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface StoreMessage : NSManagedObject

@property (nonatomic, retain) NSString * displayName;
@property (nonatomic, retain) NSString * message;
@property (nonatomic, retain) NSData * attachment;
@property (nonatomic, retain) NSNumber * isNew;

@end
