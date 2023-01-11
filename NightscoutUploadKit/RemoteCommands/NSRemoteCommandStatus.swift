//
//  NSRemoteCommandStatus.swift
//  NightscoutUploadKit
//
//  Created by Bill Gestrich on 12/31/22.
//  Copyright © 2022 Pete Schwamb. All rights reserved.
//

import Foundation

public struct NSRemoteCommandStatus: Codable {
    
    /*
     TODO: Having a message is not ideal. Should reconsider error modeling.
     See comments in RemoteCommandPayload.
     Something similar could be done here.
     The values for success, pending, etc could be the delivery/error dates which we would
     like anyways.
     */
    public let state: NSRemoteComandState
    public let message: String
    
    //TODO: Add delivery date
    public init(state: NSRemoteComandState, message: String){
        self.state = state
        self.message = message
    }
    
    public enum NSRemoteComandState: String, Codable {
        case Pending
        case InProgress
        case Success
        case Error
        
        var title: String {
            switch self {
            case .Pending:
                return "Pending"
            case .InProgress:
                return "In-Progress"
            case .Success:
                return "Success"
            case .Error:
                return "Error"
            }
        }
    }
    
    public enum NSRemoteCommandStatusError: LocalizedError {
        case parseError
    }
    
}
