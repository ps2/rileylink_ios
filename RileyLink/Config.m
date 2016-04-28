//
//  Config.m
//  RileyLink
//
//  Created by Pete Schwamb on 6/27/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

@import CoreData;
#import "Config.h"
#import "RileyLinkRecord.h"
#import "RileyLink-Swift.h"
#import <UIKit/UIKit.h>

@implementation Config

+ (Config *)sharedInstance
{
    // structure used to test whether the block has completed or not
    static dispatch_once_t p = 0;
    
    // initialize sharedObject as nil (first call only)
    __strong static Config * _sharedObject = nil;
    
    // executes a block object once and only once for the lifetime of an application
    dispatch_once(&p, ^{
        _sharedObject = [[self alloc] init];
    });
    
    // returns the same object each time
    return _sharedObject;
}

- (instancetype)init {
    if (self = [super init]) {
        _defaults = [NSUserDefaults standardUserDefaults];
    }
    
    return self;
}


- (void) setNightscoutURL:(NSString *)nightscoutURL {
    [_defaults setValue:nightscoutURL forKey:@"nightscoutURL"];
}

- (NSString*) nightscoutURL {
    return [_defaults stringForKey:@"nightscoutURL"];
}

- (void) setNightscoutAPISecret:(NSString *)nightscoutAPISecret {
    [_defaults setValue:nightscoutAPISecret forKey:@"nightscoutAPISecret"];
}

- (NSString*) nightscoutAPISecret {
    return [_defaults stringForKey:@"nightscoutAPISecret"];
}

- (void) setPumpID:(NSString *)pumpID {
    [_defaults setValue:pumpID forKey:@"pumpID"];
}

- (NSString*) pumpID {
    return [_defaults stringForKey:@"pumpID"];
}

- (void) setPumpTimeZone:(NSTimeZone *)pumpTimeZone {
    
    if (pumpTimeZone) {
        NSNumber *rawValue = [NSNumber numberWithInteger:pumpTimeZone.secondsFromGMT];
        [_defaults setObject:rawValue forKey:@"pumpTimeZone"];
    } else {
        [_defaults removeObjectForKey:@"pumpTimeZone"];
    }
}

- (NSTimeZone*) pumpTimeZone {
    NSNumber *offset = (NSNumber*)[_defaults objectForKey:@"pumpTimeZone"];
    if (offset) {
        return [NSTimeZone timeZoneForSecondsFromGMT: offset.integerValue];
    } else {
        return nil;
    }
}

- (BOOL) hasValidConfiguration {
    return self.nightscoutURL != NULL && ![self.nightscoutURL isEqualToString:@""];
}

- (NSSet*) autoConnectIds {
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *managedObjectContext = appDelegate.managedObjectContext;
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"RileyLinkRecord"
                                              inManagedObjectContext:managedObjectContext];
    fetchRequest.entity = entity;
    NSError *error;
    NSMutableSet *autoConnectIds = [[NSMutableSet alloc] init];
    NSArray *fetchedObjects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    for (RileyLinkRecord *record in fetchedObjects) {
        NSLog(@"Loaded: %@ from db", record.name);
        if ((record.autoConnect).boolValue) {
            [autoConnectIds addObject:record.peripheralId];
        }
    }
    return autoConnectIds;
}

- (void) setAutoConnectIds:(NSSet *)autoConnectIds {
    
}



@end
