//
//  TimeZone.swift
//  RileyLink
//
//  Created by Nate Racklyeft on 10/2/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//


extension TimeZone {
    static var currentFixed: TimeZone {
        return TimeZone(secondsFromGMT: TimeZone.current.secondsFromGMT())!
    }
}
