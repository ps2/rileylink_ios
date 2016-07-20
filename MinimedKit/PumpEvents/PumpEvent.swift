//
//  PumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public protocol PumpEvent : DictionaryRepresentable {
    
    init?(availableData: NSData, pumpModel: PumpModel)
    
    var rawData: NSData {
        get
    }

    var length: Int {
        get
    }
    
}
