//
//  NoteNightscoutTreatment.swift
//  RileyLink
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation


public class NoteNightscoutTreatment: NightscoutTreatment {

    override public var dictionaryRepresentation: [String: Any] {
        var rval = super.dictionaryRepresentation
        rval["eventType"] = "Note"
        return rval;
    }
}
