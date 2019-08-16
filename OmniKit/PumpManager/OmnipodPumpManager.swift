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
import UserNotifications
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
    case podAlreadyPrimed
    case notReadyForPrime
    case notReadyForCannulaInsertion
}

extension OmnipodPumpManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noPodPaired:
            return LocalizedString("No pod paired", comment: "Error message shown when no pod is paired")
        case .podAlreadyPrimed:
            return LocalizedString("Pod already primed", comment: "Error message shown when prime is attempted, but pod is already primed")
        case .podAlreadyPaired:
            return LocalizedString("Pod already paired", comment: "Error message shown when user cannot pair because pod is already paired")
        case .notReadyForPrime:
            return LocalizedString("Pod is not in a state ready for priming.", comment: "Error message when prime fails because the pod is in an unexpected state")
        case .notReadyForCannulaInsertion:
            return LocalizedString("Pod is not in a state ready for cannula insertion.", comment: "Error message when cannula insertion fails because the pod is in an unexpected state")
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .noPodPaired:
            return nil
        case .podAlreadyPrimed:
            return nil
        case .podAlreadyPaired:
            return nil
        case .notReadyForPrime:
            return nil
        case .notReadyForCannulaInsertion:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .noPodPaired:
            return LocalizedString("Please pair a new pod", comment: "Recover suggestion shown when no pod is paired")
        case .podAlreadyPrimed:
            return nil
        case .podAlreadyPaired:
            return nil
        case .notReadyForPrime:
            return nil
        case .notReadyForCannulaInsertion:
            return nil
        }
    }
}


public class OmnipodPumpManager: RileyLinkPumpManager {
    public init(state: OmnipodPumpManagerState, rileyLinkDeviceProvider: RileyLinkDeviceProvider, rileyLinkConnectionManager: RileyLinkConnectionManager? = nil) {
        self.lockedState = Locked(state)
        self.lockedPodComms = Locked(PodComms(podState: state.podState))
        super.init(rileyLinkDeviceProvider: rileyLinkDeviceProvider, rileyLinkConnectionManager: rileyLinkConnectionManager)

        self.podComms.delegate = self
        self.podComms.messageLogger = self
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

    private var podComms: PodComms {
        get {
            return lockedPodComms.value
        }
        set {
            lockedPodComms.value = newValue
        }
    }
    private let lockedPodComms: Locked<PodComms>

    private let podStateObservers = WeakSynchronizedSet<PodStateObserver>()

    public var state: OmnipodPumpManagerState {
        return lockedState.value
    }

    private func setState(_ changes: (_ state: inout OmnipodPumpManagerState) -> Void) -> Void {
        return setStateWithResult(changes)
    }

    private func mutateState(_ changes: (_ state: inout OmnipodPumpManagerState) -> Void) -> OmnipodPumpManagerState {
        return setStateWithResult({ (state) -> OmnipodPumpManagerState in
            changes(&state)
            return state
        })
    }

    private func setStateWithResult<ReturnType>(_ changes: (_ state: inout OmnipodPumpManagerState) -> ReturnType) -> ReturnType {
        var oldValue: OmnipodPumpManagerState!
        var returnType: ReturnType!
        let newValue = lockedState.mutate { (state) in
            oldValue = state
            returnType = changes(&state)
        }

        guard oldValue != newValue else {
            return returnType
        }

        if oldValue.podState != newValue.podState {
            podStateObservers.forEach { (observer) in
                observer.podStateDidUpdate(newValue.podState)
            }

            if oldValue.podState?.lastInsulinMeasurements?.reservoirVolume != newValue.podState?.lastInsulinMeasurements?.reservoirVolume {
                if let lastInsulinMeasurements = newValue.podState?.lastInsulinMeasurements, let reservoirVolume = lastInsulinMeasurements.reservoirVolume {
                    self.pumpDelegate.notify({ (delegate) in
                        self.log.info("DU: updating reservoir level %{public}@", String(describing: reservoirVolume))
                        delegate?.pumpManager(self, didReadReservoirValue: reservoirVolume, at: lastInsulinMeasurements.validTime) { _ in }
                    })
                }
            }
        }


        // Ideally we ensure that oldValue.rawValue != newValue.rawValue, but the types aren't
        // defined as equatable
        pumpDelegate.notify { (delegate) in
            delegate?.pumpManagerDidUpdateState(self)
        }

        let oldStatus = status(for: oldValue)
        let newStatus = status(for: newValue)

        if oldStatus != newStatus {
            notifyStatusObservers(oldStatus: oldStatus)
        }

        // Reschedule expiration notification if relevant values change
        if oldValue.expirationReminderDate != newValue.expirationReminderDate ||
            oldValue.podState?.expiresAt != newValue.podState?.expiresAt
        {
            schedulePodExpirationNotification(for: newValue)
        }

        return returnType
    }
    private let lockedState: Locked<OmnipodPumpManagerState>

    private let statusObservers = WeakSynchronizedSet<PumpManagerStatusObserver>()

    private func notifyStatusObservers(oldStatus: PumpManagerStatus) {
        let status = self.status
        pumpDelegate.notify { (delegate) in
            delegate?.pumpManager(self, didUpdate: status, oldStatus: oldStatus)
        }
        statusObservers.forEach { (observer) in
            observer.pumpManager(self, didUpdate: status, oldStatus: oldStatus)
        }
    }

    private let pumpDelegate = WeakSynchronizedDelegate<PumpManagerDelegate>()

    public let log = OSLog(category: "OmnipodPumpManager")

    // MARK: - RileyLink Updates

    override public var rileyLinkConnectionManagerState: RileyLinkConnectionManagerState? {
        get {
            return state.rileyLinkConnectionManagerState
        }
        set {
            setState { (state) in
                state.rileyLinkConnectionManagerState = newValue
            }
        }
    }

    override public func deviceTimerDidTick(_ device: RileyLinkDevice) {
        pumpDelegate.notify { (delegate) in
            delegate?.pumpManagerBLEHeartbeatDidFire(self)
        }
    }

    // MARK: - CustomDebugStringConvertible

    override public var debugDescription: String {
        let lines = [
            "## OmnipodPumpManager",
            "podComms: \(String(reflecting: podComms))",
            "state: \(String(reflecting: state))",
            "status: \(String(describing: status))",
            "podStateObservers.count: \(podStateObservers.cleanupDeallocatedElements().count)",
            "statusObservers.count: \(statusObservers.cleanupDeallocatedElements().count)",
            super.debugDescription,
        ]
        return lines.joined(separator: "\n")
    }
}

extension OmnipodPumpManager {
    // MARK: - PodStateObserver
    
