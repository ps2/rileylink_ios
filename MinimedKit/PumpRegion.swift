//
//  PumpRegion.swift
//  RileyLink
//
//  Created by Pete Schwamb on 9/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public enum PumpRegion: Int, CustomStringConvertible  {
    case NorthAmerica = 0
    case WorldWide
    
    public var description: String {
        switch self {
        case .WorldWide:
            return NSLocalizedString("World-Wide", comment: "Describing the worldwide pump region")
        case .NorthAmerica:
            return NSLocalizedString("North America", comment: "Describing the North America pump region")
        }
    }
}
