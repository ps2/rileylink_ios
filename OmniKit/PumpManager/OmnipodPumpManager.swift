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

public enum ReservoirAlertState {
    case ok
    case lowReservoir
    case empty
}

public protocol PodStateObserver: class {
    func podStateDidUpdate(_ state: PodState?)
}

public enum OmnipodPumpManagerError: Error {
    case noPodPaired
    case podAlreadyPaired
}

extension OmnipodPumpManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noPodPaired:
            return LocalizedString("No pod paired", comment: "Error message shown when no pod is paired")
        case .podAlreadyPaired:
            return nil
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .noPodPaired:
            return nil
        case .podAlreadyPaired:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .noPodPaired:
            return LocalizedString("Please pair a new pod", comment: "Recover suggestion shown when no pod is paired")
        case .podAlreadyPaired:
            return nil
        }
    }
}


public class OmnipodPumpManager: RileyLinkPumpManager, PumpManager {

    public var pumpRecordsBasalProfileStartEvents = false
    
    public var pumpReservoirCapacity: Double = 200
    
    private var lastPumpDataReportDate: Date?
    
    // MARK: - PumpManagerStatusObserver
    private var statusObservers = WeakObserverSet<PumpManagerStatusObserver>()
    
    public func addStatusObserver(_ observer: PumpManagerStatusObserver) {
        queue.async {
            self.statusObservers.add(observer)
        }
    }
    