    public func addPodStateObserver(_ observer: PodStateObserver, queue: DispatchQueue) {
        podStateObservers.insert(observer, queue: queue)
    }
    
    public func removePodStateObserver(_ observer: PodStateObserver) {
        podStateObservers.removeElement(observer)
    }

    private func updateBLEHeartbeatPreference() {
        dispatchPrecondition(condition: .notOnQueue(delegateQueue))

        rileyLinkDeviceProvider.timerTickEnabled = self.state.isPumpDataStale || pumpDelegate.call({ (delegate) -> Bool in
            return delegate?.pumpManagerMustProvideBLEHeartbeat(self) == true
        })
    }

    private func status(for state: OmnipodPumpManagerState) -> PumpManagerStatus {
        return PumpManagerStatus(
            timeZone: state.timeZone,
            device: device(for: state),
            pumpBatteryChargeRemaining: nil,
            basalDeliveryState: basalDeliveryState(for: state),
            bolusState: bolusState(for: state)
        )
    }

    private func device(for state: OmnipodPumpManagerState) -> HKDevice {
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

    private func basalDeliveryState(for state: OmnipodPumpManagerState) -> PumpManagerStatus.BasalDeliveryState {
        guard let podState = state.podState else {
            return .suspended(state.lastPumpDataReportDate ?? .distantPast)
        }

        switch state.suspendEngageState {
        case .engaging:
            return .suspending
        case .disengaging:
            return .resuming
        case .stable:
            break
        }

        switch state.tempBasalEngageState {
        case .engaging:
            return .initiatingTempBasal
        case .disengaging:
            return .cancelingTempBasal
        case .stable:
            if let tempBasal = podState.unfinalizedTempBasal, !tempBasal.isFinished {
                return .tempBasal(DoseEntry(tempBasal))
            }
            switch podState.suspendState {
            case .resumed(let date):
                return .active(date)
            case .suspended(let date):
                return .suspended(date)
            }
        }
    }

    private func bolusState(for state: OmnipodPumpManagerState) -> PumpManagerStatus.BolusState {
        guard let podState = state.podState else {
            return .none
        }

        switch state.bolusEngageState {
        case .engaging:
            return .initiating
        case .disengaging:
            return .canceling
        case .stable:
            if let bolus = podState.unfinalizedBolus, !bolus.isFinished {
                return .inProgress(DoseEntry(bolus))
            }
        }
        return .none
    }

    // Thread-safe
    public var hasActivePod: Bool {
        // TODO: Should this check be done automatically before each session?
        return state.hasActivePod
    }

    // Thread-safe
    public var expirationReminderDate: Date? {
        get {
            return state.expirationReminderDate
        }
        set {
            // Setting a new value reschedules notifications
            setState { (state) in
                state.expirationReminderDate = newValue
            }
        }
    }

    // MARK: - Notifications

    static let podExpirationNotificationIdentifier = "Omnipod:\(LoopNotificationCategory.pumpExpired.rawValue)"

    func schedulePodExpirationNotification(for state: OmnipodPumpManagerState) {
        guard let expirationReminderDate = state.expirationReminderDate,
            expirationReminderDate.timeIntervalSinceNow > 0,
            let expiresAt = state.podState?.expiresAt
        else {
            pumpDelegate.notify { (delegate) in
                delegate?.clearNotification(for: self, identifier: OmnipodPumpManager.podExpirationNotificationIdentifier)
            }
            return
        }

        let content = UNMutableNotificationContent()

        let timeBetweenNoticeAndExpiration = expiresAt.timeIntervalSince(expirationReminderDate)

        let formatter = DateComponentsFormatter()
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full

        let timeUntilExpiration = formatter.string(from: timeBetweenNoticeAndExpiration) ?? ""

        content.title = NSLocalizedString("Pod Expiration Notice", comment: "The title for pod expiration notification")

        content.body = String(format: NSLocalizedString("Time to replace your pod! Your pod will expire in %1$@", comment: "The format string for pod expiration notification body (1: time until expiration)"), timeUntilExpiration)
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = LoopNotificationCategory.pumpExpired.rawValue
        content.threadIdentifier = LoopNotificationCategory.pumpExpired.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: expirationReminderDate.timeIntervalSinceNow,
            repeats: false
        )

        pumpDelegate.notify { (delegate) in
            delegate?.scheduleNotification(for: self, identifier: OmnipodPumpManager.podExpirationNotificationIdentifier, content: content, trigger: trigger)
        }
    }

