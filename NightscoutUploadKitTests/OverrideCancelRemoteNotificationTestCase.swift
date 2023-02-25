//
//  OverrideCancelRemoteNotificationTestCase.swift
//  NightscoutUploadKitTests
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import NightscoutUploadKit

final class OverrideCancelRemoteNotificationTestCase: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testParseOverrideCancelNotification_ValidPayload_Succeeds() throws {
        
        //Arrange
        let expectedRemoteAddress = "::ffff:11.2.44.155"
        let sentAtDateString = "2023-02-25T20:46:35.778Z"
        let expectedSentAtDate = dateFormatter().date(from: sentAtDateString)!
        let expirationDateString = "2023-02-25T20:51:35.778Z"
        let expectedExpirationDate = dateFormatter().date(from: expirationDateString)!
        let expectedCancelOverrideValue = true
        
        let notification: [String: Any] = [
            "remote-address": expectedRemoteAddress,
            "sent-at": sentAtDateString,
            "expiration": expirationDateString,
            "cancel-temporary-override": expectedCancelOverrideValue
        ]
        
        //Act
        let overrideNotification = try OverrideCancelRemoteNotification(dictionary: notification)
        
        //Assert
        XCTAssertEqual(overrideNotification.remoteAddress, expectedRemoteAddress)
        XCTAssertEqual(overrideNotification.sentAt, expectedSentAtDate)
        XCTAssertEqual(overrideNotification.expiration, expectedExpirationDate)
        XCTAssertEqual(overrideNotification.cancelOverride, expectedCancelOverrideValue)
    }
    
    
    //MARK: Utils
    
    func dateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions =  [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

}
