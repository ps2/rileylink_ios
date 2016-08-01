//
//  ReadPumpStatusMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/31/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class ReadPumpStatusMessageBody: CarelinkLongMessageBody {

    public let bolusing: Bool
    public let suspended: Bool

    public required init?(rxData: NSData) {
        guard rxData.length == self.dynamicType.length else {
            return nil
        }

        bolusing = (rxData[2] as UInt8) > 0
        suspended = (rxData[3] as UInt8) > 0

        super.init(rxData: rxData)
    }
    
}
