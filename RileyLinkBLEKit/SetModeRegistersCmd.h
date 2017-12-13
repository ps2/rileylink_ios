//
//  SetModeRegistersCmd.h
//  RileyLink
//
//  Created by Pete Schwamb on 10/21/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

#import "CmdBase.h"

typedef NS_ENUM(NSInteger, RegisterModeType) {
    RegisterModeTypeTX = 0x01,
    RegisterModeTypeRX = 0x02
};

@interface SetModeRegistersCmd : CmdBase

@property (nonatomic, assign) RegisterModeType registerMode;

- (void) addRegister:(uint8_t)addr withValue:(uint8_t)value;

@end

