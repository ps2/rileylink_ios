//
//  ChangeTempBasalCarelinkMessageBody.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/6/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public class ChangeTempBasalCarelinkMessageBody: CarelinkLongMessageBody {

    public convenience init(unitsPerHour: Double, duration: TimeInterval) {

        let length = 3
        let strokesPerUnit: Double = 40
        let strokes = Int(unitsPerHour * strokesPerUnit)
        let timeSegments = Int(duration / TimeInterval(30 * 60))

        let data = Data(hexadecimalString: String(format: "%02x%04x%02x", length, strokes, timeSegments))!

        self.init(rxData: data)!
    }

}
