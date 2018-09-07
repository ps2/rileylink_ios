//
//  OmnipodPumpManager.swift
//  OmniKit
//
//  Created by Pete Schwamb on 8/4/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import HealthKit
import LoopKit
import RileyLinkKit
import RileyLinkBLEKit
import os.log

public class OmnipodPumpManager: RileyLinkPumpManager, PumpManager {
    
    public var pumpBatteryChargeRemaining: Double?
    
    public var pumpRecordsBasalProfileStartEvents = false
    
    public var pumpReservoirCapacity: Double = 200
    
    public var pumpTimeZone: TimeZone {
        return state.podState.timeZone
    }

    public func assertCurrentPumpData() {
        queue.async {
            let semaphore = DispatchSemaphore(value: 0)
            let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            self.podComms.runSession(withName: "Get status for currentPumpData assertion", using: rileyLinkSelector) { (result) in
                do {
                    switch result {
                    case .success(let session):
                        let status = try session.getStatus()
                        self.podStatusReceived(status: status)
                    case .failure(let error):
                        throw error
                    }
                } catch let error {
                    self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
                }
                semaphore.signal()
            }
            semaphore.wait()
            self.finalizeDoses {
                self.pumpManagerDelegate?.pumpManagerRecommendsLoop(self)
            }

        }
    }
    
    public func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (Double, Date) -> Void, completion: @escaping (Error?) -> Void) {
        
        finalizeDoses()
        
        let rileyLinkSelector = rileyLinkDeviceProvider.firstConnectedDevice
        podComms.runSession(withName: "Bolus", using: rileyLinkSelector) { (result) in
            
            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(SetBolusError.certain(error))
                return
            }
            
            let podStatus: StatusResponse
            
            do {
                podStatus = try session.getStatus()
            } catch let error {
                completion(SetBolusError.certain(error as? PodCommsError ?? PodCommsError.commsError(error: error)))
                return
            }
            
            guard !podStatus.deliveryStatus.bolusing else {
                completion(SetBolusError.certain(PodCommsError.unfinalizedBolus))
                return
            }
            
            willRequest(units, Date())
            
            let result = session.bolus(units: units)
            
            switch result {
            case .success(let status):
                self.podStatusReceived(status: status)
                completion(nil)
            case .certainFailure(let error):
                completion(SetBolusError.certain(error))
            case .uncertainFailure(let error):
                completion(SetBolusError.uncertain(error))
            }
        }
    }
    
    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        finalizeDoses()
        
        let rileyLinkSelector = rileyLinkDeviceProvider.firstConnectedDevice
        podComms.runSession(withName: "Enact Temp Basal", using: rileyLinkSelector) { (result) in
            do {
                switch result {
                case .success(let session):
                    try session.setTempBasal(rate: unitsPerHour, duration: duration, confidenceReminder: false, programReminderInterval: 0)
                    let basalStart = Date()
                    let dose = DoseEntry(type: .basal, startDate: basalStart, endDate: basalStart.addingTimeInterval(duration), value: unitsPerHour, unit: .unitsPerHour)
                    completion(PumpManagerResult.success(dose))
                case .failure(let error):
                    self.log.error("Failed to set temp basal: %{public}@", String(describing: error))
                    throw error
                }
            } catch (let error) {
                completion(PumpManagerResult.failure(error))
            }
        }
    }
    
    public func updateBLEHeartbeatPreference() {
        return
    }
    
    public static let managerIdentifier: String = "Omnipod"
    
    public init(state: OmnipodPumpManagerState, rileyLinkDeviceProvider: RileyLinkDeviceProvider, rileyLinkConnectionManager: RileyLinkConnectionManager? = nil) {
        self.state = state
        
        super.init(rileyLinkDeviceProvider: rileyLinkDeviceProvider, rileyLinkConnectionManager: rileyLinkConnectionManager)
        
        // Pod communication
        self.podComms = PodComms(podState: state.podState, delegate: self)
    }

    public required convenience init?(rawState: PumpManager.RawStateValue) {
        guard let state = OmnipodPumpManagerState(rawValue: rawState),
            let connectionManagerState = state.rileyLinkConnectionManagerState else
        {
            return nil
        }
        
        let rileyLinkConnectionManager = RileyLinkConnectionManager(state: connectionManagerState)
        
        self.init(state: state, rileyLinkDeviceProvider: rileyLinkConnectionManager.deviceProvider, rileyLinkConnectionManager: rileyLinkConnectionManager)
        
        rileyLinkConnectionManager.delegate = self
    }
    
    public var rawState: PumpManager.RawStateValue {
        return state.rawValue
    }
    
    override public var rileyLinkConnectionManagerState: RileyLinkConnectionManagerState? {
        get {
            return state.rileyLinkConnectionManagerState
        }
        set {
            state.rileyLinkConnectionManagerState = newValue
        }
    }

    // TODO: apply lock
    public private(set) var state: OmnipodPumpManagerState {
        didSet {
            pumpManagerDelegate?.pumpManagerDidUpdateState(self)
        }
    }
    
    public weak var pumpManagerDelegate: PumpManagerDelegate?
    
    public let log = OSLog(category: "OmnipodPumpManager")
    
    public static let localizedTitle = NSLocalizedString("Omnipod", comment: "Generic title of the omnipod pump manager")
    
    public var localizedTitle: String {
        return String(format: NSLocalizedString("Omnipod", comment: "Omnipod title"))
    }
    
    override public func deviceTimerDidTick(_ device: RileyLinkDevice) {
        self.pumpManagerDelegate?.pumpManagerBLEHeartbeatDidFire(self)
    }
    
    private func finalizeDoses(_ completion: (() -> Void)? = nil) {
        let storageHandler = { (pumpEvents: [NewPumpEvent]) -> Bool in
            let semaphore = DispatchSemaphore(value: 0)
            var success = false
            self.pumpManagerDelegate?.pumpManager(self, didReadPumpEvents: pumpEvents, completion: { (error) in
                success = error == nil
                semaphore.signal()
            })
            semaphore.wait()
            return success
        }
        podComms.finalizeDoses(storageHandler: storageHandler) {
            completion?()
        }
    }
    
    private func podStatusReceived(status: StatusResponse) {
        pumpManagerDelegate?.pumpManager(self, didReadReservoirValue: status.reservoirLevel, at: Date()) { _ in
            // Ignore result
        }
    }
    
    // MARK: - CustomDebugStringConvertible
    
    override public var debugDescription: String {
        return [
            "## OmnipodPumpManager",
            "pumpBatteryChargeRemaining: \(String(reflecting: pumpBatteryChargeRemaining))",
            "state: \(state.debugDescription)",
            "",
            "podComms: \(String(reflecting: podComms))",
            "",
            super.debugDescription,
            ].joined(separator: "\n")
    }
    
    // MARK: - Configuration
    
    // MARK: Pump
    
    public private(set) var podComms: PodComms!
    
    // TODO
    public func getStateForDevice(_ device: RileyLinkDevice, completion: @escaping (_ deviceState: DeviceState, _ podComms: PodComms) -> Void) {
        queue.async {
            completion(self.deviceStates[device.peripheralIdentifier, default: DeviceState()], self.podComms)
        }
    }
}



extension OmnipodPumpManager: PodCommsDelegate {
    public func podComms(_ podComms: PodComms, didChange state: PodState) {
        self.state.podState = state
    }
}

