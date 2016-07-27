//
//  LoopStatus.swift
//  RileyLink
//
//  Created by Pete Schwamb on 7/26/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class LoopStatus {
    var glucose: Int? = nil
    var timestamp: NSDate? = nil
    var eventualBG: Int? = nil
    var suggestedRate: Double? = nil
    var duration: NSTimeInterval? = nil
    var suggestedBolus: Double? = nil
}

