//
//  RileyLinkBLEKitTests.m
//  RileyLinkBLEKitTests
//
//  Created by Nathan Racklyeft on 4/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RileyLinkBLEDevice.h"
#import "RFPacket.h"
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
    RFPacket *packet = [[RFPacket alloc] initWithRFSPYResponse:response];
    XCTAssertEqualObjects(@"a7754838ce0303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", packet.data.hexadecimalString);
}

- (void)testEncodeData {
    NSData *msg = [NSData dataWithHexadecimalString:@"a77548380600a2"];
    RFPacket *packet = [[RFPacket alloc] initWithData:msg];
    
    XCTAssertEqualObjects(@"a965a5d1a8da566555ab2555", packet.encodedData.hexadecimalString);
}

- (void)testDecodeInvalidCRC {
    NSData *response = [NSData dataWithHexadecimalString:@"4926b165a5d1a8dab0e5635635555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555559a35"];
    RFPacket *packet = [[RFPacket alloc] initWithRFSPYResponse:response];
    XCTAssertNil(packet.data);
}


@end
