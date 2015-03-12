//
//  Storage.h
//  WD Content
//
//  Created by Sergey Seitov on 09.01.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "StoreMessage.h"
#import "XMPPFramework.h"

@interface Storage : NSObject {
}

@property (nonatomic, readonly, retain) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readonly, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly, retain) NSPersistentStoreCoordinator *persistentStoreCoordinator;

+ (Storage*)sharedInstance;

- (NSManagedObjectContext*)managedObjectContext;

- (void)saveContext;

- (void)addMessage:(XMPPMessage*)message toChat:(NSString*)chatName fromMe:(BOOL)fromMe;
- (NSUInteger)newMessagesCountForUser:(NSString*)displayName;
- (NSUInteger)allMessagesCountForUser:(NSString*)displayName;
- (void)clearChat:(NSString*)chatName;


+ (NSString*)myJid;
+ (NSString*)myPassword;
+ (NSString*)myNick;
+ (NSData*)myImage;

+ (void)setMyJid:(NSString*)jid;
+ (void)setMyPassword:(NSString*)pwd;
+ (void)setMyNick:(NSString*)nick;
+ (void)setMyImage:(NSData*)image;

@end
