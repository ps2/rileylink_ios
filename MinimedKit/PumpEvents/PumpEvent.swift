//
//  PumpEvent.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public protocol PumpEvent : DictionaryRepresentable {
    
    init?(availableData: Data, pumpModel: PumpModel)
    
    var rawData: Data {
        get
    }

    var length: Int {
        get
    }
    
}
