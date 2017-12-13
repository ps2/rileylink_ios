//
//  SetModeRegistersCmd.m
//  RileyLinkBLEKit
//
//  Created by Pete Schwamb on 10/21/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

#import "SetModeRegistersCmd.h"

@interface __RegisterSetting: NSObject
@property uint8_t addr;
@property uint8_t value;
@end

@implementation __RegisterSetting
@end


@interface SetModeRegistersCmd () {
    NSMutableArray *settings;
}
@end


@implementation SetModeRegistersCmd

- (instancetype)init {
    if (self = [super init]) {
        settings = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void) addRegister:(uint8_t)addr withValue:(uint8_t)value {
    __RegisterSetting *registerSetting = [[__RegisterSetting alloc] init];
    registerSetting.addr = addr;
    registerSetting.value = value;
    [settings addObject:registerSetting];
}

- (NSData*)data {
    NSInteger dataLen = 2 + settings.count*2;
    uint8_t cmd[dataLen];
    cmd[0] = RILEYLINK_CMD_SET_MODE_REGISTERS;
    cmd[1] = _registerMode;
    for (int i=0; i<settings.count; i++) {
        __RegisterSetting *setting = settings[i];
        cmd[2 + 2*i] = setting.addr;
        cmd[2 + 2*i + 1] = setting.value;
    }
    return [NSData dataWithBytes:cmd length:dataLen];
}

@end

