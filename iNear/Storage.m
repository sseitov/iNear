//
//  Storage.m
//  WD Content
//
//  Created by Sergey Seitov on 09.01.14.
//  Copyright (c) 2014 Sergey Seitov. All rights reserved.
//

#import "Storage.h"

@implementation Storage

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

+ (Storage*)sharedInstance
{
	static dispatch_once_t pred;
	static Storage *sharedInstance = nil;
	
	dispatch_once(&pred, ^{ sharedInstance = [[self alloc] init]; });
	return sharedInstance;
}

- (NSManagedObjectModel*)managedObjectModel
{
	if (_managedObjectModel)
		return _managedObjectModel;
	
	NSBundle *bundle = [NSBundle mainBundle];
	NSString *modelPath = [bundle pathForResource:@"MessageModel" ofType:@"momd"];
	_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:modelPath]];
	
	return _managedObjectModel;
}

- (NSPersistentStoreCoordinator*)persistentStoreCoordinator
{
	if (_persistentStoreCoordinator)
		return _persistentStoreCoordinator;
	
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    NSURL* documentDirectory =  [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];

    NSURL *storeURL = [documentDirectory URLByAppendingPathComponent:@"MessageModel.sqlite"];
	
	// Define the Core Data version migration options
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
							 nil];
	
	// Attempt to load the persistent store
	NSError *error = nil;
	if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
												   configuration:nil
															 URL:storeURL
														 options:options
														   error:&error]) {
		NSLog(@"Remove previouse store");
		[[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
		if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
													   configuration:nil
																 URL:storeURL
															 options:options
															   error:&error]) {
            [self displayValidationError:error];
			abort();
		}
	}
	
	return _persistentStoreCoordinator;
}

- (NSManagedObjectContext*)managedObjectContext
{
	if (_managedObjectContext)
		return _managedObjectContext;
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    return _managedObjectContext;
}

// Core Data error handling.
// This is one a generic method to handle and display Core Data validation errors to the user.
// https://developer.apple.com/library/mac/#documentation/Cocoa/Reference/CoreDataFramework/Miscellaneous/CoreData_Constants/Reference/reference.html
- (void)displayValidationError:(NSError *)anError {
    if (anError && [[anError domain] isEqualToString:@"NSCocoaErrorDomain"]) {
        NSArray *errors = nil;
        
        // if multiple errors
        if ([anError code] == NSValidationMultipleErrorsError) {
            errors = [[anError userInfo] objectForKey:NSDetailedErrorsKey];
        } else {
            errors = [NSArray arrayWithObject:anError];
        }
        
        if (errors && [errors count] > 0) {
            NSString *messages = @"Reason(s):\n";
            
            for (NSError * error in errors) {
                NSString *entityName = [[[[error userInfo] objectForKey:@"NSValidationErrorObject"] entity] name];
                NSString *attributeName = [[error userInfo] objectForKey:@"NSValidationErrorKey"];
                NSString *msg;
                switch ([error code]) {
                    case NSManagedObjectValidationError:
                        msg = @"Generic validation error.";
                        break;
                    case NSValidationMissingMandatoryPropertyError:
                        msg = [NSString stringWithFormat:@"The attribute '%@' mustn't be empty.", attributeName];
                        break;
                    case NSValidationRelationshipLacksMinimumCountError:
                        msg = [NSString stringWithFormat:@"The relationship '%@' doesn't have enough entries.", attributeName];
                        break;
                    case NSValidationRelationshipExceedsMaximumCountError:
                        msg = [NSString stringWithFormat:@"The relationship '%@' has too many entries.", attributeName];
                        break;
                    case NSValidationRelationshipDeniedDeleteError:
                        msg = [NSString stringWithFormat:@"To delete, the relationship '%@' must be empty.", attributeName];
                        break;
                    case NSValidationNumberTooLargeError:
                        msg = [NSString stringWithFormat:@"The number of the attribute '%@' is too large.", attributeName];
                        break;
                    case NSValidationNumberTooSmallError:
                        msg = [NSString stringWithFormat:@"The number of the attribute '%@' is too small.", attributeName];
                        break;
                    case NSValidationDateTooLateError:
                        msg = [NSString stringWithFormat:@"The date of the attribute '%@' is too late.", attributeName];
                        break;
                    case NSValidationDateTooSoonError:
                        msg = [NSString stringWithFormat:@"The date of the attribute '%@' is too soon.", attributeName];
                        break;
                    case NSValidationInvalidDateError:
                        msg = [NSString stringWithFormat:@"The date of the attribute '%@' is invalid.", attributeName];
                        break;
                    case NSValidationStringTooLongError:
                        msg = [NSString stringWithFormat:@"The text of the attribute '%@' is too long.", attributeName];
                        break;
                    case NSValidationStringTooShortError:
                        msg = [NSString stringWithFormat:@"The text of the attribute '%@' is too short.", attributeName];
                        break;
                    case NSValidationStringPatternMatchingError:
                        msg = [NSString stringWithFormat:@"The text of the attribute '%@' doesn't match the required pattern.", attributeName];
                        break;
                    default:
                        msg = [NSString stringWithFormat:@"Unknown error (code %d).", (int)[error code]];
                        break;
                }
                
                messages = [messages stringByAppendingFormat:@"%@%@%@\n", (entityName?:@""),(entityName?@": ":@""),msg];
            }
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Validation Error"
                                                            message:messages
                                                           delegate:nil
                                                  cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alert show];
        }
    }
}

