//
//  ChangeBolusWizardSetupPumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct ChangeBolusWizardSetupPumpEvent: TimestampedPumpEvent {
    public let length: Int
    public let timestamp: NSDateComponents
    
    public init?(availableData: NSData, pumpModel: PumpModel) {
        if pumpModel.larger {
            length = 144
        } else {
            length = 124
        }
        
        guard length <= availableData.length else {
            return nil
        }
        
        timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
    }
    
    public var dictionaryRepresentation: [String: AnyObject] {
        return [
            "_type": "ChangeBolusWizardSetup",
        ]
    }
}
