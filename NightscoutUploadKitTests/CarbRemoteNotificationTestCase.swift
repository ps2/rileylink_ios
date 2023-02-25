//
//  CarbRemoteNotificationTestCase.swift
//  NightscoutUploadKitTests
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import NightscoutUploadKit

final class CarbRemoteNotificationTestCase: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }
    
    func testParseCarbNotification_ValidPayload_Succeeds() throws {
        
        //Arrange
        let expectedRemoteAddress = "::ffff:11.2.44.155"
        let sentAtDateString = "2023-02-25T20:46:35.778Z"
        let expectedSentAtDate = dateFormatter().date(from: sentAtDateString)!
        let expirationDateString = "2023-02-25T20:51:35.778Z"
        let expectedExpirationDate = dateFormatter().date(from: expirationDateString)!
        let startDateString = "2023-02-25T20:46:35.778Z"
        let expectedStartDate = dateFormatter().date(from: startDateString)!
        let expectedCarbsInGrams = 15.1
        let expectedAbsorptionTimeInHours = 3.1
        let expectedFoodType = "🍕"
        let expectedOTP = "12345"

        
        let notification: [String: Any] = [
            "remote-address": expectedRemoteAddress,
            "sent-at": sentAtDateString,
            "expiration": expirationDateString,
            "start-time": startDateString,
            "carbs-entry": expectedCarbsInGrams,
            "absorption-time": expectedAbsorptionTimeInHours,
            "food-type": expectedFoodType,
            "otp": expectedOTP
        ]
        
        //Act
        let carbNotification = try CarbRemoteNotification(dictionary: notification)
        
        //Assert
        XCTAssertEqual(carbNotification.remoteAddress, expectedRemoteAddress)
        XCTAssertEqual(carbNotification.sentAt, expectedSentAtDate)
        XCTAssertEqual(carbNotification.expiration, expectedExpirationDate)
        XCTAssertEqual(carbNotification.startDate, expectedStartDate)
        XCTAssertEqual(carbNotification.amount, expectedCarbsInGrams)
        XCTAssertEqual(carbNotification.absorptionInHours, expectedAbsorptionTimeInHours)
        XCTAssertEqual(carbNotification.absorptionTime(), TimeInterval(hours: expectedAbsorptionTimeInHours))
        XCTAssertEqual(carbNotification.foodType, expectedFoodType)
        XCTAssertEqual(carbNotification.otp, expectedOTP)
    }
    
    
    //MARK: Utils
    
    func dateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions =  [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

}
