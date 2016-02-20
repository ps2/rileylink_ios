//
//  PumpModels.h
//  RileyLink
//
//  Created by Pete Schwamb on 11/19/15.
//  Copyright © 2015 Pete Schwamb. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PumpModel : NSObject

@property (nonatomic, readonly) BOOL larger;
@property (nonatomic, readonly) BOOL hasLowSuspend;
@property (nonatomic, readonly) NSInteger strokesPerUnit;
@property (nonatomic, readonly, strong) NSString *name;

+ (PumpModel*) find:(NSString*)number;



@end
