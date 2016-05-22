//
//  NSDate.swift
//  RileyLink
//
//  Created by Pete Schwamb on 5/18/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

func ==(lhs: NSDate, rhs: NSDate) -> Bool {
    return lhs === rhs || lhs.compare(rhs) == .OrderedSame
}

// MARK: - Comparable

func <(lhs: NSDate, rhs: NSDate) -> Bool {
    return lhs.compare(rhs) == .OrderedAscending
}
