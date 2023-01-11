//
//  NSRemoteCommandAlternatePayload.swift
//  NightscoutUploadKit
//
//  Created by Bill Gestrich on 1/1/23.
//  Copyright © 2023 Pete Schwamb. All rights reserved.
//

import Foundation

/*
 This demonstrates an alternate format for the action in the payload to consider
 The benefit is the payload doesn't require additional nesting.
 
 The challenges:
 
 - You can't have methods like parsePayload() -> Payload that return a Payload since it requires generic to be specified.

 */


protocol Action: Codable {
    
}

private struct BolusAction: Action, Codable {
    let amountInUnits: Double
}

enum PlaygroundError: LocalizedError {
    case error
}


private enum PayloadType: String, Codable {
    case bolus
}

private struct Payload<T: Action>: Codable {
    let actionType: String
    let action: T
}

func parsePayload() throws {
    let payloadJSON: [String: Any] = [
        "actionType": "bolus",
        "action": [
            "amountInUnits": 3.0
        ]
    ]

    let data = try! JSONSerialization.data(withJSONObject: payloadJSON)
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        assertionFailure("Could not cast")
        throw PlaygroundError.error
    }

    guard let actionString = json["actionType"] as? String, let actionType = PayloadType(rawValue: actionString) else {
        throw PlaygroundError.error
    }

    switch actionType {
    case .bolus:
        let bolusPayload = try! JSONDecoder().decode(Payload<BolusAction>.self, from: data)
        print("Parse ok")
        print(bolusPayload)
    }

}

