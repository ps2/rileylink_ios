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

        let strokes: UInt16

        switch strokesPerUnit {
        case let x where x > 10:
            strokes = rxData[2..<4]
        default:
            strokes = rxData[0..<2]
        }

        return Double(strokes) / Double(strokesPerUnit)
    }

    public required init?(rxData: NSData) {
        guard rxData.length == self.dynamicType.length else {
            return nil
        }

        print(rxData.hexadecimalString)

        super.init(rxData: rxData)
    }

}
