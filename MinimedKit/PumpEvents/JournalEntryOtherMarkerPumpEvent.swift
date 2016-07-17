//
//  JournalEnteryOtherMarkerPumpEvent.switf.swift
//  RileyLink
//
//  Created by Darrell Wright on 2016-07-16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public struct JournalEntryOtherPumpEvent: TimestampedPumpEvent {
	public let length: Int
	public let rawData: NSData
	public let timestamp: NSDateComponents

	public init?(availableData: NSData, pumpModel: PumpModel) {
		length = 7

		guard length <= availableData.length else {
			return nil
		}

		rawData = availableData[0..<length]

		timestamp = NSDateComponents(pumpEventData: availableData, offset: 2)
	}

	public var dictionaryRepresentation: [String: AnyObject] {
		return [
			"_type": "JournalEntryOtherPumpEvent",
		]
	}
}
