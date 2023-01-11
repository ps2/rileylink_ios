//
//  RemoteCommandPayload.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit //TODO: Remove

public struct NSRemoteCommandPayload: Codable {
    
    public let _id: String
    public let version: String
    public let action: NSRemoteAction
    
    public let status: NSRemoteCommandStatus
    public let otp: String
    
    public init(dictionary: [String: AnyObject]) throws {
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601DateDecoder)
        self = try jsonDecoder.decode(NSRemoteCommandPayload.self, from: data)
    }
    
    func dictionaryRepresentation() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RemoteCommandPayloadError.parseError
        }
        return dictionary
    }
    
    public static func includedInNotification(_ notification: [String: Any]) -> Bool {
        return notification["commandType"] != nil
    }
}

enum RemoteCommandPayloadError: LocalizedError {
    case parseError
}

extension DateFormatter {
    static var iso8601DateDecoder: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ" //Ex: 2022-12-24T21:34:02.090Z
        return formatter
    }()
}
