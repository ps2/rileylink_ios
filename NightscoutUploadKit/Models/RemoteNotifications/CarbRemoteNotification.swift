//
//  CarbRemoteNotification.swift
//  NightscoutUploadKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 Pete Schwamb. All rights reserved.
//

import Foundation

public struct CarbRemoteNotification: RemoteNotification, Codable {
    
    public let amount: Double
    public let absorptionInHours: Double?
    public let foodType: String?
    public let startDate: Date?
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    public let otp: String

    enum CodingKeys: String, CodingKey {
        case remoteAddress = "remote-address"
        case amount = "carbs-entry"
        case absorptionInHours = "absorption-time"
        case foodType = "food-type"
        case startDate = "start-time"
        case expiration = "expiration"
        case sentAt = "sent-at"
        case otp = "otp"
    }
    
    public func absorptionTime() -> TimeInterval? {
        guard let absorptionInHours = absorptionInHours else {
            return nil
        }
        return TimeInterval(hours: absorptionInHours)
    }
    
    public static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["carbs-entry"] != nil
    }
}