    // MARK: - Pod comms

    // Does not support concurrent callers. Not thread-safe.
    private func forgetPod(completion: @escaping () -> Void) {
        let resetPodState = { (_ state: inout OmnipodPumpManagerState) in
            self.podComms = PodComms(podState: nil)
            self.podComms.delegate = self
            self.podComms.messageLogger = self

            state.podState = nil
            state.messageLog.erase()
            state.expirationReminderDate = nil
        }

        // TODO: PodState shouldn't be mutated outside of the session queue
        // TODO: Consider serializing the entire forget-pod path instead of relying on the UI to do it

        let state = mutateState { (state) in
            state.podState?.finalizeFinishedDoses()
        }

        if let dosesToStore = state.podState?.dosesToStore {
            store(doses: dosesToStore, completion: { error in
                self.setState({ (state) in
                    if error != nil {
                        state.unstoredDoses.append(contentsOf: dosesToStore)
                    }

                    resetPodState(&state)
                })
                completion()
            })
        } else {
            setState { (state) in
                resetPodState(&state)
            }

            completion()
        }
    }
    
    // MARK: Testing
    #if targetEnvironment(simulator)
    private func jumpStartPod(address: UInt32, lot: UInt32, tid: UInt32, fault: PodInfoFaultEvent? = nil, startDate: Date? = nil, mockFault: Bool) {
        let start = startDate ?? Date()
        var podState = PodState(address: address, piVersion: "jumpstarted", pmVersion: "jumpstarted", lot: lot, tid: tid)
        podState.setupProgress = .podConfigured
        podState.activatedAt = start
        
        let fault = mockFault ? try? PodInfoFaultEvent(encodedData: Data(hexadecimalString: "020d0000000e00c36a020703ff020900002899080082")!) : nil
        podState.fault = fault

        self.podComms = PodComms(podState: podState)

        setState({ (state) in
            state.podState = podState
            state.expirationReminderDate = start + .hours(70)
        })
    }
    #endif
    
    // MARK: - Pairing

