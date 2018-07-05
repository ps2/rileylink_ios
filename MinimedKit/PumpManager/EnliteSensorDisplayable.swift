//
//  EnliteSensorDisplayable.swift
//  Loop
//
//  Created by Timothy Mecklem on 12/28/16.
//  Copyright © 2016 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit


struct EnliteSensorDisplayable: SensorDisplayable {
    public let isStateValid: Bool
    public let trendType: LoopKit.GlucoseTrend?
    public let isLocal: Bool

    public init?(_ event: MinimedKit.RelativeTimestampedGlucoseEvent) {
        isStateValid = event.isStateValid
        trendType = event.trendType
        isLocal = event.isLocal
    }
}

extension MinimedKit.RelativeTimestampedGlucoseEvent {
    var isStateValid: Bool {
        return self is SensorValueGlucoseEvent
    }

    var trendType: LoopKit.GlucoseTrend? {
        return nil
    }

    var isLocal: Bool {
        return true
    }
}
