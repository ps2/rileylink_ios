//
//  PredictedBG.swift
//  RileyLink
//
//  Created by Pete Schwamb on 8/8/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct PredictedBG {
    let values: [Double]
    let cob: [Double]?
    let iob: [Double]?

    public init(values: [Double], cob: [Double]? = nil, iob: [Double]? = nil) {
        self.values = values
        self.cob = cob
        self.iob = iob
    }

    public var dictionaryRepresentation: [String: AnyObject] {

        var rval = [String: AnyObject]()

        rval["values"] = values

        if let cob = cob {
            rval["cob"] = cob
        }

        if let iob = iob {
            rval["iob"] = iob
        }

        return rval
    }
}
