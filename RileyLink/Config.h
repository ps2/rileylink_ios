//
//  Config.h
//  RileyLink
//
//  Created by Pete Schwamb on 6/27/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>

#define CONFIG_EVENT_ALERTS_TOGGLED @"CONFIG_EVENT_ALERTS_TOGGLED"

@interface Config : NSObject {
  NSUserDefaults *_defaults;
}

+ (Config *)sharedInstance;

@property (nonatomic, strong) NSString *nightscoutURL;
@property (nonatomic, strong) NSString *nightscoutAPISecret;
@property (nonatomic, strong) NSString *pumpID;
@property (nonatomic, assign) BOOL alertsEnable;

@property (nonatomic, readonly) BOOL hasValidConfiguration;

@end