    // Called on the main thread
    public func pairAndPrime(completion: @escaping (PumpManagerResult<TimeInterval>) -> Void) {
        #if targetEnvironment(simulator)
        // If we're in the simulator, create a mock PodState
        let mockFaultDuringPairing = false
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(2)) {
            self.jumpStartPod(address: 0x1f0b3557, lot: 40505, tid: 6439, mockFault: mockFaultDuringPairing)
            let fault: PodInfoFaultEvent? = self.setStateWithResult({ (state) in
                state.podState?.setupProgress = .priming
                return state.podState?.fault
            })
            if mockFaultDuringPairing {
                completion(.failure(PodCommsError.podFault(fault: fault!)))
            } else {
                let mockPrimeDuration = TimeInterval(.seconds(3))
                completion(.success(mockPrimeDuration))
            }
        }
        #else
        let deviceSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        let configureAndPrimeSession = { (result: PodComms.SessionRunResult) in
            switch result {
            case .success(let session):
                // We're on the session queue
                session.assertOnSessionQueue()

                self.log.default("Beginning pod configuration and prime")

                // Clean up any previously un-stored doses if needed
                let unstoredDoses = self.state.unstoredDoses
                if self.store(doses: unstoredDoses, in: session) {
                    self.setState({ (state) in
                        state.unstoredDoses.removeAll()
                    })
                }

                do {
                    let primeFinishedAt = try session.prime()
                    completion(.success(primeFinishedAt))
                } catch let error {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }

        let needsPairing = setStateWithResult({ (state) -> PumpManagerResult<Bool> in
            guard let podState = state.podState else {
                return .success(true) // Needs pairing
            }

            guard podState.setupProgress.primingNeeded else {
                return .failure(OmnipodPumpManagerError.podAlreadyPrimed)
            }

            // If still need configuring, run pair()
            return .success(podState.setupProgress == .addressAssigned)
        })

        switch needsPairing {
        case .success(true):
            self.log.default("Pairing pod before priming")

            self.podComms.pair(using: deviceSelector, timeZone: .currentFixed, messageLogger: self) { (session) in
                // Calls completion
                configureAndPrimeSession(session)
            }
        case .success(false):
            self.log.default("Pod already paired. Continuing.")

            self.podComms.runSession(withName: "Configure and prime pod", using: deviceSelector) { (result) in
                // Calls completion
                configureAndPrimeSession(result)
            }
        case .failure(let error):
            completion(.failure(error))
        }
        #endif
    }

    // Called on the main thread
    public func insertCannula(completion: @escaping (PumpManagerResult<TimeInterval>) -> Void) {
        #if targetEnvironment(simulator)
        let mockDelay = TimeInterval(seconds: 3)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + mockDelay) {
            let result = self.setStateWithResult({ (state) -> PumpManagerResult<TimeInterval> in
                // Mock fault
                //            let fault = try! PodInfoFaultEvent(encodedData: Data(hexadecimalString: "020d0000000e00c36a020703ff020900002899080082")!)
                //            self.state.podState?.fault = fault
                //            return .failure(PodCommsError.podFault(fault: fault))

                // Mock success
                state.podState?.setupProgress = .completed
                return .success(mockDelay)
            })

            completion(result)
        }
        #else
        let preError = setStateWithResult({ (state) -> OmnipodPumpManagerError? in
            guard let podState = state.podState, let expiresAt = podState.expiresAt, podState.readyForCannulaInsertion else
            {
                return .notReadyForCannulaInsertion
            }

            state.expirationReminderDate = expiresAt.addingTimeInterval(-Pod.expirationReminderAlertDefaultTimeBeforeExpiration)

            guard podState.setupProgress.needsCannulaInsertion else {
                return .podAlreadyPaired
            }

            return nil
        })

        if let error = preError {
            completion(.failure(error))
            return
        }

        let deviceSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        let timeZone = self.state.timeZone

        self.podComms.runSession(withName: "Insert cannula", using: deviceSelector) { (result) in
            switch result {
            case .success(let session):
                do {
                    if self.state.podState?.setupProgress.needsInitialBasalSchedule == true {
                        let scheduleOffset = timeZone.scheduleOffset(forDate: Date())
                        try session.programInitialBasalSchedule(self.state.basalSchedule, scheduleOffset: scheduleOffset)

                        session.dosesForStorage() { (doses) -> Bool in
                            return self.store(doses: doses, in: session)
                        }
                    }

                    let finishWait = try session.insertCannula()

                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + finishWait) {
                        // Runs a new session
                        self.checkCannulaInsertionFinished()
                    }
                    completion(.success(finishWait))
                } catch let error {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
        #endif
    }

    private func checkCannulaInsertionFinished() {
        let deviceSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        self.podComms.runSession(withName: "Check cannula insertion finished", using: deviceSelector) { (result) in
            switch result {
            case .success(let session):
                do {
                    try session.checkInsertionCompleted()
                } catch let error {
                    self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
                }
            case .failure(let error):
                self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
            }
        }
    }

    public func refreshStatus(completion: ((_ result: PumpManagerResult<StatusResponse>) -> Void)? = nil) {
        guard self.hasActivePod else {
            completion?(.failure(OmnipodPumpManagerError.noPodPaired))
            return
        }

        self.getPodStatus(storeDosesOnSuccess: false, completion: completion)
    }

    // MARK: - Pump Commands

    private func getPodStatus(storeDosesOnSuccess: Bool, completion: ((_ result: PumpManagerResult<StatusResponse>) -> Void)? = nil) {
        guard state.podState?.unfinalizedBolus?.isFinished != false else {
            self.log.info("Skipping status request due to unfinalized bolus in progress.")
            completion?(.failure(PodCommsError.unfinalizedBolus))
            return
        }
        
        let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        podComms.runSession(withName: "Get pod status", using: rileyLinkSelector) { (result) in
            do {
                switch result {
                case .success(let session):
                    let status = try session.getStatus()
                    if storeDosesOnSuccess {
                        session.dosesForStorage({ (doses) -> Bool in
                            self.store(doses: doses, in: session)
                        })
                    }
                    completion?(.success(status))
                case .failure(let error):
                    throw error
                }
            } catch let error {
                completion?(.failure(error))
                self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
            }
        }
    }

    public func acknowledgeAlerts(_ alertsToAcknowledge: AlertSet, completion: @escaping (_ alerts: [AlertSlot: PodAlert]?) -> Void) {
        guard self.hasActivePod else {
            completion(nil)
            return
        }

        let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        self.podComms.runSession(withName: "Acknowledge Alarms", using: rileyLinkSelector) { (result) in
            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure:
                completion(nil)
                return
            }

            do {
                let alerts = try session.acknowledgeAlerts(alerts: alertsToAcknowledge)
                completion(alerts)
            } catch {
                completion(nil)
            }
        }
    }

    public func setTime(completion: @escaping (Error?) -> Void) {
        
        let timeZone = TimeZone.currentFixed

        let preError = setStateWithResult { (state) -> Error? in
            guard state.hasActivePod else {
                return OmnipodPumpManagerError.noPodPaired
            }

            guard state.podState?.unfinalizedBolus?.isFinished != false else {
                return PodCommsError.unfinalizedBolus
            }

            return nil
        }

        if let error = preError {
            completion(error)
            return
        }

        let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        self.podComms.runSession(withName: "Set time zone", using: rileyLinkSelector) { (result) in
            switch result {
            case .success(let session):
                do {
                    let _ = try session.setTime(timeZone: timeZone, basalSchedule: self.state.basalSchedule, date: Date())
                    self.setState { (state) in
                        state.timeZone = timeZone
                    }
                    completion(nil)
                } catch let error {
                    completion(error)
                }
            case .failure(let error):
                completion(error)
            }
        }
    }

    public func setBasalSchedule(_ schedule: BasalSchedule, completion: @escaping (Error?) -> Void) {
        let shouldContinue = setStateWithResult({ (state) -> PumpManagerResult<Bool> in
            guard state.hasActivePod else {
                // If there's no active pod yet, save the basal schedule anyway
                state.basalSchedule = schedule
                return .success(false)
            }

            guard state.podState?.unfinalizedBolus?.isFinished != false else {
                return .failure(PodCommsError.unfinalizedBolus)
            }

            return .success(true)
        })

        switch shouldContinue {
        case .success(true):
            break
        case .success(false):
            completion(nil)
            return
        case .failure(let error):
            completion(error)
            return
        }

        let timeZone = self.state.timeZone

        self.podComms.runSession(withName: "Save Basal Profile", using: self.rileyLinkDeviceProvider.firstConnectedDevice) { (result) in
            do {
                switch result {
                case .success(let session):
                    let scheduleOffset = timeZone.scheduleOffset(forDate: Date())
                    let result = session.cancelDelivery(deliveryType: .all, beepType: .noBeep)
                    switch result {
                    case .certainFailure(let error):
                        throw error
                    case .uncertainFailure(let error):
                        throw error
                    case .success:
                        break
                    }
                    let _ = try session.setBasalSchedule(schedule: schedule, scheduleOffset: scheduleOffset, acknowledgementBeep: false, completionBeep: false, programReminderInterval: 0)

                    self.setState { (state) in
                        state.basalSchedule = schedule
                    }
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

    // Called on the main thread.
    // The UI is responsible for serializing calls to this method;
    // it does not handle concurrent calls.
    public func deactivatePod(forgetPodOnFail: Bool, completion: @escaping (Error?) -> Void) {
        #if targetEnvironment(simulator)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(2)) {

            self.forgetPod(completion: {
                completion(nil)
            })
        }
        #else
        guard self.state.podState != nil else {
            if forgetPodOnFail {
                forgetPod(completion: {
                    completion(OmnipodPumpManagerError.noPodPaired)
                })
            } else {
                completion(OmnipodPumpManagerError.noPodPaired)
            }
            return
        }

        let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        self.podComms.runSession(withName: "Deactivate pod", using: rileyLinkSelector) { (result) in
            switch result {
            case .success(let session):
                do {
                    try session.deactivatePod()

                    self.forgetPod(completion: {
                        completion(nil)
                    })
                } catch let error {
                    if forgetPodOnFail {
                        self.forgetPod(completion: {
                            completion(error)
                        })
                    } else {
                        completion(error)
                    }
                }
            case .failure(let error):
                if forgetPodOnFail {
                    self.forgetPod(completion: {
                        completion(error)
                    })
                } else {
                    completion(error)
                }
            }
        }
        #endif
    }

    public func testingCommands(completion: @escaping (Error?) -> Void) {
        guard self.hasActivePod else {
            completion(OmnipodPumpManagerError.noPodPaired)
            return
        }

        let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        self.podComms.runSession(withName: "Testing Commands", using: rileyLinkSelector) { (result) in
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

// MARK: - PumpManager
extension OmnipodPumpManager: PumpManager {

    public static let managerIdentifier: String = "Omnipod"

    public static let localizedTitle = LocalizedString("Omnipod", comment: "Generic title of the omnipod pump manager")

    public var supportedBolusVolumes: [Double] {
        // 0.05 units for rates between 0.05-30U/hr
        // 0 is not a supported bolus volume
        return (1...600).map { Double($0) / Double(Pod.pulsesPerUnit) }
    }

    public var supportedBasalRates: [Double] {
        // 0.05 units for rates between 0.05-30U/hr
        // 0 is not a supported scheduled basal rate
        return (1...600).map { Double($0) / Double(Pod.pulsesPerUnit) }
    }

    public func roundToSupportedBolusVolume(units: Double) -> Double {
        // We do support rounding a 0 U volume to 0
        return supportedBolusVolumes.last(where: { $0 <= units }) ?? 0
    }

    public func roundToSupportedBasalRate(unitsPerHour: Double) -> Double {
        // We do support rounding a 0 U/hr rate to 0
        return supportedBasalRates.last(where: { $0 <= unitsPerHour }) ?? 0
    }

    public var maximumBasalScheduleEntryCount: Int {
        return Pod.maximumBasalScheduleEntryCount
    }

    public var minimumBasalScheduleEntryDuration: TimeInterval {
        return Pod.minimumBasalScheduleEntryDuration
    }

    public var pumpRecordsBasalProfileStartEvents: Bool {
        return false
    }

    public var pumpReservoirCapacity: Double {
        return Pod.reservoirCapacity
    }

    public var lastReconciliation: Date? {
        return self.state.podState?.lastInsulinMeasurements?.validTime
    }

    public var status: PumpManagerStatus {
        // Acquire the lock just once
        let state = self.state

        return status(for: state)
    }

    public var rawState: PumpManager.RawStateValue {
        return state.rawValue
    }

    public var pumpManagerDelegate: PumpManagerDelegate? {
        get {
            return pumpDelegate.delegate
        }
        set {
            pumpDelegate.delegate = newValue

            // TODO: is there still a scenario where this is required?
            // self.schedulePodExpirationNotification()
        }
    }

    public var delegateQueue: DispatchQueue! {
        get {
            return pumpDelegate.queue
        }
        set {
            pumpDelegate.queue = newValue
        }
    }

    // MARK: Methods

    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
        guard self.hasActivePod else {
            completion(OmnipodPumpManagerError.noPodPaired)
            return
        }

        let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        self.podComms.runSession(withName: "Suspend", using: rileyLinkSelector) { (result) in

            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(error)
                return
            }

            defer {
                self.setState({ (state) in
                    state.suspendEngageState = .stable
                })
            }
            self.setState({ (state) in
                state.suspendEngageState = .engaging
            })

            let result = session.cancelDelivery(deliveryType: .all, beepType: .noBeep)
            switch result {
            case .certainFailure(let error):
                completion(error)
            case .uncertainFailure(let error):
                completion(error)
            case .success:
                session.dosesForStorage() { (doses) -> Bool in
                    return self.store(doses: doses, in: session)
                }
                completion(nil)
            }
        }
    }

    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
        guard self.hasActivePod else {
            completion(OmnipodPumpManagerError.noPodPaired)
            return
        }

        let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        self.podComms.runSession(withName: "Resume", using: rileyLinkSelector) { (result) in

            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(error)
                return
            }

            defer {
                self.setState({ (state) in
                    state.suspendEngageState = .stable
                })
            }
            self.setState({ (state) in
                state.suspendEngageState = .disengaging
            })

            do {
                let scheduleOffset = self.state.timeZone.scheduleOffset(forDate: Date())
                let _ = try session.resumeBasal(schedule: self.state.basalSchedule, scheduleOffset: scheduleOffset)
                session.dosesForStorage() { (doses) -> Bool in
                    return self.store(doses: doses, in: session)
                }
                completion(nil)
            } catch (let error) {
                completion(error)
            }
        }
    }

    public func addStatusObserver(_ observer: PumpManagerStatusObserver, queue: DispatchQueue) {
        statusObservers.insert(observer, queue: queue)
    }

    public func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
        statusObservers.removeElement(observer)
    }

    public func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool) {
        rileyLinkDeviceProvider.timerTickEnabled = self.state.isPumpDataStale || mustProvideBLEHeartbeat
    }

    public func assertCurrentPumpData() {
        let shouldFetchStatus = setStateWithResult { (state) -> Bool? in
            guard state.hasActivePod else {
                return nil // No active pod
            }

            return state.isPumpDataStale
        }

        switch shouldFetchStatus {
        case .none:
            return // No active pod
        case true?:
            log.default("Fetching status because pumpData is too old")
            getPodStatus(storeDosesOnSuccess: true) { (response) in
                self.pumpDelegate.notify({ (delegate) in
                    switch response {
                    case .success:
                        self.log.default("Recommending Loop")
                        delegate?.pumpManagerRecommendsLoop(self)
                    case .failure(let error):
                        self.log.default("Not recommending Loop because pump data is stale: %@", String(describing: error))
                        if let error = error as? PumpManagerError {
                            delegate?.pumpManager(self, didError: error)
                        }
                    }
                })
            }
        case false?:
            log.default("Skipping status update because pumpData is fresh")
            pumpDelegate.notify { (delegate) in
                self.log.default("Recommending Loop")
                delegate?.pumpManagerRecommendsLoop(self)
            }
        }
    }

    public func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (DoseEntry) -> Void, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        guard self.hasActivePod else {
            completion(.failure(SetBolusError.certain(OmnipodPumpManagerError.noPodPaired)))
            return
        }

        // Round to nearest supported volume
        let enactUnits = roundToSupportedBolusVolume(units: units)

        let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        self.podComms.runSession(withName: "Bolus", using: rileyLinkSelector) { (result) in
            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(.failure(SetBolusError.certain(error)))
                return
            }

            var podStatus: StatusResponse

            do {
                podStatus = try session.getStatus()
            } catch let error {
                completion(.failure(SetBolusError.certain(error as? PodCommsError ?? PodCommsError.commsError(error: error))))
                return
            }

            // If pod suspended, resume basal before bolusing
            if podStatus.deliveryStatus == .suspended {
                do {
                    let scheduleOffset = self.state.timeZone.scheduleOffset(forDate: Date())
                    podStatus = try session.resumeBasal(schedule: self.state.basalSchedule, scheduleOffset: scheduleOffset)
                } catch let error {
                    completion(.failure(SetBolusError.certain(error as? PodCommsError ?? PodCommsError.commsError(error: error))))
                    return
                }
            }

            guard !podStatus.deliveryStatus.bolusing else {
                completion(.failure(SetBolusError.certain(PodCommsError.unfinalizedBolus)))
                return
            }

            // TODO: Move this to the top, since Loop is expecting a status change to cancel its loading indicator?
            defer {
                self.setState({ (state) in
                    state.bolusEngageState = .stable
                })
            }
            self.setState({ (state) in
                state.bolusEngageState = .engaging
            })

            let date = Date()
            let endDate = date.addingTimeInterval(enactUnits / Pod.bolusDeliveryRate)
            let dose = DoseEntry(type: .bolus, startDate: date, endDate: endDate, value: enactUnits, unit: .units)
            willRequest(dose)

            let result = session.bolus(units: enactUnits)
            session.dosesForStorage() { (doses) -> Bool in
                return self.store(doses: doses, in: session)
            }

            switch result {
            case .success:
                completion(.success(dose))
            case .certainFailure(let error):
                completion(.failure(SetBolusError.certain(error)))
            case .uncertainFailure(let error):
                completion(.failure(SetBolusError.uncertain(error)))
            }
        }
    }

