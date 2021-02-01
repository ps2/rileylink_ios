//
//  ReservoirLevel.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 1/31/21.
//  Copyright © 2021 Pete Schwamb. All rights reserved.
//

import Foundation

public enum ReservoirLevel: Equatable {
    public typealias RawValue = Int
    
    public static let aboveThresholdMagicNumber: Int = 5115

    case valid(Double)
    case aboveThreshold

    public var percentage: Double {
        switch self {
        case .aboveThreshold:
            return 1
        case .valid(let value):
            // Set 50U as the halfway mark, even though pods can hold 200U.
            return min(1, max(0, value / 100))
        }
    }
}
