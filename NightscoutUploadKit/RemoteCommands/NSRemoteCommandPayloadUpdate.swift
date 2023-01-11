//
//  NSRemoteCommandPayloadUpdate.swift
//  NightscoutUploadKit
//
//  Created by Bill Gestrich on 12/31/22.
//  Copyright © 2022 Pete Schwamb. All rights reserved.
//

import Foundation

public struct NSRemoteCommandPayloadUpdate: Codable {
    
    public let status: NSRemoteCommandStatus?
    
    public init(status: NSRemoteCommandStatus? = nil) {
        self.status = status
    }
    
    public func dictionaryRepresentation() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let jsonObj = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        
        guard let result = jsonObj as? [String: Any] else {
            throw RemoteCommandPayloadUpdateError.invalidJSON
        }
        
        return result
        
        enum RemoteCommandPayloadUpdateError: LocalizedError {
            case invalidJSON
        }
    }
}
