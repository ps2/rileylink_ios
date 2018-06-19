//
//  ChangeMaxBasalRateMessageBody.swift
//  MinimedKit
//
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation


public class ChangeMaxBasalRateMessageBody: CarelinkLongMessageBody {

    static let multiplier: Double = 40

    public convenience init?(maxBasalUnitsPerHour: Double) {
        guard maxBasalUnitsPerHour >= 0 && maxBasalUnitsPerHour <= 35 else {
            return nil
        }

        let ticks = UInt16(maxBasalUnitsPerHour * type(of: self).multiplier)
        var data = Data(bytes: [UInt8(clamping: ticks.bitWidth / 8)])
        data.appendBigEndian(ticks)

        self.init(rxData: data)
    }

}
