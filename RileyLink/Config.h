//
//  Config.h
//  RileyLink
//
//  Created by Pete Schwamb on 6/27/15.
//  Copyright (c) 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Config : NSObject {
  NSUserDefaults *_defaults;
}

+ (nonnull Config *)sharedInstance;

@property (nonatomic, nullable, strong) NSString *nightscoutURL;
@property (nonatomic, nullable, strong) NSString *nightscoutAPISecret;
@property (nonatomic, nullable, strong) NSString *pumpID;

@property (nonatomic, readonly) BOOL hasValidConfiguration;

@end
