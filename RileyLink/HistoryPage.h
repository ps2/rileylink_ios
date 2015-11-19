//
//  HistoryPage.h
//  RileyLink
//
//  Created by Pete Schwamb on 11/18/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HistoryPage : NSObject

@property (nonatomic, nonnull, readonly, strong) NSData *data;
@property (nonatomic, nullable, readonly, strong) NSString *pumpModel;
@property (nonatomic, nullable, readonly, strong) NSDictionary *registry;

- (nonnull instancetype)initWithData:(nonnull NSData *)data andPumpModel:(nullable NSString *)model;
- (nonnull NSArray*) decode;

@end
