//
//  NSTimeInterval.swift
//  RileyLink
//
//  Created by Nathan Racklyeft on 4/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation


extension NSTimeInterval {
    init(minutes: Double) {
        self.init(minutes * 60)
    }
    
    init(hours: Double) {
        self.init(minutes: hours * 60)
    }
    
    var minutes: Double {
        return self / 60.0
    }
    
    var hours: Double {
        return minutes / 60.0
    }
}
