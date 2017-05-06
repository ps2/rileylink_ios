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

- (void)testDecodeRFString {
    NSData *response = [NSData dataWithHexadecimalString:@"5655c56c55555c8e55554b5a35552e6d31d232d6c558e3c566b2d16563956c55555c665716b2d16563956c5558b5556a39a5563c56c55555c8e55554b999555695d23d342d6c5558b571695d15565c56c5556a8d555555555555555555555571c6729b15"];
    RFPacket *packet = [[RFPacket alloc] initWithRFSPYResponse:response];

    XCTAssertEqualObjects(@"1710002e000b7300b64143b7103317824703571000160182470357107b008365031710002e000b6900804344b7107b0180400517100a3000000000000000ff9261", packet.data.hexadecimalString);
}

@end
