//
//  PumpOpsSynchronousTests.swift
//  RileyLink
//
//  Created by Jaim Zuber on 2/21/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import XCTest

@testable import RileyLinkKit
import MinimedKit
import RileyLinkBLEKit

class PumpOpsSynchronousTests: XCTestCase {
    
    var sut: PumpOpsSynchronous!
    var pumpState: PumpState!
    var pumpID: String!
    var pumpRegion: PumpRegion!
    var rileyLinkCmdSession: RileyLinkCmdSession!
    var pumpModel: PumpModel!
    var messageSenderStub: PumpMessageSenderStub!

    let dateComponents2007 = DateComponents(calendar: Calendar.current, year: 2007, month: 1, day: 1)
    let dateComponents2017 = DateComponents(calendar: Calendar.current, year: 2017, month: 1, day: 1)
    
    let squareBolusDataLength = 26
    
    lazy var datePast2007: Date = {
        return self.dateComponents2017.date!.addingTimeInterval(TimeInterval(minutes:60))
    }()
    
    lazy var datePast2017: Date = {
        return self.dateComponents2017.date!.addingTimeInterval(TimeInterval(minutes:60))
    }()
    
    lazy var dateTimestamp2010: DateComponents = {
        self.createSquareBolusEvent2010().timestamp
    }()
    
    override func setUp() {
        super.setUp()
        
        pumpID = "350535"
        pumpRegion = .worldWide
        pumpModel = PumpModel.model523
        
        rileyLinkCmdSession = RileyLinkCmdSession()
        messageSenderStub = PumpMessageSenderStub()
        
        setUpSUT()
    }
    
    /// Creates the System Under Test. This is needed because our SUT has dependencies injected through the constructor
    func setUpSUT() {
        pumpState = PumpState(pumpID: pumpID, pumpRegion: pumpRegion)
        pumpState.pumpModel = pumpModel
        pumpState.awakeUntil = Date(timeIntervalSinceNow: 100) // pump is awake
        
        sut = PumpOpsSynchronous(pumpState: pumpState, session: rileyLinkCmdSession, pumpMessageSender: messageSenderStub)
    }
    
    /// Duplicates logic in setUp with a new PumpModel
    ///
    /// - Parameter newPumpModel: model of the pump to test
    func setUpTestWithPumpModel(_ newPumpModel: PumpModel) {
        pumpModel = newPumpModel
        setUpSUT()
    }
    
    func testShouldContinueIfTimestampBeforeStartDateNotEncountered() {
        let pumpEvents: [PumpEvent] = [createBatteryEvent()]
        
        let (_, hasMoreEvents, _) = sut.convertPumpEventToTimestampedEvents(pumpEvents: pumpEvents, startDate: Date.distantPast, pumpModel: pumpModel)
        
        XCTAssertTrue(hasMoreEvents)
    }
    
    func testShouldFinishIfTimestampBeforeStartDateEncountered() {
        let batteryEvent = createBatteryEvent()
        let pumpEvents: [PumpEvent] = [batteryEvent]
        
        let afterBatteryEventDate = batteryEvent.timestamp.date!.addingTimeInterval(TimeInterval(hours: 10))
        
        let (_, hasMoreEvents, _) = sut.convertPumpEventToTimestampedEvents(pumpEvents: pumpEvents, startDate: afterBatteryEventDate, pumpModel: pumpModel)
        
        XCTAssertFalse(hasMoreEvents)
    }

    func testEventsAfterStartDateAreReturned() {
        let batteryEvent2007 = createBatteryEvent(withDateComponent: dateComponents2007)
        let batteryEvent2017 = createBatteryEvent(withDateComponent: dateComponents2017)
        let pumpEvents: [PumpEvent] = [batteryEvent2017, batteryEvent2007]
        
        let (events, _, _) = sut.convertPumpEventToTimestampedEvents(pumpEvents: pumpEvents, startDate: Date.distantPast, pumpModel: pumpModel)
        
        XCTAssertEqual(events.count, 2)
    }

