//
//  RileyLinkBLEKitTests.m
//  RileyLinkBLEKitTests
//
//  Created by Nathan Racklyeft on 4/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RileyLinkBLEDevice.h"

@interface RileyLinkBLEDevice (_Private)

- (SubgRfspyVersionState)firmwareStateForVersionString:(NSString *)firmwareVersion;

@end

@interface RileyLinkBLEKitTests : XCTestCase

@end

@implementation RileyLinkBLEKitTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testVersionParsing {
    id peripheral = nil;

    RileyLinkBLEDevice *device = [[RileyLinkBLEDevice alloc] initWithPeripheral:peripheral];

    SubgRfspyVersionState state = [device firmwareStateForVersionString:@"subg_rfspy 0.8"];

    XCTAssertEqual(SubgRfspyVersionStateUpToDate, state);
}

@end
