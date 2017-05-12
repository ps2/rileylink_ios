//
//  DataFrameMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 5/6/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public class DataFrameMessageBody : CarelinkLongMessageBody {
    public let lastFrameFlag: Bool
    public let frameNumber: Int
    public let contents: Data

    public required init?(rxData: Data) {
        self.lastFrameFlag = rxData[0] & 0x80 != 0
        self.frameNumber = Int(rxData[0] & 0x7f)
        self.contents = rxData.subdata(in: (1..<rxData.count))
        super.init(rxData: rxData)
    }
}