    func testEventBeforeStartDateIsFiltered() {
        let datePast2007 = dateComponents2007.date!.addingTimeInterval(TimeInterval(minutes: 60))
        
        let batteryEvent2007 = createBatteryEvent(withDateComponent: dateComponents2007)
        let batteryEvent2017 = createBatteryEvent(withDateComponent: dateComponents2017)
        let pumpEvents: [PumpEvent] = [batteryEvent2017, batteryEvent2007]
        
        let (events, hasMoreEvents, cancelled) = sut.convertPumpEventToTimestampedEvents(pumpEvents: pumpEvents, startDate: datePast2007, pumpModel: pumpModel)
        
        assertArray(events, doesntContainPumpEvent: batteryEvent2007)
        XCTAssertEqual(events.count, 1)
        XCTAssertFalse(hasMoreEvents)
        XCTAssertFalse(cancelled)
    }

    func testPumpLostTimeCancelsFetchEarly() {
        let batteryEvent2007 = createBatteryEvent(withDateComponent: dateComponents2007)
        let batteryEvent2017 = createBatteryEvent(withDateComponent: dateComponents2017)
        let pumpEvents: [PumpEvent] = [batteryEvent2007, batteryEvent2017]

        let (events, hasMoreEvents, cancelledEarly) = sut.convertPumpEventToTimestampedEvents(pumpEvents: pumpEvents, startDate: Date.distantPast,  pumpModel: pumpModel)

        XCTAssertTrue(cancelledEarly)
        XCTAssertFalse(hasMoreEvents)
        XCTAssertEqual(events.count, 1)
        assertArray(events, doesntContainPumpEvent: batteryEvent2017)
    }
    
    func testEventsWithSameDataArentAddedTwice() {
        let pumpEvents: [PumpEvent] = [createBolusEvent2009(), createBolusEvent2009()]
        let (events, _, _) = sut.convertPumpEventToTimestampedEvents(pumpEvents: pumpEvents, startDate: Date.distantPast, pumpModel: pumpModel)
        XCTAssertEqual(events.count, 1)
    }

    func testNonMutableSquareWaveBolusFor522IsReturned() {
        // device that can have out of order events
        setUpTestWithPumpModel(.model522)
        // 2009-07-31 09:00:00 +0000
        // 120 minute duration
        let squareWaveBolus = BolusNormalPumpEvent(availableData: Data(hexadecimalString: "010080048000240009a24a1510")!, pumpModel: pumpModel)!
        
        let events:[PumpEvent] = [squareWaveBolus]
        
        let (timeStampedEvents, _, _) = sut.convertPumpEventToTimestampedEvents(pumpEvents: events, startDate: Date.distantPast, pumpModel: pumpModel)
        
        // It should be included
        XCTAssertTrue(array(timeStampedEvents, containsPumpEvent: squareWaveBolus))
    }

    // This sets up a square wave bolus that has a timestamp four hours before a temp basal, but is appended to history
    // "after" the temp basal.  This is an important condition to test, because the temp basal could be filtered out erroneously
    // if we were just filtering on startDate, and startDate was after the bolus timestamp, but before the temp basal.
    // Previously, convertPumpEventToTimestampedEvents was being called with startDate: Date.distantPast
    // Changing it to use a time in that important window to cover
    func testDelayedAppendEventDoesNotCauseValidEventsToBeFilteredOut() {
        setUpTestWithPumpModel(.model522)

        let tempEventBasal = createTempEventBasal2016()
        let dateComponents = tempEventBasal.timestamp.addingTimeInterval(TimeInterval(hours:-4))
        let squareBolusEventFourHoursBefore = createSquareBolusEvent(dateComponents: dateComponents)
        
        let events:[PumpEvent] = [squareBolusEventFourHoursBefore, tempEventBasal]
        let (timeStampedEvents, hasMoreEvents, cancelled) = sut.convertPumpEventToTimestampedEvents(pumpEvents: events, startDate: Date.distantPast, pumpModel: pumpModel)

        // Debatable (undefined) whether this should be returned. It is tested to avoid inadvertantly changing behavior
        assertArray(timeStampedEvents, containsPumpEvent: squareBolusEventFourHoursBefore)
        XCTAssertTrue(hasMoreEvents)
        XCTAssertFalse(cancelled)
    }

