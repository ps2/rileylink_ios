//
//  GlucoseEntry.swift
//  NightscoutUploadKit
//
//  Created by Pete Schwamb on 4/19/20.
//  Copyright © 2020 Pete Schwamb. All rights reserved.
//

import Foundation

public struct GlucoseEntry {
    public var identifier: String
    public var sgv: Double
    public var date: Date
    public var trend: Int
    public var direction: String
    public var device: String
    public var type: String
}
