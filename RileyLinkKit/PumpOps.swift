//
//  PumpOps.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/14/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit
import RileyLinkBLEKit


public class PumpOps {
    
    public let pumpState: PumpState
    public let device: RileyLinkBLEDevice
    
    public init(pumpState: PumpState, device: RileyLinkBLEDevice) {
        self.pumpState = pumpState
        self.device = device
    }
    
    public func pressButton(_ completion: @escaping (Either<String, Error>) -> Void) {
        device.runSession(withName: "Press button") { (session) -> Void in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            let message = PumpMessage(packetType: .carelink, address: self.pumpState.pumpID, messageType: .buttonPress, messageBody: ButtonPressCarelinkMessageBody(buttonType: .down))
            do {
                _ = try ops.runCommandWithArguments(message)
                completion(.success("Success."))
            } catch let error {
                DispatchQueue.main.async { () -> Void in
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func getPumpModel(_ completion: @escaping (Either<String, Error>) -> Void)  {
        device.runSession(withName: "Get pump model") { (session) -> Void in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            do {
                let model = try ops.getPumpModelNumber()

                self.pumpState.pumpModel = PumpModel(rawValue: model)

                DispatchQueue.main.async { () -> Void in
                    completion(.success(model))
                }
            } catch let error {
                DispatchQueue.main.async { () -> Void in
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func readSettings(_ completion: @escaping (Either<ReadSettingsCarelinkMessageBody, Error>) -> Void)  {
        device.runSession(withName: "Read pump settings") { (session) -> Void in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            do {
                let response: ReadSettingsCarelinkMessageBody = try ops.messageBody(to: .readSettings)
                DispatchQueue.main.async { () -> Void in
                    completion(.success(response))
                }
            } catch let error {
                DispatchQueue.main.async { () -> Void in
                    completion(.failure(error))
                }
            }
        }
    }

    
    public func getBatteryVoltage(_ completion: @escaping (Either<GetBatteryCarelinkMessageBody, Error>) -> Void)  {
        device.runSession(withName: "Get battery voltage") { (session) -> Void in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            do {
                let response: GetBatteryCarelinkMessageBody = try ops.messageBody(to: .getBattery)
                DispatchQueue.main.async { () -> Void in
                    completion(.success(response))
                }
            } catch let error {
                DispatchQueue.main.async { () -> Void in
                    completion(.failure(error))
                }
            }
        }
    }

    /**
     Reads the current insulin reservoir volume.
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter completion: A closure called after the command is complete. This closure takes a single Result argument:
        - success(units, date): The reservoir volume, in units of insulin, and DateCompoments representing the pump's clock
        - failure(error): An error describing why the command failed
     */
    public func readRemainingInsulin(_ completion: @escaping (Either<(units: Double, date: DateComponents), Error>) -> Void) {
        device.runSession(withName: "Read remaining insulin") { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)

            do {
                let pumpModel = try ops.getPumpModel()

                let clockResp: ReadTimeCarelinkMessageBody = try ops.messageBody(to: .readTime)

                let response: ReadRemainingInsulinMessageBody = try ops.messageBody(to: .readRemainingInsulin)

                completion(.success((units: response.getUnitsRemainingForStrokes(pumpModel.strokesPerUnit), date: clockResp.dateComponents)))
            } catch let error {
                completion(.failure(error))
            }
        }
    }

    /**
     Fetches history entries which occurred on or after the specified date.
 
     It is possible for Minimed Pumps to non-atomically append multiple history entries with the same timestamp, for example, `BolusWizardEstimatePumpEvent` may appear and be read before `BolusNormalPumpEvent` is written. Therefore, the `startDate` parameter is used as part of an inclusive range, leaving the client to manage the possibility of duplicates.

     History timestamps are reconciled with UTC based on the `timeZone` property of PumpState, as well as recorded clock change events.

     - parameter startDate:  The earliest date of events to retrieve
     - parameter completion: A closure called after the command is complete. This closure takes a single Result argument:
        - success(events): An array of fetched history entries, in ascending order of insertion
        - failure(error):  An error describing why the command failed

     */
    public func getHistoryEvents(since startDate: Date, completion: @escaping (Either<(events: [TimestampedHistoryEvent], pumpModel: PumpModel), Error>) -> Void) {
        device.runSession(withName: "Get history events") { (session) -> Void in
            NSLog("History fetching task started.")
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            do {
                let (events, pumpModel) = try ops.getHistoryEvents(since: startDate)
                DispatchQueue.main.async { () -> Void in
                    completion(.success(events: events, pumpModel: pumpModel))
                }
            } catch let error {
                DispatchQueue.main.async { () -> Void in
                    completion(.failure(error))
                }
            }
        }
    }

    /**
     Fetches glucose history entries which occurred on or after the specified date.
     
     History timestamps are reconciled with UTC based on the `timeZone` property of PumpState, as well as recorded clock change events.
     
     - parameter startDate:  The earliest date of events to retrieve
     - parameter completion: A closure called after the command is complete. This closure takes a single Result argument:
     - success(events): An array of fetched history entries, in ascending order of insertion
     - failure(error):  An error describing why the command failed
     
     */
    public func getGlucoseHistoryEvents(since startDate: Date, completion: @escaping (Either<[TimestampedGlucoseEvent], Error>) -> Void) {
        device.runSession(withName: "Get glucose history events") { (session) -> Void in
            NSLog("Glucose history fetching task started.")
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            do {
                let events = try ops.getGlucoseHistoryEvents(since: startDate)
                DispatchQueue.main.async { () -> Void in
                    completion(.success(events))
                }
            } catch let error {
                DispatchQueue.main.async { () -> Void in
                    completion(.failure(error))
                }
            }
        }
    }
    
    /**
 
 */
    public func writeGlucoseHistoryTimestamp(completion: @escaping (Either<Bool, Error>) -> Void) {
        device.runSession(withName: "Write glucose history timestamp") { (session) -> Void in
            NSLog("Write glucose history timestamp started.")
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            do {
                _ = try ops.writeGlucoseHistoryTimestamp()
                DispatchQueue.main.async { () -> Void in
                    completion(.success(true))
                }
            } catch let error {
                DispatchQueue.main.async { () -> Void in
                    completion(.failure(error))
                }
            }
        }
    }

    /**
     Reads the pump's clock
 
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter completion: A closure called after the command is complete. This closure takes a single Result argument:
        - success(clock): The pump's clock
        - failure(error): An error describing why the command failed
     */
    public func readTime(_ completion: @escaping (Either<DateComponents, Error>) -> Void) {
        device.runSession(withName: "Read pump time") { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)

            do {
                let response: ReadTimeCarelinkMessageBody = try ops.messageBody(to: .readTime)

                completion(.success(response.dateComponents))
            } catch let error {
                completion(.failure(error))
            }
        }
    }


    /**
     Reads clock, reservoir, battery, bolusing, and suspended state from pump

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter completion: A closure called after the command is complete. This closure takes a single Result argument:
        - success(status): A structure describing the current status of the pump
        - failure(error): An error describing why the command failed
     */
    public func readPumpStatus(_ completion: @escaping (Either<PumpStatus, Error>) -> Void) {
        device.runSession(withName: "Read pump status") { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)

            do {
                let response: PumpStatus = try ops.readPumpStatus()
                completion(.success(response))
            } catch let error {
                completion(.failure(error))
            }
        }
    }


    /**
     Sets a bolus
     
     *Note: Use at your own risk!*
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
     
     - parameter units:              The number of units to deliver
     - parameter cancelExistingTemp: If true, additional pump commands will be issued to clear any running temp basal. Defaults to false.
     - parameter completion:         A closure called after the command is complete. This closure takes a single argument:
        - error: An error describing why the command failed
     */
    public func setNormalBolus(units: Double, cancelExistingTemp: Bool = false, completion: @escaping (_ error: SetBolusError?) -> Void) {
        device.runSession(withName: "Set normal bolus") { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            completion(ops.setNormalBolus(units: units, cancelExistingTemp: cancelExistingTemp))
        }
    }
    
    /**
     Changes the current temporary basal rate
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
     
     - parameter unitsPerHour: The new basal rate, in Units per hour
     - parameter duration:     The duration of the rate
     - parameter completion:   A closure called after the command is complete. This closure takes a single Result argument:
        - success(messageBody): The pump message body describing the new basal rate
        - failure(error):       An error describing why the command failed
     */
    public func setTempBasal(rate unitsPerHour: Double, duration: TimeInterval, completion: @escaping (Either<ReadTempBasalCarelinkMessageBody, Error>) -> Void) {
        device.runSession(withName: "Set temp basal") { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            
            do {
                let response = try ops.setTempBasal(unitsPerHour, duration: duration)
                completion(.success(response))
            } catch let error {
                completion(.failure(error))
            }
        }
    }
    
    /**
     Changes the pump's clock to the specified date components
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
     
     - parameter generator:  A closure which returns the desired date components. An exeception is raised if the date components are not valid.
     - parameter completion: A closure called after the command is complete. This closure takes a single argument:
        - error: An error describing why the command failed
     */
    public func setTime(_ generator: @escaping () -> DateComponents, completion: @escaping (_ error: Error?) -> Void) {
        device.runSession(withName: "Set time") { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            
            do {
                try ops.changeTime {
                    PumpMessage(packetType: .carelink, address: self.pumpState.pumpID, messageType: .changeTime, messageBody: ChangeTimeCarelinkMessageBody(dateComponents: generator())!)
                }
                completion(nil)
            } catch let error {
                completion(error)
            }
        }
    }

    /**
     Pairs the pump with a virtual "watchdog" device to enable it to broadcast periodic status packets. Only pump models x23 and up are supported.
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter watchdogID: A 3-byte address for the watchdog device.
     - parameter completion: A closure called after the command is complete. This closure takes a single argument:
        - error: An error describing why the command failed.
     */
    public func changeWatchdogMarriageProfile(toWatchdogID watchdogID: Data, completion: @escaping (_ error: Error?) -> Void) {
        device.runSession(withName: "Change watchdog marriage profile") { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)

            var lastError: Error?

            for _ in 0..<3 {
                do {
                    try ops.changeWatchdogMarriageProfile(watchdogID)

                    lastError = nil
                    break
                } catch let error {
                    lastError = error
                }
            }

            completion(lastError)
        }
    }

    func tuneRadio(for region: PumpRegion = .northAmerica, completion: @escaping (Either<FrequencyScanResults, Error>) -> Void)  {
        device.runSession(withName: "Tune pump") { (session) -> Void in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            do {
                try ops.configureRadio(for: region)
                let response = try ops.tuneRadio(for: region)
                DispatchQueue.main.async { () -> Void in
                    completion(.success(response))
                }
            } catch let error {
                DispatchQueue.main.async { () -> Void in
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func setRXFilterMode(_ mode: RXFilterMode, completion: @escaping (_ error: Error?) -> Void) {
        device.runSession(withName: "Set RX filter mode") { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            
            do {
                try ops.setRXFilterMode(mode)
                completion(nil)
            } catch let error {
                completion(error)
            }
        }
    }
}
