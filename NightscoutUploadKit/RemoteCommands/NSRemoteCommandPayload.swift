//
//  NSRemoteCommandPayload.swift
//  NightscoutServiceKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public struct NSRemoteCommandPayload: Codable, Equatable {
    
    public let _id: String?
    public let version: String
    public let action: NSRemoteAction
    public let sendNotification: Bool
    public let createdDate: Date
    
    public let status: NSRemoteCommandStatus
    public let otp: String
    
    public init(version: String, createdDate: Date, action: NSRemoteAction, sendNotification: Bool, status: NSRemoteCommandStatus, otp: String) {
        self._id = nil
        self.createdDate = createdDate
        self.version = version
        self.action = action
        self.sendNotification = sendNotification
        self.status = status
        self.otp = otp
    }
    
    public init(dictionary: [String: AnyObject]) throws {
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601DateDecoder)
        self = try jsonDecoder.decode(NSRemoteCommandPayload.self, from: data)
    }
    
    func dictionaryRepresentation() throws -> [String: Any] {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .formatted(DateFormatter.iso8601DateDecoder)
        let data = try jsonEncoder.encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RemoteCommandPayloadError.parseError
        }
        return dictionary
    }
    
    public static func includedInNotification(_ notification: [String: Any]) -> Bool {
        guard let version = notification["version"] as? Double else {
            return false
        }
            
        return version >= 2.0
    }
    
    
    //MARK: Equatable
    
    public static func == (lhs: NightscoutUploadKit.NSRemoteCommandPayload, rhs: NightscoutUploadKit.NSRemoteCommandPayload) -> Bool {
        //TODO: Make this exhaustive
        return lhs._id == rhs._id &&
        lhs.status.state == rhs.status.state
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