    // MARK: Regular Bolus Event before starttime (offset 9 minutes)
    func test522RegularBolusEventBeforeStartTimeShouldNotCancel() {
        setUpTestWithPumpModel(.model522)
        
        let pumpEvent = createSquareBolusEvent2010()
        
        let startDate = pumpEvent.timestamp.date!.addingTimeInterval(TimeInterval(minutes:9))
        
        let (timestampedEvents, hasMoreEvents, cancelled) = sut.convertPumpEventToTimestampedEvents(pumpEvents: [pumpEvent], startDate: startDate, pumpModel: self.pumpModel)
        
        assertArray(timestampedEvents, containsPumpEvent: pumpEvent)
        //We found an event before the start time but we can't verify the timestamp from the Square Bolus so there could be more valid events
        XCTAssertTrue(hasMoreEvents)
        XCTAssertFalse(cancelled)
    }

    // The test the border condition sof the pump lost time detection, the main behavior of which is covered
    // in testPumpLostTimeCancelsFetchEarly. The precise point at which we decide pump time is lost (the one hour mark) is aribtrary.
    
    func testOutOfOrderEventUnderAnHourDoesntCancel() {
        setUpTestWithPumpModel(.model523)

        let after2007Date = dateComponents2007.date!.addingTimeInterval(TimeInterval(minutes:59))

        let batteryEvent = createBatteryEvent(withDateComponent: dateComponents2007)
        let laterBatteryEvent = createBatteryEvent(atTime: after2007Date)

        let events = [batteryEvent, laterBatteryEvent]

        let (_, _, cancelled) = sut.convertPumpEventToTimestampedEvents(pumpEvents: events, startDate: .distantPast, pumpModel: pumpModel)

        XCTAssertFalse(cancelled)
    }

    // MARK: Test Sanity Checks
    func test2010EventSanityWith523() {
        setUpTestWithPumpModel(.model523)
        let bolusEvent = createSquareBolusEvent2010()
        XCTAssertEqual(bolusEvent.timestamp.year!, 2010)
        XCTAssertEqual(bolusEvent.timestamp.timeZone, pumpState.timeZone)
    }
    
    func test2009EventSanityWith523() {
        setUpTestWithPumpModel(.model523)
        let bolusEvent = createBolusEvent2009()
        XCTAssertEqual(bolusEvent.timestamp.year!, 2009)
        XCTAssertEqual(bolusEvent.timestamp.timeZone, pumpState.timeZone)
    }
    
    func test2009EventSavityWith522() {
        setUpTestWithPumpModel(.model522)
        XCTAssertEqual(createBolusEvent2009().timestamp.year!, 2009)
    }
    
    func test2010EventSanityWith522() {
        setUpTestWithPumpModel(.model522)
        XCTAssertEqual(createSquareBolusEvent2010().timestamp.year!, 2010)
    }

    func createBatteryEvent(withDateComponent dateComponents: DateComponents) -> BatteryPumpEvent {
        return createBatteryEvent(atTime: dateComponents.date!)
    }
    
    func createBatteryEvent(atTime date: Date = Date()) -> BatteryPumpEvent {
     
        let calendar = Calendar.current
        
        let year = calendar.component(.year, from: date) - 2000
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        
        let secondByte = UInt8(second) & 0b00111111
        let minuteByte = UInt8(minute) & 0b00111111
        let hourByte = UInt8(hour) & 0b00011111
        let dayByte = UInt8(day) & 0b00011111
        let monthUpperComponent = (UInt8(month) & 0b00001100) << 4
        let monthLowerComponent = (UInt8(month) & 0b00000011) << 6
        let secondMonthByte = secondByte | monthUpperComponent
        let minuteMonthByte = minuteByte | monthLowerComponent
        let yearByte = UInt8(year) & 0b01111111

        let batteryData = Data(bytes: [0,0, secondMonthByte, minuteMonthByte, hourByte, dayByte, yearByte])
        let batteryPumpEvent = BatteryPumpEvent(availableData: batteryData, pumpModel: PumpModel.model523)!
        return batteryPumpEvent
    }
    
