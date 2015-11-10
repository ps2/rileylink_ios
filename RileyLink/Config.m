//
//  Config.m
//  RileyLink
//
//  Created by Pete Schwamb on 6/27/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import "Config.h"

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

- (BOOL) hasValidConfiguration {
  return self.nightscoutURL != NULL && ![self.nightscoutURL isEqualToString:@""];
}

- (BOOL) alertsEnable {
  return [_defaults boolForKey:@"alertsEnable"];
}

- (void) setAlertsEnable:(BOOL)alertsEnabled {
  [_defaults setBool:alertsEnabled forKey:@"alertsEnable"];
  [[NSNotificationCenter defaultCenter] postNotificationName:CONFIG_EVENT_ALERTS_TOGGLED object:self userInfo:nil];
}


@end
