//
//  ReadRemainingInsulinMessageBody.swift
//  RileyLink
//
//  Created by Nathan Racklyeft on 5/25/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit

public class ReadRemainingInsulinMessageBody: CarelinkLongMessageBody {

    public func getUnitsRemainingForStrokes(strokesPerUnit: Int) -> Double {

        let strokes: [UInt8]

        switch strokesPerUnit {
        case let x where x > 10:
            strokes = rxData[3..<5]
        default:
            strokes = rxData[1..<3]
        }

        return Double(Int(bigEndianBytes: strokes)) / Double(strokesPerUnit)
    }

    public required init?(rxData: NSData) {
        guard rxData.length == self.dynamicType.length else {
            return nil
        }

        super.init(rxData: rxData)
    }

}
