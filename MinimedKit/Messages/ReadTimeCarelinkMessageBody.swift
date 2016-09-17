//
//  ReadTimeCarelinkMessageBody.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/17/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public class ReadTimeCarelinkMessageBody: CarelinkLongMessageBody {

    public let dateComponents: DateComponents

    public required init?(rxData: Data) {
        guard rxData.count == type(of: self).length else {
            return nil
        }

        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        dateComponents.hour   = Int(rxData[1] as UInt8)
        dateComponents.minute = Int(rxData[2] as UInt8)
        dateComponents.second = Int(rxData[3] as UInt8)
        dateComponents.year   = Int(bigEndianBytes: rxData.subdata(in: 4..<6))
        dateComponents.month  = Int(rxData[6] as UInt8)
        dateComponents.day    = Int(rxData[7] as UInt8)

        self.dateComponents = dateComponents

        super.init(rxData: rxData)
    }
}
