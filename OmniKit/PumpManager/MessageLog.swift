//
//  MessageLog.swift
//  OmniKit
//
//  Created by Pete Schwamb on 1/28/19.
//  Copyright © 2019 Pete Schwamb. All rights reserved.
//

import Foundation

public struct MessageLogEntry: CustomStringConvertible, Equatable {

    public var description: String {
        return "\(timestamp) \(messageDirection) \(data.hexadecimalString)"
    }

    enum MessageDirection: Int {
        case send
        case receive
    }

    let messageDirection: MessageDirection
    let timestamp: Date
    let data: Data
}

extension MessageLogEntry: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard
            let rawMessageDirection = rawValue["messageDirection"] as? Int,
            let messageDirection = MessageDirection(rawValue: rawMessageDirection),
            let timestamp = rawValue["timestamp"] as? Date,
            let data = rawValue["data"] as? Data
            else {
                return nil
        }

        self.messageDirection = messageDirection
        self.timestamp = timestamp
        self.data = data
    }

    public var rawValue: RawValue {
        return [
            "messageDirection": messageDirection.rawValue,
            "timestamp": timestamp,
            "data": data,
        ]
    }

}

public struct MessageLog: CustomStringConvertible, Equatable {

    var entries = [MessageLogEntry]()

    public var description: String {
        var lines = ["### MessageLog"]
        for entry in entries {
            lines.append("* " + entry.description)
        }
        return lines.joined(separator: "\n")
    }

    mutating func erase() {
        entries.removeAll()
    }

    mutating func record(_ entry: MessageLogEntry) {
        entries.append(entry)
    }
}

extension MessageLog: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let rawEntries = rawValue["entries"] as? [MessageLogEntry.RawValue] else {
            return nil
        }

        self.entries = rawEntries.compactMap { MessageLogEntry(rawValue: $0) }
    }

    public var rawValue: RawValue {
        return [
            "entries": entries.map { $0.rawValue }
        ]
    }
}