#pragma mark - Public methods

- (void)saveContext
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            [self displayValidationError:error];
        }
    }
}

- (void)addMessage:(XMPPMessage*)message toChat:(NSString*)chatName fromMe:(BOOL)fromMe
{
    StoreMessage *newMessage = (StoreMessage *)[NSEntityDescription insertNewObjectForEntityForName:@"StoreMessage"
                                                                             inManagedObjectContext: _managedObjectContext];
    newMessage.date = [NSDate date];
    newMessage.fromMe = [NSNumber numberWithBool:fromMe];
    if (fromMe) {
        newMessage.isNew = [NSNumber numberWithBool:NO];
    } else {
        newMessage.isNew = [NSNumber numberWithBool:YES];
    }
    newMessage.displayName = chatName;
    if ([message isChatMessageWithBody]) {
        newMessage.message = message.body;
    } else {
        NSString* imageStr = [[message elementForName:@"attachement"] stringValue];
        newMessage.attachment = [[NSData alloc] initWithBase64EncodedString:imageStr options:kNilOptions];
    }
    [self saveContext];
}

- (NSUInteger)newMessagesCountForUser:(NSString*)displayName
{
    if (!_managedObjectContext) {
        _managedObjectContext = [self managedObjectContext];
    }
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"StoreMessage"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"displayName == %@ AND isNew == YES", displayName];
    
    return [_managedObjectContext countForFetchRequest:fetchRequest error:nil];
}

- (NSUInteger)allMessagesCountForUser:(NSString*)displayName
{
    if (!_managedObjectContext) {
        _managedObjectContext = [self managedObjectContext];
    }
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"StoreMessage"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"displayName == %@", displayName];
    
    return [_managedObjectContext countForFetchRequest:fetchRequest error:nil];
}

- (void)clearChat:(NSString*)chatName
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"StoreMessage"];
    request.predicate = [NSPredicate predicateWithFormat:@"displayName == %@", chatName];
    NSError *error = nil;
    NSArray *results = [_managedObjectContext executeFetchRequest:request error:nil];
    if (error) {
        [self displayValidationError:error];
    } else {
        for (StoreMessage* message in results) {
            [_managedObjectContext deleteObject:message];
        }
        [self saveContext];
    }
}

#pragma mark - Profile properties

+ (NSString*)myJid
{
    NSDictionary *profile = [[NSUserDefaults standardUserDefaults] objectForKey:@"profile"];
    if (profile && [profile objectForKey:@"account"]) {
        return [profile objectForKey:@"account"];
    } else {
        return @"";
    }
}

+ (NSString*)myPassword
{
    NSDictionary *profile = [[NSUserDefaults standardUserDefaults] objectForKey:@"profile"];
    if (profile && [profile objectForKey:@"password"]) {
        return [profile objectForKey:@"password"];
    } else {
        return @"";
    }
}

+ (NSString*)myNick
{
    NSDictionary *profile = [[NSUserDefaults standardUserDefaults] objectForKey:@"profile"];
    if (profile && [profile objectForKey:@"displayName"]) {
        return [profile objectForKey:@"displayName"];
    } else {
        return @"";
    }
}

+ (NSData*)myImage
{
    NSDictionary *profile = [[NSUserDefaults standardUserDefaults] objectForKey:@"profile"];
    if (profile && [profile objectForKey:@"image"]) {
        return [profile objectForKey:@"image"];
    } else {
        return nil;
    }
}

+ (void)setMyJid:(NSString*)jid
{
    NSDictionary *old = [[NSUserDefaults standardUserDefaults] objectForKey:@"profile"];
    NSMutableDictionary *new = (old == nil) ? [NSMutableDictionary dictionary] : [NSMutableDictionary dictionaryWithDictionary:old];
    [new setObject:jid forKey:@"account"];
    [[NSUserDefaults standardUserDefaults] setObject:new forKey:@"profile"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)setMyPassword:(NSString*)pwd
{
    NSDictionary *old = [[NSUserDefaults standardUserDefaults] objectForKey:@"profile"];
    NSMutableDictionary *new = (old == nil) ? [NSMutableDictionary dictionary] : [NSMutableDictionary dictionaryWithDictionary:old];
    [new setObject:pwd forKey:@"password"];
    [[NSUserDefaults standardUserDefaults] setObject:new forKey:@"profile"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)setMyNick:(NSString*)nick
{
    NSDictionary *old = [[NSUserDefaults standardUserDefaults] objectForKey:@"profile"];
    NSMutableDictionary *new = (old == nil) ? [NSMutableDictionary dictionary] : [NSMutableDictionary dictionaryWithDictionary:old];
    [new setObject:nick forKey:@"displayName"];
    [[NSUserDefaults standardUserDefaults] setObject:new forKey:@"profile"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)setMyImage:(NSData*)image
{
    NSDictionary *old = [[NSUserDefaults standardUserDefaults] objectForKey:@"profile"];
    NSMutableDictionary *new = (old == nil) ? [NSMutableDictionary dictionary] : [NSMutableDictionary dictionaryWithDictionary:old];
    [new setObject:image forKey:@"image"];
    [[NSUserDefaults standardUserDefaults] setObject:new forKey:@"profile"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
