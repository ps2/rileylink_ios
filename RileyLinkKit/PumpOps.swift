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
    
    public func pressButton(completion: (Either<String, ErrorType>) -> Void) {
        device.runSession { (session) -> Void in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            let message = PumpMessage(packetType: .Carelink, address: self.pumpState.pumpID, messageType: .ButtonPress, messageBody: ButtonPressCarelinkMessageBody(buttonType: .Down))
            do {
                try ops.runCommandWithArguments(message)
                completion(.Success("Success."))
            } catch let error {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion(.Failure(error))
                })
            }
        }
    }
    
    public func getPumpModel(completion: (Either<String, ErrorType>) -> Void)  {
        device.runSession { (session) -> Void in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            do {
                let model = try ops.getPumpModelNumber()
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion(.Success(model))
                })
            } catch let error {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion(.Failure(error))
                })
            }
        }
    }
    
    public func getBatteryVoltage(completion: (Either<GetBatteryCarelinkMessageBody, ErrorType>) -> Void)  {
        device.runSession { (session) -> Void in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            do {
                let response: GetBatteryCarelinkMessageBody = try ops.getMessageBodyWithType(.GetBattery)
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion(.Success(response))
                })
            } catch let error {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion(.Failure(error))
                })
            }
        }
    }
    
    public func getHistoryEventsSinceDate(startDate: NSDate, completion: (Either<(events: [PumpEvent], pumpModel: PumpModel), ErrorType>) -> Void) {
        device.runSession { (session) -> Void in
            NSLog("History fetching task started.")
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            do {
                let (events, pumpModel) = try ops.getHistoryEventsSinceDate(startDate)
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion(.Success(events: events, pumpModel: pumpModel))
                })
            } catch let error {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion(.Failure(error))
                })
            }
        }
    }
    
    /**
     Sets a bolus
     
     *Note: Use at your own risk!*
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
     
     - parameter units:      The number of units to deliver
     - parameter completion: A closure called after the command is complete. This closure takes a single argument:
     - error: An error describing why the command failed
     */
    public func setNormalBolus(units: Double, completion: (error: ErrorType?) -> Void) {
        device.runSession { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            
            
            do {
                let pumpModel = try ops.getPumpModel()
                
                let message = PumpMessage(packetType: .Carelink, address: self.pumpState.pumpID, messageType: .Bolus, messageBody: BolusCarelinkMessageBody(units: units, strokesPerUnit: pumpModel.strokesPerUnit))
                
                try ops.runCommandWithArguments(message)
                
                completion(error: nil)
            } catch let error {
                completion(error: error)
            }
        }
    }
    
    /**
     Changes the current temporary basal rate
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
     
     - parameter unitsPerHour: The new basal rate, in Units per hour
     - parameter duration:     The duration of the rate
     - parameter completion:   A closure called after the command is complete. This closure takes a single Result argument:
     - Success(messageBody): The pump message body describing the new basal rate
     - Failure(error):       An error describing why the command failed
     */
    public func setTempBasal(unitsPerHour: Double, duration: NSTimeInterval, completion: (Either<ReadTempBasalCarelinkMessageBody, ErrorType>) -> Void) {
        device.runSession { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            
            do {
                let response = try ops.setTempBasal(unitsPerHour, duration: duration)
                completion(.Success(response))
            } catch let error {
                completion(.Failure(error))
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
    public func setTime(generator: () -> NSDateComponents, completion: (error: ErrorType?) -> Void) {
        device.runSession { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            
            do {
                try ops.changeTime {
                    PumpMessage(packetType: .Carelink, address: self.pumpState.pumpID, messageType: .ChangeTime, messageBody: ChangeTimeCarelinkMessageBody(dateComponents: generator())!)
                }
                completion(error: nil)
            } catch let error {
                completion(error: error)
            }
        }
    }
    
    // TODO: Internal scope
    public func tunePump(completion: (Either<FrequencyScanResults, ErrorType>) -> Void)  {
        device.runSession { (session) -> Void in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            do {
                let response = try ops.scanForPump()
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion(.Success(response))
                })
            } catch let error {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion(.Failure(error))
                })
            }
        }
    }
    
    public func setRXFilterMode(mode: RXFilterMode, completion: (error: ErrorType?) -> Void) {
        device.runSession { (session) in
            let ops = PumpOpsSynchronous(pumpState: self.pumpState, session: session)
            
            do {
                try ops.setRXFilterMode(mode)
                completion(error: nil)
            } catch let error {
                completion(error: error)
            }
        }
    }
}
