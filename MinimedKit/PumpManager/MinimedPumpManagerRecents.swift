//
//  MinimedPumpManagerRecents.swift
//  MinimedKit
//
//  Copyright © 2019 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

struct MinimedPumpManagerRecents: Equatable {
    var bolusState: PumpManagerStatus.BolusState = .none

    var basalDeliveryStateTransitioning = false

    var lastAddedPumpEvents: Date = .distantPast

    var latestPumpStatus: PumpStatus? = nil

    var latestPumpStatusFromMySentry: MySentryPumpStatusMessageBody? = nil {
        didSet {
            if let sensorState = latestPumpStatusFromMySentry {
                self.sensorState = EnliteSensorDisplayable(sensorState)
            }
        }
    }

    var sensorState: EnliteSensorDisplayable? = nil
}

extension MinimedPumpManagerRecents: CustomDebugStringConvertible {
    var debugDescription: String {
        return """
        ### MinimedPumpManagerRecents
        bolusState: \(bolusState)
        basalDeliveryStateTransitioning: \(basalDeliveryStateTransitioning)
        lastAddedPumpEvents: \(lastAddedPumpEvents)
        latestPumpStatus: \(String(describing: latestPumpStatus))
        latestPumpStatusFromMySentry: \(String(describing: latestPumpStatusFromMySentry))
        sensorState: \(String(describing: sensorState))
        """
    }
}
