//
//  PumpRegion.swift
//  RileyLink
//
//  Created by Pete Schwamb on 9/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public enum PumpRegion: Int, CustomStringConvertible  {
    case northAmerica = 0
    case worldWide
    
    public var description: String {
        switch self {
        case .worldWide:
            return NSLocalizedString("World-Wide", comment: "Describing the worldwide pump region")
        case .northAmerica:
            return NSLocalizedString("North America", comment: "Describing the North America pump region")
        }
    }
}
