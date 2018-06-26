//
//  ChangeMaxBolusMessageBody.swift
//  MinimedKit
//
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation


public class ChangeMaxBolusMessageBody: CarelinkLongMessageBody {

    static let multiplier: Double = 10

    public convenience init?(maxBolusUnits: Double) {
        guard maxBolusUnits >= 0 && maxBolusUnits <= 25 else {
            return nil
        }

        let ticks = UInt8(maxBolusUnits * type(of: self).multiplier)
        var data = Data(bytes: [UInt8(clamping: ticks.bitWidth / 8)])
        data.appendBigEndian(ticks)

        self.init(rxData: data)
    }

}