    public func cancelBolus(completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {
        guard self.hasActivePod else {
            completion(.failure(OmnipodPumpManagerError.noPodPaired))
            return
        }

        let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        self.podComms.runSession(withName: "Cancel Bolus", using: rileyLinkSelector) { (result) in

            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(.failure(error))
                return
            }

            do {
                defer {
                    self.setState({ (state) in
                        state.bolusEngageState = .stable
                    })
                }
                self.setState({ (state) in
                    state.bolusEngageState = .disengaging
                })

                let result = session.cancelDelivery(deliveryType: .bolus, beepType: .noBeep)
                switch result {
                case .certainFailure(let error):
                    throw error
                case .uncertainFailure(let error):
                    throw error
                case .success(_, let canceledBolus):
                    session.dosesForStorage() { (doses) -> Bool in
                        return self.store(doses: doses, in: session)
                    }

                    let canceledDoseEntry: DoseEntry? = canceledBolus != nil ? DoseEntry(canceledBolus!) : nil
                    completion(.success(canceledDoseEntry))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        guard self.hasActivePod else {
            completion(.failure(OmnipodPumpManagerError.noPodPaired))
            return
        }

        // Round to nearest supported rate
        let rate = roundToSupportedBasalRate(unitsPerHour: unitsPerHour)

        let rileyLinkSelector = self.rileyLinkDeviceProvider.firstConnectedDevice
        self.podComms.runSession(withName: "Enact Temp Basal", using: rileyLinkSelector) { (result) in
            self.log.info("Enact temp basal %.03fU/hr for %ds", rate, Int(duration))
            let session: PodCommsSession
            switch result {
            case .success(let s):
                session = s
            case .failure(let error):
                completion(.failure(error))
                return
            }

            do {
                let preError = self.setStateWithResult({ (state) -> PodCommsError? in
                    if case .some(.suspended) = state.podState?.suspendState {
                        self.log.info("Not enacting temp basal because podState indicates pod is suspended.")
                        return .podSuspended
                    }

                    guard state.podState?.unfinalizedBolus?.isFinished != false else {
                        self.log.info("Not enacting temp basal because podState indicates unfinalized bolus in progress.")
                        return .unfinalizedBolus
                    }

                    return nil
                })

                if let error = preError {
                    throw error
                }

                let status: StatusResponse
                let canceledDose: UnfinalizedDose?

                let result = session.cancelDelivery(deliveryType: .tempBasal, beepType: .noBeep)
                switch result {
                case .certainFailure(let error):
                    throw error
                case .uncertainFailure(let error):
                    throw error
                case .success(let cancelTempStatus, let dose):
                    status = cancelTempStatus
                    canceledDose = dose
                }

                guard !status.deliveryStatus.bolusing else {
                    throw PodCommsError.unfinalizedBolus
                }

                guard status.deliveryStatus != .suspended else {
                    self.log.info("Canceling temp basal because status return indicates pod is suspended.")
                    throw PodCommsError.podSuspended
                }

                defer {
                    self.setState({ (state) in
                        state.tempBasalEngageState = .stable
                    })
                }

                if duration < .ulpOfOne {
                    // 0 duration temp basals are used to cancel any existing temp basal
                    self.setState({ (state) in
                        state.tempBasalEngageState = .disengaging
                    })
                    let cancelTime = canceledDose?.finishTime ?? Date()
                    let dose = DoseEntry(type: .tempBasal, startDate: cancelTime, endDate: cancelTime, value: 0, unit: .unitsPerHour)
                    session.dosesForStorage() { (doses) -> Bool in
                        return self.store(doses: doses, in: session)
                    }
                    completion(.success(dose))
                } else {
                    self.setState({ (state) in
                        state.tempBasalEngageState = .engaging
                    })

                    let result = session.setTempBasal(rate: rate, duration: duration, acknowledgementBeep: false, completionBeep: false, programReminderInterval: 0)
                    let basalStart = Date()
                    let dose = DoseEntry(type: .tempBasal, startDate: basalStart, endDate: basalStart.addingTimeInterval(duration), value: rate, unit: .unitsPerHour)
                    session.dosesForStorage() { (doses) -> Bool in
                        return self.store(doses: doses, in: session)
                    }
                    switch result {
                    case .success:
                        completion(.success(dose))
                    case .uncertainFailure(let error):
                        self.log.error("Temp basal uncertain error: %@", String(describing: error))
                        completion(.success(dose))
                    case .certainFailure(let error):
                        completion(.failure(error))
                    }
                }
            } catch let error {
                self.log.error("Error during temp basal: %@", String(describing: error))
                completion(.failure(error))
            }
        }
    }

    /// Returns a dose estimator for the current bolus, if one is in progress
    public func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> DoseProgressReporter? {
        if case .inProgress(let dose) = bolusState(for: self.state) {
            return PodDoseProgressEstimator(dose: dose, pumpManager: self, reportingQueue: dispatchQueue)
        }
        return nil
    }

    // This cannot be called from within the lockedState lock!
    func store(doses: [UnfinalizedDose], in session: PodCommsSession) -> Bool {
        session.assertOnSessionQueue()

        // We block the session until the data's confirmed stored by the delegate
        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        store(doses: doses) { (error) in
            success = (error == nil)
            semaphore.signal()
        }

        semaphore.wait()

        if success {
            setState { (state) in
                state.lastPumpDataReportDate = Date()
            }
        }
        return success
    }

    func store(doses: [UnfinalizedDose], completion: @escaping (_ error: Error?) -> Void) {
        let lastPumpReconciliation = lastReconciliation

        pumpDelegate.notify { (delegate) in
            guard let delegate = delegate else {
                preconditionFailure("pumpManagerDelegate cannot be nil")
            }

            delegate.pumpManager(self, hasNewPumpEvents: doses.map { NewPumpEvent($0) }, lastReconciliation: lastPumpReconciliation, completion: { (error) in
                if let error = error {
                    self.log.error("Error storing pod events: %@", String(describing: error))
                } else {
                    self.log.info("DU: Stored pod events: %@", String(describing: doses))
                }

                completion(error)
            })
        }
    }
}

extension OmnipodPumpManager: MessageLogger {
    func didSend(_ message: Data) {
        setState { (state) in
            state.messageLog.record(MessageLogEntry(messageDirection: .send, timestamp: Date(), data: message))
        }
    }
    
    func didReceive(_ message: Data) {
        setState { (state) in
            state.messageLog.record(MessageLogEntry(messageDirection: .receive, timestamp: Date(), data: message))
        }
    }
}

extension OmnipodPumpManager: PodCommsDelegate {
    func podComms(_ podComms: PodComms, didChange podState: PodState) {
        setState { (state) in
            state.podState = podState
        }
    }
}

