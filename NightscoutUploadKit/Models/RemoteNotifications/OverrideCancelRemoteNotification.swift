//
//  OverrideCancelRemoteNotification.swift
//  NightscoutUploadKit
//
//  Created by Bill Gestrich on 2/25/23.
//  Copyright © 2023 Pete Schwamb. All rights reserved.
//

import Foundation

public struct OverrideCancelRemoteNotification: RemoteNotification, Codable {
    
    public let remoteAddress: String
    public let expiration: Date?
    public let sentAt: Date?
    public let cancelOverride: Bool

    enum CodingKeys: String, CodingKey {
        case remoteAddress = "remote-address"
        case expiration = "expiration"
        case sentAt = "sent-at"
        case cancelOverride = "cancel-temporary-override"
    }
    
    public static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["cancel-temporary-override"] != nil
    }
}