    func createSquareBolusEvent2016() -> BolusNormalPumpEvent {
        //2016-08-01 05:00:16 +000
        let dateComponents = DateComponents(calendar: Calendar.current, timeZone: pumpState.timeZone, year: 2016, month: 8, day: 1, hour: 5, minute: 0, second: 16)
        let data = Data(hexadecimalString: "01009009600058008a344b1010")!
        return BolusNormalPumpEvent(length: BolusNormalPumpEvent.calculateLength(pumpModel.larger), rawData: data, timestamp: dateComponents, unabsorbedInsulinRecord: nil, amount: 0.0, programmed: 0.0, unabsorbedInsulinTotal: 0.0, type: .square, duration: TimeInterval(minutes: 120))
    }
    
    func createSquareBolusEvent2010() -> BolusNormalPumpEvent {
        //2010-08-01 05:00:16 +000
        let dateComponents = DateComponents(calendar: Calendar.current, timeZone: pumpState.timeZone, year: 2010, month: 8, day: 1, hour: 5, minute: 0, second: 16)
        let data = Data(hexadecimalString: "01009000900058008a344b1010")!
        return BolusNormalPumpEvent(length: BolusNormalPumpEvent.calculateLength(pumpModel.larger), rawData: data, timestamp: dateComponents, unabsorbedInsulinRecord: nil, amount: 0.0, programmed: 0.0, unabsorbedInsulinTotal: 0.0, type: .square, duration: TimeInterval(minutes: 120))
    }
    
    func createSquareBolusEvent(dateComponents: DateComponents) -> BolusNormalPumpEvent {
        let data = Data(hexadecimalString: randomDataString(length: squareBolusDataLength))!
        return BolusNormalPumpEvent(length: BolusNormalPumpEvent.calculateLength(pumpModel.larger), rawData: data, timestamp: dateComponents, unabsorbedInsulinRecord: nil, amount: 0.0, programmed: 0.0, unabsorbedInsulinTotal: 0.0, type: .square, duration: TimeInterval(hours: 8))
    }
    
    func createBolusEvent2011() -> BolusNormalPumpEvent {
        //2010-08-01 05:00:11 +000
        let dateComponents = DateComponents(calendar: Calendar.current, timeZone: pumpState.timeZone, year: 2011, month: 8, day: 1, hour: 5, minute: 0, second: 16)
        let data = Data(hexadecimalString: "01009000900058008a344b10FF")!
        return BolusNormalPumpEvent(length: BolusNormalPumpEvent.calculateLength(pumpModel.larger), rawData: data, timestamp: dateComponents, unabsorbedInsulinRecord: nil, amount: 0.0, programmed: 0.0, unabsorbedInsulinTotal: 0.0, type: .normal, duration: TimeInterval(minutes: 120))
    }
    
    func createTempEventBasal2016() -> TempBasalPumpEvent {
        // 2016-05-30 01:21:00 +0000
        let tempEventBasal = TempBasalPumpEvent(availableData: Data(hexadecimalString:"338c4055145d1000")!, pumpModel: pumpModel)!
        return tempEventBasal
    }
    
    func createBolusEvent2009() -> BolusNormalPumpEvent {
        
        let dateComponents = DateComponents(calendar: Calendar.current, timeZone: pumpState.timeZone, year: 2009, month: 7, day: 31, hour: 9, minute: 0, second: 0)
        let timeInterval: TimeInterval = TimeInterval(minutes: 2)
        let data = Data(hexadecimalString:"338c4055145d2000")!
        
        return BolusNormalPumpEvent(length: 13, rawData: data, timestamp: dateComponents, unabsorbedInsulinRecord: nil, amount: 2.0, programmed: 1.0, unabsorbedInsulinTotal: 0.0, type: .normal, duration: timeInterval)
    }
    
