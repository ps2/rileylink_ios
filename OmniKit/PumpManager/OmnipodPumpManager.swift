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
    
    private var lastPumpDataReportDate: Date?
    
    public func assertCurrentPumpData() {
        
        let pumpStatusAgeTolerance = TimeInterval(minutes: 4)
        
        
        guard (lastPumpDataReportDate ?? .distantPast).timeIntervalSinceNow < -pumpStatusAgeTolerance else {
            return
        }

        queue.async {
            let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            self.podComms.runSession(withName: "Get status for currentPumpData assertion", using: rileyLinkSelector) { (result) in
                do {
                    switch result {
                    case .success(let session):
                        let status = try session.getStatus()
                        
                        session.finalizeDoses(deliveryStatus: status.deliveryStatus, storageHandler: { (doses) -> Bool in
                            return self.store(doses: doses)
                        })

                        if let reservoirLevel = status.reservoirLevel {
                            let semaphore = DispatchSemaphore(value: 0)
                            self.pumpManagerDelegate?.pumpManager(self, didReadReservoirValue: reservoirLevel, at: Date()) { (_) in
                                semaphore.signal()
                            }
                            semaphore.wait()
                        }
                        self.pumpManagerDelegate?.pumpManagerRecommendsLoop(self)
                    case .failure(let error):
                        throw error
                    }
                } catch let error {
                    self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
                }
            }
        }
    }

    
    public func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (Double, Date) -> Void, completion: @escaping (Error?) -> Void) {
        
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
            
            session.finalizeDoses(deliveryStatus: podStatus.deliveryStatus, storageHandler: { ( _ ) -> Bool in
                return false
            })
            
            willRequest(units, Date())
            
            let result = session.bolus(units: units)
            
            switch result {
            case .success:
                completion(nil)
            case .certainFailure(let error):
                completion(SetBolusError.certain(error))
            case .uncertainFailure(let error):
                completion(SetBolusError.uncertain(error))
            }
        }
    }
    
    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        //completion(PumpManagerResult.failure(PodCommsError.emptyResponse))
        
        let rileyLinkSelector = rileyLinkDeviceProvider.firstConnectedDevice
        podComms.runSession(withName: "Enact Temp Basal", using: rileyLinkSelector) { (result) in
            self.log.info("Enact temp basal %.03fU/hr for %ds", unitsPerHour, Int(duration))
            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(PumpManagerResult.failure(error))
                return
            }
            
            do {
                let podStatus = try session.getStatus()
                if podStatus.deliveryStatus.tempBasalRunning {
                    let cancelStatus = try session.cancelDelivery(deliveryType: .tempBasal, beepType: .noBeep)

                    guard !cancelStatus.deliveryStatus.tempBasalRunning else {
                        throw PodCommsError.unfinalizedTempBasal
                    }
                }
                
                session.finalizeDoses(deliveryStatus: podStatus.deliveryStatus, storageHandler: { ( _ ) -> Bool in
                    return false
                })
                
                if duration < .ulpOfOne {
                    // 0 duration temp basals are used to cancel any existing temp basal
                    let cancelTime = Date()
                    let dose = DoseEntry(type: .basal, startDate: cancelTime, endDate: cancelTime, value: 0, unit: .unitsPerHour)
                    completion(PumpManagerResult.success(dose))
                } else {
                    let result = session.setTempBasal(rate: unitsPerHour, duration: duration, confidenceReminder: false, programReminderInterval: 0)
                    let basalStart = Date()
                    let dose = DoseEntry(type: .basal, startDate: basalStart, endDate: basalStart.addingTimeInterval(duration), value: unitsPerHour, unit: .unitsPerHour)
                    switch result {
                    case .success:
                        completion(PumpManagerResult.success(dose))
                    case .uncertainFailure(let error):
                        self.log.error("Temp basal uncertain error: %@", String(describing: error))
                        completion(PumpManagerResult.success(dose))
                    case .certainFailure(let error):
                        completion(PumpManagerResult.failure(error))
                    }
                }
            } catch let error {
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
    
    
    // MARK: - CustomDebugStringConvertible
    
    override public var debugDescription: String {
        return [
            "## OmnipodPumpManager",
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
}

extension OmnipodPumpManager: PodCommsDelegate {
    
    public func store(doses: [UnfinalizedDose]) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        self.pumpManagerDelegate?.pumpManager(self, didReadPumpEvents: doses.map { NewPumpEvent($0) }, completion: { (error) in
            if let error = error {
                self.log.error("Error storing pod events: %@", String(describing: error))
            } else {
                self.log.error("Stored pod events: %@", String(describing: doses))
            }
            success = error == nil
            semaphore.signal()
        })
        semaphore.wait()
        
        if success {
            self.lastPumpDataReportDate = Date()
        }
        return success
    }
    
    public func podComms(_ podComms: PodComms, didChange state: PodState) {
        self.state.podState = state
    }
}

