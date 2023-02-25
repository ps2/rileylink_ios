//
//  BolusRemoteNotification.swift
//  NightscoutUploadKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 Pete Schwamb. All rights reserved.
//

import Foundation

public struct BolusRemoteNotification: RemoteNotification, Codable {
    
    public let amount: Double
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    public let otp: String
    
    enum CodingKeys: String, CodingKey {
        case remoteAddress = "remote-address"
        case amount = "bolus-entry"
        case expiration = "expiration"
        case sentAt = "sent-at"
        case otp = "otp"
    }
    
    public static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["bolus-entry"] != nil
    }
}
