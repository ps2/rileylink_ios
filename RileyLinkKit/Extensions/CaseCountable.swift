//
//  CaseCountable.swift
//  RileyLink
//
//  Created by Pete Schwamb on 12/30/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public protocol CaseCountable: RawRepresentable {}

public extension CaseCountable where RawValue: Integer {
    static var count: Int {
        var i: RawValue = 0
        while let new = Self(rawValue: i) { i = new.rawValue.advanced(by: 1) }
        return Int(i.toIntMax())
    }
}
