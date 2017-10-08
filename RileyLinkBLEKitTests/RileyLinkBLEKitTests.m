//
//  RileyLinkBLEKitTests.m
//  RileyLinkBLEKitTests
//
//  Created by Nathan Racklyeft on 4/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RileyLinkBLEDevice.h"
#import "RileyLinkBLEKit/RileyLinkBLEKit-Swift.h"
#import "NSData+Conversion.h"

@interface RileyLinkBLEDevice (_Private)

- (SubgRfspyVersionState)firmwareStateForVersionString:(NSString *)firmwareVersion;

@end

@interface RileyLinkBLEKitTests : XCTestCase

@end

@implementation RileyLinkBLEKitTests

- (void)testVersionParsing {
    id peripheral = nil;
    
    RileyLinkBLEDevice *device = [[RileyLinkBLEDevice alloc] initWithPeripheral:peripheral];
    
    SubgRfspyVersionState state = [device firmwareStateForVersionString:@"subg_rfspy 0.8"];
    
    XCTAssertEqual(SubgRfspyVersionStateUpToDate, state);
}

- (void)testDecodeRF {
    NSData *response = [NSData dataWithHexadecimalString:@"4926a965a5d1a8dab0e5635635555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555559a35"];
    RFPacket *packet = [[RFPacket alloc] initWithRfspyResponse:response];
    XCTAssertEqualObjects(@"a965a5d1a8dab0e5635635555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555559a35", packet.data.hexadecimalString);
    XCTAssertEqual(-37, packet.rssi);
}


@end
