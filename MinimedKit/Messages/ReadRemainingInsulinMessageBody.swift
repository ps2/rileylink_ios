//
//  ReadRemainingInsulinMessageBody.swift
//  RileyLink
//
//  Created by Nathan Racklyeft on 5/25/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class ReadRemainingInsulinMessageBody: CarelinkLongMessageBody {

    public func getUnitsRemainingForStrokes(_ strokesPerUnit: Int) -> Double {

        let strokes: Data

        switch strokesPerUnit {
        case let x where x > 10:
            strokes = rxData.subdata(in: 3..<5)
        default:
            strokes = rxData.subdata(in: 1..<3)
        }

        return Double(Int(bigEndianBytes: strokes)) / Double(strokesPerUnit)
    }

    public required init?(rxData: Data) {
        guard rxData.count == type(of: self).length else {
            return nil
        }

        super.init(rxData: rxData)
    }
}