    func createNonDelayedEvent2009() -> BolusReminderPumpEvent {
        let dateComponents = DateComponents(calendar: Calendar.current, timeZone: pumpState.timeZone, year: 2009, month: 7, day: 31, hour: 9, minute: 0, second: 0)
        let data = Data(hexadecimalString:"338c48FFF45d2000")!
        let length = 7
        
        return BolusReminderPumpEvent(length: length, rawData: data, timestamp: dateComponents)
    }
}

// from comment at https://gist.github.com/szhernovoy/276e69eb90a0de84dd90
func randomDataString(length:Int) -> String {
    let charSet = "abcdef0123456789"
    var c = charSet.characters.map { String($0) }
    var s:String = ""
    for _ in 0..<length {
        s.append(c[Int(arc4random()) % c.count])
    }
    return s
}

class PumpMessageSenderStub : PumpMessageSender {
    
    var responses = [MessageType: [PumpMessage]]()
    
    // internal tracking of how many times a response type has been received
    private var responsesHaveOccured = [MessageType: Int]()
    
    func sendAndListen(_ msg: PumpMessage, timeoutMS: UInt32, repeatCount: UInt8 = 0, msBetweenPackets: UInt8 = 0, retryCount: UInt8 = 3) throws -> PumpMessage {
        
        if let responseArray = responses[msg.messageType] {
            let numberOfResponsesReceived: Int
            
            if let someValue = responsesHaveOccured[msg.messageType] {
                numberOfResponsesReceived = someValue
            } else {
                numberOfResponsesReceived = 0
            }
            
            let nextNumberOfResponsesReceived = numberOfResponsesReceived+1
            responsesHaveOccured[msg.messageType] = nextNumberOfResponsesReceived
            
            if numberOfResponsesReceived >= responseArray.count {
                XCTFail()
            }
            
            return responseArray[numberOfResponsesReceived]
        }
        return PumpMessage(rxData: Data())!
    }
}

func array(_ timestampedEvents: [TimestampedHistoryEvent], containsPumpEvent pumpEvent: PumpEvent) -> Bool {
    let event = timestampedEvents.first { $0.pumpEvent.rawData == pumpEvent.rawData }
    
    return event != nil
}

func assertArray(_ timestampedEvents: [TimestampedHistoryEvent], containsPumpEvent pumpEvent: PumpEvent) {
    XCTAssertNotNil(timestampedEvents.first { $0.pumpEvent.rawData == pumpEvent.rawData})
}

func assertArray(_ timestampedEvents: [TimestampedHistoryEvent], containsPumpEvents pumpEvents: [PumpEvent]) {
    pumpEvents.forEach { assertArray(timestampedEvents, containsPumpEvent: $0) }
}

func assertArray(_ timestampedEvents: [TimestampedHistoryEvent], doesntContainPumpEvent pumpEvent: PumpEvent) {
    XCTAssertNil(timestampedEvents.first { $0.pumpEvent.rawData == pumpEvent.rawData })
}

// from http://jernejstrasner.com/2015/07/08/testing-throwable-methods-in-swift-2.html - transferred to Swift 3
func assertThrows<T>(_ expression: @autoclosure  () throws -> T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    do {
        let _ = try expression()
        XCTFail("No error to catch! - \(message)", file: file, line: line)
    } catch {
    }
}

func assertNoThrow<T>(_ expression: @autoclosure  () throws -> T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    do {
        let _ = try expression()
    } catch let error {
        XCTFail("Caught error: \(error) - \(message)", file: file, line: line)
    }
}

extension DateComponents {
    func addingTimeInterval(_ timeInterval: TimeInterval) -> DateComponents {
        let newDate = self.date!.addingTimeInterval(timeInterval)
        let newDateComponents = Calendar.current.dateComponents(in: TimeZone.currentFixed, from: newDate)
        return newDateComponents
    }
}