    public func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
        queue.async {
            self.statusObservers.remove(observer)
        }
    }
    
    private func notifyStatusObservers() {
        let status = self.status
        pumpManagerDelegate?.pumpManager(self, didUpdateStatus: status)
        for observer in statusObservers {
            observer.pumpManager(self, didUpdateStatus: status)
        }
    }

    
    // MARK: - PodStateObserver
    private var podStateObservers = WeakObserverSet<PodStateObserver>()
    
    public func addPodStateObserver(_ observer: PodStateObserver) {
        queue.async {
            self.podStateObservers.add(observer)
        }
    }
    
    public func removePodStateObserver(_ observer: PodStateObserver) {
        queue.async {
            self.podStateObservers.remove(observer)
        }
    }
    
    private func notifyPodStateObservers() {
        let podState = self.state.podState
        for observer in podStateObservers {
            observer.podStateDidUpdate(podState)
        }
    }

    
    private struct MessageLogEntry: CustomStringConvertible {
        var description: String {
            return "\(timestamp) \(messageDirection) \(data.hexadecimalString)"
        }
        
        enum MessageDirection {
            case send
            case receive
        }
        
        let messageDirection: MessageDirection
        let timestamp: Date
        let data: Data
    }
    
    private var messageLog = [MessageLogEntry]()
    
    public func updateBLEHeartbeatPreference() {
        return
    }
    
    public static let managerIdentifier: String = "Omnipod"
    
    public static func roundToDeliveryIncrement(_ units: Double) -> Double {
        return round(units * pulsesPerUnit) / pulsesPerUnit
    }
    
    public init(state: OmnipodPumpManagerState, rileyLinkDeviceProvider: RileyLinkDeviceProvider, rileyLinkConnectionManager: RileyLinkConnectionManager? = nil) {
        self.state = state
        
        super.init(rileyLinkDeviceProvider: rileyLinkDeviceProvider, rileyLinkConnectionManager: rileyLinkConnectionManager)
        
        // Pod communication
        if let podState = state.podState {
            self.podComms = PodComms(podState: podState, delegate: self, messageLogger: self)
        } else {
            self.podComms = nil
        }
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
            
            if oldValue.podState?.suspended != state.podState?.suspended ||
                oldValue.timeZone != state.timeZone
            {
                notifyStatusObservers()
            }
        }
    }
    
    public var device: HKDevice {
        if let podState = state.podState {
            return HKDevice(
                name: type(of: self).managerIdentifier,
                manufacturer: "Insulet",
                model: "Eros",
                hardwareVersion: nil,
                firmwareVersion: podState.piVersion,
                softwareVersion: String(OmniKitVersionNumber),
                localIdentifier: String(format:"%04X", podState.address),
                udiDeviceIdentifier: nil
            )
        } else {
            return HKDevice(
                name: type(of: self).managerIdentifier,
                manufacturer: "Insulet",
                model: "Eros",
                hardwareVersion: nil,
                firmwareVersion: nil,
                softwareVersion: String(OmniKitVersionNumber),
                localIdentifier: nil,
                udiDeviceIdentifier: nil
            )
        }
    }
    
    private var suspendStateTransitioning: Bool = false {
        didSet {
            notifyStatusObservers()
        }
    }
    
    private var suspendState: PumpManagerStatus.SuspendState {
        guard let podState = state.podState else {
            return .none
        }
        
        if suspendStateTransitioning {
            return podState.suspended ? .resuming : .suspending
        } else {
            return podState.suspended ? .suspended : .none
        }
    }
    
    private var bolusStateTransitioning: Bool = false {
        didSet {
            notifyStatusObservers()
        }
    }
    
    private var bolusState: PumpManagerStatus.BolusState {
        guard let podState = state.podState else {
            return .none
        }
        if let bolus = podState.unfinalizedBolus, bolus.finishTime.timeIntervalSinceNow < 0 {
            // TODO: return progress
            return bolusStateTransitioning ? .canceling : .inProgress(Float(bolus.progress))
        } else {
            return bolusStateTransitioning ? .initiating : .none
        }
    }
    
    public var status: PumpManagerStatus {
        return PumpManagerStatus(
            timeZone: state.timeZone,
            device: device,
            pumpBatteryChargeRemaining: nil,
            suspendState: suspendState,
            bolusState: bolusState)
    }
    
    public weak var pumpManagerDelegate: PumpManagerDelegate?
    
    public let log = OSLog(category: "OmnipodPumpManager")
    
    public static let localizedTitle = LocalizedString("Omnipod", comment: "Generic title of the omnipod pump manager")
    
    public var localizedTitle: String {
        return String(format: LocalizedString("Omnipod", comment: "Omnipod title"))
    }
    
    override public func deviceTimerDidTick(_ device: RileyLinkDevice) {
        self.pumpManagerDelegate?.pumpManagerBLEHeartbeatDidFire(self)
    }
    
    // MARK: - CustomDebugStringConvertible
    
    override public var debugDescription: String {
        var lines = [
            "## OmnipodPumpManager",
            state.debugDescription,
            "",
            String(describing: podComms!),
            super.debugDescription,
            "",
            ]
        
        lines.append("### MessageLog")
        for entry in messageLog {
            lines.append("* " + entry.description)
        }
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Pod comms
    private(set) var podComms: PodComms?
    
    public var hasPairedPod: Bool {
        return podComms != nil
    }
    
    // Paired, primed, cannula inserted, and not faulting
    public var hasActivePod: Bool {
        if let podState = state.podState, let podProgressStatus = podState.podProgressStatus {
            return podState.fault == nil && podProgressStatus.readyForDelivery
        } else {
            return false
        }
    }
    
    public func forgetPod() {
        queue.async {
            self.podComms = nil
            self.state.podState = nil
            self.notifyPodStateObservers()
            self.messageLog.removeAll()
        }
    }
    
    // MARK: Testing
    public func jumpStartPod(address: UInt32, lot: UInt32, tid: UInt32, schedule: BasalSchedule, fault: PodInfoFaultEvent? = nil, startDate: Date? = nil) {
        let connectionManager = RileyLinkConnectionManager(autoConnectIDs: [])
        let start = startDate ?? Date()
        let expire = start.addingTimeInterval(.days(3))
        var podState = PodState(address: address, activatedAt: start, expiresAt: expire, piVersion: "jumpstarted", pmVersion: "jumpstarted", lot: lot, tid: tid)
        podState.fault = fault
        self.state = OmnipodPumpManagerState(podState: podState, timeZone: TimeZone.currentFixed, basalSchedule: schedule, rileyLinkConnectionManagerState: connectionManager.state)
    }
    
    // MARK: - Pairing
    
    public func pair(completion: @escaping (Error?) -> Void) {
        queue.async {
            guard self.podComms == nil else {
                completion(OmnipodPumpManagerError.podAlreadyPaired)
                return
            }
            
            let deviceSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            
            PodComms.pair(using: deviceSelector, timeZone: .currentFixed, messageLogger: self) { (result) in
                switch(result) {
                case .success(let podState):
                    self.state.podState = podState
                    self.podComms = PodComms(podState: podState, delegate: self, messageLogger: self)
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }
    
    public func configureAndPrimePod(completion: @escaping (Error?) -> Void) {
        
        queue.async {
            guard let podComms = self.podComms else {
                completion(OmnipodPumpManagerError.noPodPaired)
                return
            }

            let deviceSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            
            podComms.runSession(withName: "Configure and prime pod", using: deviceSelector) { (result) in
                switch result {
                case .success(let session):
                    do {
                        try session.configureAndPrimePod()
                        completion(nil)
                    } catch let error {
                        completion(error)
                    }
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }
    
    public func finishPrime(completion: @escaping (Error?) -> Void) {
        queue.async {
            guard let podComms = self.podComms else {
                completion(OmnipodPumpManagerError.noPodPaired)
                return
            }
            
            let deviceSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            
            podComms.runSession(withName: "Finish prime", using: deviceSelector) { (result) in
                switch result {
                case .success(let session):
                    do {
                        try session.finishPrime()
                        completion(nil)
                    } catch let error {
                        completion(error)
                    }
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }
    
    public func insertCannula(completion: @escaping (Error?) -> Void) {
        queue.async {
            guard let podComms = self.podComms else
            {
                completion(OmnipodPumpManagerError.noPodPaired)
                return
            }
            
            let deviceSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            let timeZone = self.state.timeZone
            
            podComms.runSession(withName: "Insert cannula", using: deviceSelector) { (result) in
                switch result {
                case .success(let session):
                    do {
                        let scheduleOffset = timeZone.scheduleOffset(forDate: Date())
                        try session.insertCannula(basalSchedule: self.state.basalSchedule, scheduleOffset: scheduleOffset)
                        completion(nil)
                    } catch let error {
                        completion(error)
                    }
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }
    
    // MARK: - Pump Commands

    public func assertCurrentPumpData() {
        let pumpStatusAgeTolerance = TimeInterval(minutes: 4)
        
        queue.async {
            guard let podComms = self.podComms, let podState = self.state.podState, podState.fault == nil else {
                return
            }
            
            guard (self.lastPumpDataReportDate ?? .distantPast).timeIntervalSinceNow < -pumpStatusAgeTolerance else {
                return
            }
            
            self.getPodStatus(podComms: podComms) { (response) in
                if case .success = response {
                    self.log.info("Recommending Loop")
                    self.pumpManagerDelegate?.pumpManagerRecommendsLoop(self)
                }
            }
        }
    }
    
    public func refreshStatus(completion: ((_ result: PumpManagerResult<StatusResponse>) -> Void)? = nil) {
        queue.async {
            guard let podComms = self.podComms, let podState = self.state.podState, podState.fault == nil else {
                return
            }
            
            self.getPodStatus(podComms: podComms, completion: completion)
        }
    }

    // PumpManager queue only
    private func getPodStatus(podComms: PodComms, completion: ((_ result: PumpManagerResult<StatusResponse>) -> Void)? = nil) {
        
        let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        podComms.runSession(withName: "Get pod status", using: rileyLinkSelector) { (result) in
            do {
                switch result {
                case .success(let session):
                    let status = try session.getStatus()
                    
                    session.storeFinalizedDoses() { (doses) -> Bool in
                        return self.store(doses: doses)
                    }

                    if let reservoirLevel = status.reservoirLevel {
                        let semaphore = DispatchSemaphore(value: 0)
                        self.pumpManagerDelegate?.pumpManager(self, didReadReservoirValue: reservoirLevel, at: Date()) { (_) in
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                    completion?(PumpManagerResult.success(status))
                case .failure(let error):
                    throw error
                }
            } catch let error {
                completion?(PumpManagerResult.failure(error))
                self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
            }
        }
    }
    
    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
        queue.async {
            guard self.hasActivePod, let podComms = self.podComms else {
                completion(OmnipodPumpManagerError.noPodPaired)
                return
            }
            
            let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            podComms.runSession(withName: "Suspend", using: rileyLinkSelector) { (result) in
                
                let session: PodCommsSession
                switch result {
                case .success(let s):
                    session = s
                case .failure(let error):
                    completion(error)
                    return
                }
                
                defer { self.suspendStateTransitioning = false }
                self.suspendStateTransitioning = true

                do {
                    let _ = try session.cancelDelivery(deliveryType: .all, beepType: .noBeep)
                    completion(nil)
                    
                    session.storeFinalizedDoses() { (doses) -> Bool in
                        return self.store(doses: doses)
                    }

                } catch (let error) {
                    completion(error)
                }
            }
        }
    }
    
    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
        queue.async {
            guard self.hasActivePod, let podComms = self.podComms else {
                completion(OmnipodPumpManagerError.noPodPaired)
                return
            }
            let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            podComms.runSession(withName: "Resume", using: rileyLinkSelector) { (result) in
                
                let session: PodCommsSession
                switch result {
                case .success(let s):
                    session = s
                case .failure(let error):
                    completion(error)
                    return
                }
                
                defer { self.suspendStateTransitioning = false }
                self.suspendStateTransitioning = true
                
                do {
                    let scheduleOffset = self.state.timeZone.scheduleOffset(forDate: Date())
                    let _ = try session.resumeBasal(schedule: self.state.basalSchedule, scheduleOffset: scheduleOffset)
                    completion(nil)
                } catch (let error) {
                    completion(error)
                }
            }
        }
    }
    
    
    public func acknowledgeAlarms(_ alarmsToAcknowledge: PodAlarmState, completion: @escaping (_ status: StatusResponse?) -> Void) {
        queue.async {
            guard self.hasActivePod, let podComms = self.podComms else {
                completion(nil)
                return
            }
            let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            podComms.runSession(withName: "Acknowledge Alarms", using: rileyLinkSelector) { (result) in
                let session: PodCommsSession
                switch result {
                case .success(let s):
                    session = s
                case .failure:
                    completion(nil)
                    return
                }
                
                do {
                    let status = try session.acknowledgeAlarms(alarms: alarmsToAcknowledge)
                    completion(status)
                } catch {
                    completion(nil)
                }
            }
        }
    }
    
    public func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (DoseEntry) -> Void, completion: @escaping (Error?) -> Void) {
        queue.async {
            guard self.hasActivePod, let podComms = self.podComms else {
                completion(OmnipodPumpManagerError.noPodPaired)
                return
            }

            // Round to nearest supported volume
            let enactUnits = OmnipodPumpManager.roundToDeliveryIncrement(units)
            
            let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            podComms.runSession(withName: "Bolus", using: rileyLinkSelector) { (result) in
                
                let session: PodCommsSession
                switch result {
                case .success(let s):
                    session = s
                case .failure(let error):
                    completion(SetBolusError.certain(error))
                    return
                }
                
                var podStatus: StatusResponse
                
                do {
                    podStatus = try session.getStatus()
                } catch let error {
                    completion(SetBolusError.certain(error as? PodCommsError ?? PodCommsError.commsError(error: error)))
                    return
                }
                
                // If pod suspended, resume basal before bolusing
                if podStatus.deliveryStatus == .suspended {
                    do {
                        let scheduleOffset = self.state.timeZone.scheduleOffset(forDate: Date())
                        podStatus = try session.resumeBasal(schedule: self.state.basalSchedule, scheduleOffset: scheduleOffset)
                    } catch let error {
                        completion(SetBolusError.certain(error as? PodCommsError ?? PodCommsError.commsError(error: error)))
                        return
                    }
                    self.notifyStatusObservers()
                }
                
                guard !podStatus.deliveryStatus.bolusing else {
                    completion(SetBolusError.certain(PodCommsError.unfinalizedBolus))
                    return
                }
                
                defer { self.bolusStateTransitioning = false }
                self.bolusStateTransitioning = true
                
                let date = Date()
                let endDate = date.addingTimeInterval(enactUnits / bolusDeliveryRate)
                let dose = DoseEntry(type: .bolus, startDate: date, endDate: endDate, value: enactUnits, unit: .units)
                willRequest(dose)
                
                let result = session.bolus(units: enactUnits)
                
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
    }
    
    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        queue.async {
            guard self.hasActivePod, let podComms = self.podComms else {
                completion(PumpManagerResult.failure(OmnipodPumpManagerError.noPodPaired))
                return
            }

            // Round to nearest supported rate
            let rate = OmnipodPumpManager.roundToDeliveryIncrement(unitsPerHour)
            
            let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            podComms.runSession(withName: "Enact Temp Basal", using: rileyLinkSelector) { (result) in
                self.log.info("Enact temp basal %.03fU/hr for %ds", rate, Int(duration))
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
                    
                    if podStatus.deliveryStatus == .suspended {
                        throw PodCommsError.podSuspended
                    }
                    
                    if podStatus.deliveryStatus.bolusing {
                        throw PodCommsError.unfinalizedBolus
                    }

                    if podStatus.deliveryStatus.tempBasalRunning {
                        let cancelStatus = try session.cancelDelivery(deliveryType: .tempBasal, beepType: .noBeep)

                        guard !cancelStatus.deliveryStatus.tempBasalRunning else {
                            throw PodCommsError.unfinalizedTempBasal
                        }
                    }
                    
                    if duration < .ulpOfOne {
                        // 0 duration temp basals are used to cancel any existing temp basal
                        let cancelTime = Date()
                        let dose = DoseEntry(type: .basal, startDate: cancelTime, endDate: cancelTime, value: 0, unit: .unitsPerHour)
                        completion(PumpManagerResult.success(dose))
                    } else {
                        let result = session.setTempBasal(rate: rate, duration: duration, confidenceReminder: false, programReminderInterval: 0)
                        let basalStart = Date()
                        let dose = DoseEntry(type: .basal, startDate: basalStart, endDate: basalStart.addingTimeInterval(duration), value: rate, unit: .unitsPerHour)
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
                    self.log.error("Error during temp basal: %@", String(describing: error))
                    completion(PumpManagerResult.failure(error))
                }
            }
        }
    }
    
    public func setTime(completion: @escaping (Error?) -> Void) {
        
        let timeZone = TimeZone.currentFixed
        
        queue.async {
            guard self.hasActivePod, let podComms = self.podComms else {
                completion(OmnipodPumpManagerError.noPodPaired)
                return
            }

            let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            podComms.runSession(withName: "Set time zone", using: rileyLinkSelector) { (result) in
                switch result {
                case .success(let session):
                    do {
                        let _ = try session.setTime(timeZone: timeZone, basalSchedule: self.state.basalSchedule, date: Date())
                        self.state.timeZone = timeZone
                        completion(nil)
                    } catch let error {
                        completion(error)
                    }
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }

    public func setBasalSchedule(_ schedule: BasalSchedule, completion: @escaping (Error?) -> Void) {
        queue.async {
            guard self.hasActivePod, let podComms = self.podComms else {
                completion(OmnipodPumpManagerError.noPodPaired)
                return
            }

            let timeZone = self.state.timeZone
            
            podComms.runSession(withName: "Save Basal Profile", using: self.rileyLinkDeviceProvider.firstConnectedDevice) { (result) in
                do {
                    switch result {
                    case .success(let session):
                        let scheduleOffset = timeZone.scheduleOffset(forDate: Date())
                        let _ = try session.cancelDelivery(deliveryType: .all, beepType: .noBeep)
                        let _ = try session.setBasalSchedule(schedule: schedule, scheduleOffset: scheduleOffset, confidenceReminder: false, programReminderInterval: 0)
                        completion(nil)
                    case .failure(let error):
                        throw error
                    }
                } catch let error {
                    self.log.error("Save basal profile failed: %{public}@", String(describing: error))
                    completion(error)
                }
            }
        }
    }

    public func deactivatePod(completion: @escaping (Error?) -> Void) {
        queue.async {
            guard let podComms = self.podComms else {
                completion(OmnipodPumpManagerError.noPodPaired)
                return
            }
            
            let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            podComms.runSession(withName: "Deactivate pod", using: rileyLinkSelector) { (result) in
                switch result {
                case .success(let session):
                    do {
                        try session.deactivatePod()
                        completion(nil)
                    } catch let error {
                        completion(error)
                    }
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }
    
    public func testingCommands(completion: @escaping (Error?) -> Void) {
        queue.async {
            guard self.hasActivePod, let podComms = self.podComms else {
                completion(OmnipodPumpManagerError.noPodPaired)
                return
            }
            
            let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
            podComms.runSession(withName: "Testing Commands", using: rileyLinkSelector) { (result) in
                switch result {
                case .success(let session):
                    do {
                        let _ = try session.testingCommands()
                        completion(nil)
                    } catch let error {
                        completion(error)
                    }
                case .failure(let error):
                    completion(error)
                }
            }
        }
    }
}

// MARK: -

extension OmnipodPumpManager: MessageLogger {
    func didSend(_ message: Data) {
        messageLog.append(MessageLogEntry(messageDirection: .send, timestamp: Date(), data: message))
    }
    
    func didReceive(_ message: Data) {
        messageLog.append(MessageLogEntry(messageDirection: .receive, timestamp: Date(), data: message))
    }
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
    
    func podComms(_ podComms: PodComms, didChange state: PodState) {
        self.state.podState = state
        notifyPodStateObservers()
    }
}

