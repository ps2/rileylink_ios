//
//  BatteryIndicator.swift
//  RileyLink
//
//  Created by Pete Schwamb on 8/2/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import NightscoutUploadKit
import MinimedKit

extension BatteryIndicator {
    init?(batteryStatus: MinimedKit.BatteryStatus) {
        switch batteryStatus {
        case .Low:
            self = .Low
        case .Normal:
            self = .Normal
        default:
            return nil
        }
    }
}