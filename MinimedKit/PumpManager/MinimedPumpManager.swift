//
//  MinimedPumpManager.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
import RileyLinkKit
import RileyLinkBLEKit
import os.log

public protocol MinimedPumpManagerStateObserver: class {
    func didUpdatePumpManagerState(_ state: MinimedPumpManagerState)
}

public class MinimedPumpManager: RileyLinkPumpManager {
    public init(state: MinimedPumpManagerState, rileyLinkDeviceProvider: RileyLinkDeviceProvider, rileyLinkConnectionManager: RileyLinkConnectionManager? = nil, pumpOps: PumpOps? = nil) {
        self.lockedState = Locked(state)

        self.hkDevice = HKDevice(
            name: type(of: self).managerIdentifier,
            manufacturer: "Medtronic",
            model: state.pumpModel.rawValue,
            hardwareVersion: nil,
            firmwareVersion: state.pumpFirmwareVersion,
            softwareVersion: String(MinimedKitVersionNumber),
            localIdentifier: state.pumpID,
            udiDeviceIdentifier: nil
        )
        
        super.init(rileyLinkDeviceProvider: rileyLinkDeviceProvider, rileyLinkConnectionManager: rileyLinkConnectionManager)

        // Pump communication
        let idleListeningEnabled = state.pumpModel.hasMySentry
        self.pumpOps = pumpOps ?? PumpOps(pumpSettings: state.pumpSettings, pumpState: state.pumpState, delegate: self)

        self.rileyLinkDeviceProvider.idleListeningState = idleListeningEnabled ? MinimedPumpManagerState.idleListeningEnabledDefaults : .disabled
    }

    public required convenience init?(rawState: PumpManager.RawStateValue) {
        guard let state = MinimedPumpManagerState(rawValue: rawState),
            let connectionManagerState = state.rileyLinkConnectionManagerState else
        {
            return nil
        }
        
        let rileyLinkConnectionManager = RileyLinkConnectionManager(state: connectionManagerState)
        
        self.init(state: state, rileyLinkDeviceProvider: rileyLinkConnectionManager.deviceProvider, rileyLinkConnectionManager: rileyLinkConnectionManager)
        
        rileyLinkConnectionManager.delegate = self
    }

    public private(set) var pumpOps: PumpOps!

    // MARK: - PumpManager

    public let stateObservers = WeakSynchronizedSet<MinimedPumpManagerStateObserver>()

    private(set) public var state: MinimedPumpManagerState {
        get {
            return lockedState.value
        }
        set {
            let oldValue = lockedState.value
            let oldStatus = status
            lockedState.value = newValue

            // PumpManagerStatus may have changed
            if oldValue.timeZone != newValue.timeZone ||
                oldValue.suspendState != newValue.suspendState
            {
                notifyStatusObservers(oldStatus: oldStatus)
            }

            if oldValue != newValue {
                pumpDelegate.notify { (delegate) in
                    delegate?.pumpManagerDidUpdateState(self)
                }
                stateObservers.forEach { (observer) in
                    observer.didUpdatePumpManagerState(newValue)
                }
            }
        }
    }
    private let lockedState: Locked<MinimedPumpManagerState>

    /// Temporal state of the manager
    private var recents: MinimedPumpManagerRecents {
        get {
            return lockedRecents.value
        }
        set {
            let oldValue = recents
            let oldStatus = status
            lockedRecents.value = newValue

            // Battery percentage may have changed
            if oldValue.latestPumpStatusFromMySentry != newValue.latestPumpStatusFromMySentry ||
                oldValue.latestPumpStatus != newValue.latestPumpStatus
            {
                let oldBatteryPercentage = state.batteryPercentage
                let newBatteryPercentage: Double?

                // Persist the updated battery level
                if let status = newValue.latestPumpStatusFromMySentry {
                    newBatteryPercentage = Double(status.batteryRemainingPercent) / 100
                } else if let status = newValue.latestPumpStatus {
                    newBatteryPercentage = batteryChemistry.chargeRemaining(at: status.batteryVolts)
                } else {
                    newBatteryPercentage = nil
                }

                if oldBatteryPercentage != newBatteryPercentage {
                    state.batteryPercentage = newBatteryPercentage
                }
            }

            // PumpManagerStatus may have changed
            if oldStatus != status {
                notifyStatusObservers(oldStatus: oldStatus)
            }
        }
    }
    private let lockedRecents = Locked(MinimedPumpManagerRecents())

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

    private let cgmDelegate = WeakSynchronizedDelegate<CGMManagerDelegate>()
    private let pumpDelegate = WeakSynchronizedDelegate<PumpManagerDelegate>()

    public let log = OSLog(category: "MinimedPumpManager")

    // MARK: - CGMManager

    private let hkDevice: HKDevice

    // MARK: - RileyLink Updates

    override public var rileyLinkConnectionManagerState: RileyLinkConnectionManagerState? {
        get {
            return state.rileyLinkConnectionManagerState
        }
        set {
            state.rileyLinkConnectionManagerState = newValue
        }
    }

    override public func device(_ device: RileyLinkDevice, didReceivePacket packet: RFPacket) {
        device.assertOnSessionQueue()

        guard let data = MinimedPacket(encodedData: packet.data)?.data,
            let message = PumpMessage(rxData: data),
            message.address.hexadecimalString == state.pumpID,
            case .mySentry = message.packetType
        else {
            return
        }

        switch message.messageBody {
        case let body as MySentryPumpStatusMessageBody:
            self.updatePumpStatus(body, from: device)
        case is MySentryAlertMessageBody, is MySentryAlertClearedMessageBody:
            break
        case let body:
            self.log.error("Unknown MySentry Message: %d: %{public}@", message.messageType.rawValue, body.txData.hexadecimalString)
        }
    }

    override public func deviceTimerDidTick(_ device: RileyLinkDevice) {
        pumpDelegate.notify { (delegate) in
            delegate?.pumpManagerBLEHeartbeatDidFire(self)
        }
    }

    // MARK: - CustomDebugStringConvertible

    override public var debugDescription: String {
        return [
            "## MinimedPumpManager",
            "isPumpDataStale: \(isPumpDataStale)",
            "pumpOps: \(String(reflecting: pumpOps))",
            "recents: \(String(reflecting: recents))",
            "state: \(String(reflecting: state))",
            "status: \(String(describing: status))",
            "stateObservers.count: \(stateObservers.cleanupDeallocatedElements().count)",
            "statusObservers.count: \(statusObservers.cleanupDeallocatedElements().count)",
            super.debugDescription,
        ].joined(separator: "\n")
    }
}

extension MinimedPumpManager {
    /**
     Attempts to fix an extended communication failure between a RileyLink device and the pump

     - parameter device: The RileyLink device
     */
    private func troubleshootPumpComms(using device: RileyLinkDevice) {
        device.assertOnSessionQueue()

        // Ensuring timer tick is enabled will allow more tries to bring the pump data up-to-date.
        updateBLEHeartbeatPreference()

        // How long we should wait before we re-tune the RileyLink
        let tuneTolerance = TimeInterval(minutes: 14)

        let lastTuned = state.lastTuned ?? .distantPast

        if lastTuned.timeIntervalSinceNow <= -tuneTolerance {
            pumpOps.runSession(withName: "Tune pump", using: device) { (session) in
                do {
                    let scanResult = try session.tuneRadio(attempts: 1)
                    self.log.default("Device %{public}@ auto-tuned to %{public}@ MHz", device.name ?? "", String(describing: scanResult.bestFrequency))
                } catch let error {
                    self.log.error("Device %{public}@ auto-tune failed with error: %{public}@", device.name ?? "", String(describing: error))
                    self.rileyLinkDeviceProvider.deprioritize(device, completion: nil)
                    if let error = error as? LocalizedError {
                        self.pumpDelegate.notify { (delegate) in
                            delegate?.pumpManager(self, didError: PumpManagerError.communication(MinimedPumpManagerError.tuneFailed(error)))
                        }
                    }
                }
            }
        } else {
            rileyLinkDeviceProvider.deprioritize(device, completion: nil)
        }
    }

    private func runSuspendResumeOnSession(state: SuspendResumeMessageBody.SuspendResumeState, session: PumpOpsSession) throws {
        defer { self.recents.suspendEngageState = .stable }
        self.recents.suspendEngageState = state == .suspend ? .engaging : .disengaging

        try session.setSuspendResumeState(state)
        let date = Date()
        switch state {
        case .suspend:
            self.state.suspendState = .suspended(date)
        case .resume:
            self.state.suspendState = .resumed(date)
        }

        if state == .suspend {
            self.state.unfinalizedBolus?.cancel(at: Date())
            if let bolus = self.state.unfinalizedBolus {
                self.state.pendingDoses.append(bolus)
            }
            self.state.unfinalizedBolus = nil

            self.state.pendingDoses.append(UnfinalizedDose(suspendStartTime: Date()))
        } else {
            self.state.pendingDoses.append(UnfinalizedDose(resumeStartTime: Date()))
        }
    }

    private func setSuspendResumeState(state: SuspendResumeMessageBody.SuspendResumeState, completion: @escaping (Error?) -> Void) {
        rileyLinkDeviceProvider.getDevices { (devices) in
            guard let device = devices.firstConnected else {
                completion(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink))
                return
            }

            let sessionName: String = {
                switch state {
                case .suspend:
                    return "Suspend Delivery"
                case .resume:
                    return "Resume Delivery"
                }
            }()

            self.pumpOps.runSession(withName: sessionName, using: device) { (session) in
                do {
                    try self.runSuspendResumeOnSession(state: state, session: session)
                    self.storePendingPumpEvents({ (error) in
                        completion(error)
                    })
                } catch let error {
                    self.troubleshootPumpComms(using: device)
                    completion(PumpManagerError.communication(error as? LocalizedError))
                }
            }
        }
    }

    /**
     Handles receiving a MySentry status message, which are only posted by MM x23 pumps.

     This message has two important pieces of info about the pump: reservoir volume and battery.

     Because the RileyLink must actively listen for these packets, they are not a reliable heartbeat. However, we can still use them to assert glucose data is current.

     - parameter status: The status message body
     - parameter device: The RileyLink that received the message
     */
    private func updatePumpStatus(_ status: MySentryPumpStatusMessageBody, from device: RileyLinkDevice) {
        device.assertOnSessionQueue()

        log.default("MySentry message received")

        var pumpDateComponents = status.pumpDateComponents
        var glucoseDateComponents = status.glucoseDateComponents

        let timeZone = state.timeZone
        pumpDateComponents.timeZone = timeZone
        glucoseDateComponents?.timeZone = timeZone

        // The pump sends the same message 3x, so ignore it if we've already seen it.
        guard status != recents.latestPumpStatusFromMySentry, let pumpDate = pumpDateComponents.date else {
            return
        }

        // Ignore status messages without some semblance of recency.
        guard abs(pumpDate.timeIntervalSinceNow) < .minutes(5) else {
            log.error("Ignored MySentry status due to date mismatch: %{public}@ in %{public}", String(describing: pumpDate), String(describing: timeZone))
            return
        }
        
        recents.latestPumpStatusFromMySentry = status

        switch status.glucose {
        case .active(glucose: let glucose):
            // Enlite data is included
            if let date = glucoseDateComponents?.date {
                let sample = NewGlucoseSample(
                    date: date,
                    quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: Double(glucose)),
                    isDisplayOnly: false,
                    syncIdentifier: status.glucoseSyncIdentifier ?? UUID().uuidString,
                    device: self.device
                )

                cgmDelegate.notify { (delegate) in
                    delegate?.cgmManager(self, didUpdateWith: .newData([sample]))
                }
            }
        case .off:
            // Enlite is disabled, so assert glucose from another source
            pumpDelegate.notify { (delegate) in
                delegate?.pumpManagerBLEHeartbeatDidFire(self)
            }
        default:
            // Anything else is an Enlite error
            // TODO: Provide info about status.glucose
            cgmDelegate.notify { (delegate) in
                delegate?.cgmManager(self, didUpdateWith: .error(PumpManagerError.deviceState(nil)))
            }
        }
        
        // Sentry packets are sent in groups of 3, 5s apart. Wait 11s before allowing the loop data to continue to avoid conflicting comms.
        device.sessionQueueAsyncAfter(deadline: .now() + .seconds(11)) { [weak self] in
            self?.updateReservoirVolume(status.reservoirRemainingUnits, at: pumpDate, withTimeLeft: TimeInterval(minutes: Double(status.reservoirRemainingMinutes)))
        }
    }

    /**
     Store a new reservoir volume and notify observers of new pump data.

     - parameter units:    The number of units remaining
     - parameter date:     The date the reservoir was read
     - parameter timeLeft: The approximate time before the reservoir is empty
     */
    private func updateReservoirVolume(_ units: Double, at date: Date, withTimeLeft timeLeft: TimeInterval?) {
        // Must be called from the sessionQueue

        state.lastReservoirReading = ReservoirReading(units: units, validAt: date)

        pumpDelegate.notify { (delegate) in
            delegate?.pumpManager(self, didReadReservoirValue: units, at: date) { (result) in
                self.pumpManagerDelegateDidProcessReservoirValue(result)
            }
        }

        // New reservoir data means we may want to adjust our timer tick requirements
        updateBLEHeartbeatPreference()
    }

    /// Called on an unknown queue by the delegate
    private func pumpManagerDelegateDidProcessReservoirValue(_ result: PumpManagerResult<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool)>) {
        switch result {
        case .failure:
            break
        case .success(let (_, _, areStoredValuesContinuous)):
            // Run a loop as long as we have fresh, reliable pump data.
            if state.preferredInsulinDataSource == .pumpHistory || !areStoredValuesContinuous {
                fetchPumpHistory { (error) in  // Can be centralQueue or sessionQueue
                    self.pumpDelegate.notify { (delegate) in
                        if let error = error as? PumpManagerError {
                            delegate?.pumpManager(self, didError: error)
                        }

                        if error == nil || areStoredValuesContinuous {
                            delegate?.pumpManagerRecommendsLoop(self)
                        }
                    }
                }
            } else {
                pumpDelegate.notify { (delegate) in
                    delegate?.pumpManagerRecommendsLoop(self)
                }
            }
        }
    }


    private func reconcilePendingDosesWith(_ events: [NewPumpEvent]) {
        // Must be called from the sessionQueue

        var reconcilableEvents = events.filter { !self.state.recentlyReconciledEventIDs.contains($0.raw) }

        let matchingTimeWindow = TimeInterval(minutes: 1)

        func markReconciled(raw: Data, index: Int) -> Void {
            self.state.recentlyReconciledEventIDs.insert(raw, at: 0)
            self.state.recentlyReconciledEventIDs = Array(self.state.recentlyReconciledEventIDs.prefix(5))
            reconcilableEvents.remove(at: index)
        }

        // If we have a bolus in progress, see if it has shown up in history yet
        if let bolus = self.state.unfinalizedBolus, let index = reconcilableEvents.firstMatchingIndex(for: bolus, within: matchingTimeWindow) {
            let matchingBolus = reconcilableEvents[index]
            self.log.debug("Matched unfinalized bolus %{public}@ to history record %{public}@", String(describing: bolus), String(describing: matchingBolus))
            self.state.unfinalizedBolus = nil
            markReconciled(raw: matchingBolus.raw, index: index)
        }

        // Reconcile temp basal
        if let tempBasal = self.state.unfinalizedTempBasal, let index = reconcilableEvents.firstMatchingIndex(for: tempBasal, within: matchingTimeWindow), let dose = events[index].dose {
            let matchedTempBasal = reconcilableEvents[index]
            self.log.debug("Matched unfinalized temp basal %{public}@ to history record %{public}@", String(describing: tempBasal), String(describing: matchedTempBasal))
            // Update unfinalizedTempBasal to match entry in history, and mark as reconciled
            self.state.unfinalizedTempBasal = UnfinalizedDose(tempBasalRate: dose.unitsPerHour, startTime: dose.startDate, duration: dose.endDate.timeIntervalSince(dose.startDate), isReconciledWithHistory: true)
            markReconciled(raw: matchedTempBasal.raw, index: index)
        }

        // Reconcile any finished doses that we were temporarily tracking
        self.state.pendingDoses.removeAll { (dose) -> Bool in
            if let index = reconcilableEvents.firstMatchingIndex(for: dose, within: matchingTimeWindow) {
                let historyEvent = reconcilableEvents[index]
                self.log.debug("Matched pending dose %{public}@ to history record %{public}@", String(describing: dose), String(describing: historyEvent))
                markReconciled(raw: historyEvent.raw, index: index)
                return true
            }
            return false
        }

        self.state.lastReconciliation = Date()
    }

    private var pendingDosesForStorage: [NewPumpEvent] {
        // Must be called from the sessionQueue
        return (self.state.pendingDoses + [self.state.unfinalizedBolus, self.state.unfinalizedTempBasal]).compactMap({ (dose) in
            guard let dose = dose, !dose.isReconciledWithHistory else {
                return nil
            }
            return NewPumpEvent(dose)
        })
    }

    /// Polls the pump for new history events and passes them to the loop manager
    ///
    /// - Parameters:
    ///   - completion: A closure called once upon completion
    ///   - error: An error describing why the fetch and/or store failed
    private func fetchPumpHistory(_ completion: @escaping (_ error: Error?) -> Void) {
        rileyLinkDeviceProvider.getDevices { (devices) in
            guard let device = devices.firstConnected else {
                completion(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink))
                return
            }

            self.pumpOps.runSession(withName: "Fetch Pump History", using: device) { (session) in
                do {
                    guard let startDate = self.pumpDelegate.call({ (delegate) in
                        return delegate?.startDateToFilterNewPumpEvents(for: self)
                    }) else {
                        preconditionFailure("pumpManagerDelegate cannot be nil")
                    }

                    let (historyEvents, model) = try session.getHistoryEvents(since: startDate)

                    // Reconcile history with pending doses
                    let newPumpEvents = historyEvents.pumpEvents(from: model)
                    self.reconcilePendingDosesWith(newPumpEvents)

                    self.pumpDelegate.notify({ (delegate) in
                        guard let delegate = delegate else {
                            preconditionFailure("pumpManagerDelegate cannot be nil")
                        }

                        delegate.pumpManager(self, hasNewPumpEvents: newPumpEvents + self.pendingDosesForStorage, lastReconciliation: self.lastReconciliation, completion: { (error) in
                            // Called on an unknown queue by the delegate
                            if error == nil {
                                self.recents.lastAddedPumpEvents = Date()
                            }

                            completion(error)
                        })
                    })
                } catch let error {
                    self.troubleshootPumpComms(using: device)

                    completion(PumpManagerError.communication(error as? LocalizedError))
                }
            }
        }
    }

    private func storePendingPumpEvents(_ completion: @escaping (_ error: Error?) -> Void) {
        // Must be called from the sessionQueue
        let events = pendingDosesForStorage

        log.debug("Storing pending pump events: %{public}@", String(describing: events))

        self.pumpDelegate.notify({ (delegate) in
            guard let delegate = delegate else {
                preconditionFailure("pumpManagerDelegate cannot be nil")
            }

            delegate.pumpManager(self, hasNewPumpEvents: events, lastReconciliation: self.lastReconciliation, completion: { (error) in
                // Called on an unknown queue by the delegate
                completion(error)
            })

        })
    }

    // Safe to call from any thread
    private var isPumpDataStale: Bool {
        // How long should we wait before we poll for new pump data?
        let pumpStatusAgeTolerance = rileyLinkDeviceProvider.idleListeningEnabled ? TimeInterval(minutes: 6) : TimeInterval(minutes: 4)

        return isReservoirDataOlderThan(timeIntervalSinceNow: -pumpStatusAgeTolerance)
    }

    // Safe to call from any thread
    private func isReservoirDataOlderThan(timeIntervalSinceNow: TimeInterval) -> Bool {
        let state = self.state
        var lastReservoirDate = state.lastReservoirReading?.validAt ?? .distantPast

        // Look for reservoir data from MySentry that hasn't yet been written (due to 11-second imposed delay)
        if let sentryStatus = recents.latestPumpStatusFromMySentry {
            var components = sentryStatus.pumpDateComponents
            components.timeZone = state.timeZone

            lastReservoirDate = max(components.date ?? .distantPast, lastReservoirDate)
        }

        return lastReservoirDate.timeIntervalSinceNow <= timeIntervalSinceNow
    }

    private func updateBLEHeartbeatPreference() {
        // Must not be called on the delegate's queue
        rileyLinkDeviceProvider.timerTickEnabled = isPumpDataStale || pumpDelegate.call({ (delegate) -> Bool in
            return delegate?.pumpManagerMustProvideBLEHeartbeat(self) == true
        })
    }

    // MARK: - Configuration

    // MARK: Pump

    /// The user's preferred method of fetching insulin data from the pump
    public var preferredInsulinDataSource: InsulinDataSource {
        get {
            return state.preferredInsulinDataSource
        }
        set {
            state.preferredInsulinDataSource = newValue
        }
    }

    /// The pump battery chemistry, for voltage -> percentage calculation
    public var batteryChemistry: BatteryChemistryType {
        get {
            return state.batteryChemistry
        }
        set {
            state.batteryChemistry = newValue
        }
    }
    
}


// MARK: - PumpManager
extension MinimedPumpManager: PumpManager {
    public static let managerIdentifier: String = "Minimed500"

    public static let localizedTitle = LocalizedString("Minimed 500/700 Series", comment: "Generic title of the minimed pump manager")

    public var localizedTitle: String {
        return String(format: LocalizedString("Minimed %@", comment: "Pump title (1: model number)"), state.pumpModel.rawValue)
    }

    /*
     It takes a MM pump about 40s to deliver 1 Unit while bolusing
     See: http://www.healthline.com/diabetesmine/ask-dmine-speed-insulin-pumps#3
     */
    private static let deliveryUnitsPerMinute = 1.5

    public var supportedBasalRates: [Double] {
        return state.pumpModel.supportedBasalRates
    }

    public var supportedBolusVolumes: [Double] {
        return state.pumpModel.supportedBolusVolumes
    }

    public var maximumBasalScheduleEntryCount: Int {
        return state.pumpModel.maximumBasalScheduleEntryCount
    }

    public var minimumBasalScheduleEntryDuration: TimeInterval {
        return state.pumpModel.minimumBasalScheduleEntryDuration
    }

    public var pumpRecordsBasalProfileStartEvents: Bool {
        return state.pumpModel.recordsBasalProfileStartEvents
    }

    public var pumpReservoirCapacity: Double {
        return Double(state.pumpModel.reservoirCapacity)
    }

    public var lastReconciliation: Date? {
        return state.lastReconciliation
    }

    public var status: PumpManagerStatus {
        let state = self.state
        let recents = self.recents
        let basalDeliveryState: PumpManagerStatus.BasalDeliveryState

        switch recents.suspendEngageState {
        case .engaging:
            basalDeliveryState = .suspending
        case .disengaging:
            basalDeliveryState = .resuming
        case .stable:
            switch recents.tempBasalEngageState {
            case .engaging:
                basalDeliveryState = .initiatingTempBasal
            case .disengaging:
                basalDeliveryState = .cancelingTempBasal
            case .stable:
                switch self.state.suspendState {
                case .suspended(let date):
                    basalDeliveryState = .suspended(date)
                case .resumed(let date):
                    if let tempBasal = state.unfinalizedTempBasal, !tempBasal.finished {
                        basalDeliveryState = .tempBasal(DoseEntry(tempBasal))
                    } else {
                        basalDeliveryState = .active(date)
                    }
                }
            }
        }

        let bolusState: PumpManagerStatus.BolusState

        switch recents.bolusEngageState {
        case .engaging:
            bolusState = .initiating
        case .disengaging:
            bolusState = .canceling
        case .stable:
            if let bolus = state.unfinalizedBolus, !bolus.finished {
                bolusState = .inProgress(DoseEntry(bolus))
            } else {
                bolusState = .none
            }
        }

        return PumpManagerStatus(
            timeZone: state.timeZone,
            device: hkDevice,
            pumpBatteryChargeRemaining: state.batteryPercentage,
            basalDeliveryState: basalDeliveryState,
            bolusState: bolusState
        )
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
        }
    }

    public var delegateQueue: DispatchQueue! {
        get {
            return pumpDelegate.queue
        }
        set {
            pumpDelegate.queue = newValue
            cgmDelegate.queue = newValue
        }
    }

    // MARK: Methods

    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
        setSuspendResumeState(state: .suspend, completion: completion)
    }

    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
        setSuspendResumeState(state: .resume, completion: completion)
    }

    public func addStatusObserver(_ observer: PumpManagerStatusObserver, queue: DispatchQueue) {
        statusObservers.insert(observer, queue: queue)
    }

    public func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
        statusObservers.removeElement(observer)
    }

    public func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool) {
        rileyLinkDeviceProvider.timerTickEnabled = isPumpDataStale || mustProvideBLEHeartbeat
    }

    /**
     Ensures pump data is current by either waking and polling, or ensuring we're listening to sentry packets.
     */
    public func assertCurrentPumpData() {
        rileyLinkDeviceProvider.assertIdleListening(forcingRestart: true)

        guard isPumpDataStale else {
            return
        }

        log.default("Pump data is stale, fetching.")

        rileyLinkDeviceProvider.getDevices { (devices) in
            guard let device = devices.firstConnected else {
                let error = PumpManagerError.connection(MinimedPumpManagerError.noRileyLink)
                self.log.error("No devices found while fetching pump data")
                self.pumpDelegate.notify({ (delegate) in
                    delegate?.pumpManager(self, didError: error)
                })
                return
            }

            self.pumpOps.runSession(withName: "Get Pump Status", using: device) { (session) in
                do {
                    let status = try session.getCurrentPumpStatus()
                    guard var date = status.clock.date else {
                        assertionFailure("Could not interpret a valid date from \(status.clock) in the system calendar")
                        throw PumpManagerError.configuration(MinimedPumpManagerError.noDate)
                    }

                    // Check if the clock should be reset
                    if abs(date.timeIntervalSinceNow) > .seconds(20) {
                        self.log.error("Pump clock is more than 20 seconds off. Resetting.")
                        self.pumpDelegate.notify({ (delegate) in
                            delegate?.pumpManager(self, didAdjustPumpClockBy: date.timeIntervalSinceNow)
                        })
                        try session.setTimeToNow()

                        guard let newDate = try session.getTime().date else {
                            throw PumpManagerError.configuration(MinimedPumpManagerError.noDate)
                        }

                        date = newDate
                    }

                    if case .resumed = self.state.suspendState, status.suspended {
                        self.state.suspendState = .suspended(Date())
                    }

                    self.recents.latestPumpStatus = status

                    self.updateReservoirVolume(status.reservoir, at: date, withTimeLeft: nil)
                } catch let error {
                    self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
                    self.pumpDelegate.notify({ (delegate) in
                        delegate?.pumpManager(self, didError: PumpManagerError.communication(error as? LocalizedError))
                    })
                    self.troubleshootPumpComms(using: device)
                }
            }
        }
    }

    public func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (_ dose: DoseEntry) -> Void, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        guard units > 0 else {
            assertionFailure("Invalid zero unit bolus")
            return
        }

        pumpOps.runSession(withName: "Bolus", using: rileyLinkDeviceProvider.firstConnectedDevice) { (session) in

            guard let session = session else {
                completion(.failure(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink)))
                return
            }

            if let unfinalizedBolus = self.state.unfinalizedBolus {
                guard unfinalizedBolus.finished else {
                    completion(.failure(PumpManagerError.deviceState(MinimedPumpManagerError.bolusInProgress)))
                    return
                }
                self.state.pendingDoses.append(unfinalizedBolus)
            }

            self.recents.bolusEngageState = .engaging

            // If we don't have recent pump data, or the pump was recently rewound, read new pump data before bolusing.
            if self.isReservoirDataOlderThan(timeIntervalSinceNow: .minutes(-6)) {
                do {
                    let reservoir = try session.getRemainingInsulin()

                    self.pumpDelegate.notify({ (delegate) in
                        delegate?.pumpManager(self, didReadReservoirValue: reservoir.units, at: reservoir.clock.date!) { _ in
                            // Ignore result
                        }
                    })
                } catch let error as PumpOpsError {
                    self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
                    completion(.failure(SetBolusError.certain(error)))
                    return
                } catch let error as PumpCommandError {
                    self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
                    switch error {
                    case .arguments(let error):
                        completion(.failure(SetBolusError.certain(error)))
                    case .command(let error):
                        completion(.failure(SetBolusError.certain(error)))
                    }
                    return
                } catch let error {
                    self.recents.bolusEngageState = .stable
                    completion(.failure(error))
                    return
                }
            }

            do {
                if case .suspended = self.state.suspendState {
                    do {
                        try self.runSuspendResumeOnSession(state: .resume, session: session)
                    } catch let error as PumpOpsError {
                        self.log.error("Failed to resume pump for bolus: %{public}@", String(describing: error))
                        completion(.failure(SetBolusError.certain(error)))
                        return
                    } catch let error as PumpCommandError {
                        self.log.error("Failed to resume pump for bolus: %{public}@", String(describing: error))
                        switch error {
                        case .arguments(let error):
                            completion(.failure(SetBolusError.certain(error)))
                        case .command(let error):
                            completion(.failure(SetBolusError.certain(error)))
                        }
                        return
                    } catch let error {
                        self.recents.bolusEngageState = .stable
                        completion(.failure(error))
                        return
                    }
                }

                let date = Date()
                let deliveryTime = self.state.pumpModel.bolusDeliveryTime(units: units)
                let requestedDose = UnfinalizedDose(bolusAmount: units, startTime: date, duration: deliveryTime)
                willRequest(DoseEntry(requestedDose))

                try session.setNormalBolus(units: units)

                // Between bluetooth and the radio and firmware, about 2s on average passes before we start tracking
                let commsOffset = TimeInterval(seconds: -2)
                let doseStart = Date().addingTimeInterval(commsOffset)

                let dose = UnfinalizedDose(bolusAmount: units, startTime: doseStart, duration: deliveryTime)
                self.state.unfinalizedBolus = dose
                self.recents.bolusEngageState = .stable

                self.storePendingPumpEvents({ (error) in
                    completion(.success(DoseEntry(dose)))
                })
            } catch let error {
                self.log.error("Failed to bolus: %{public}@", String(describing: error))
                self.recents.bolusEngageState = .stable
                completion(.failure(error))
            }
        }
    }

    public func cancelBolus(completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {
        self.recents.bolusEngageState = .disengaging
        setSuspendResumeState(state: .suspend) { (error) in
            self.recents.bolusEngageState = .stable
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(nil))
            }
        }
    }


    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        pumpOps.runSession(withName: "Set Temp Basal", using: rileyLinkDeviceProvider.firstConnectedDevice) { (session) in
            guard let session = session else {
                completion(.failure(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink)))
                return
            }

            self.recents.tempBasalEngageState = .engaging

            do {
                let response = try session.setTempBasal(unitsPerHour, duration: duration)

                let now = Date()
                let endDate = now.addingTimeInterval(response.timeRemaining)
                let startDate = endDate.addingTimeInterval(-duration)

                let dose = UnfinalizedDose(tempBasalRate: unitsPerHour, startTime: startDate, duration: duration)

                if duration < .ulpOfOne {
                    self.state.unfinalizedTempBasal?.cancel(at: startDate)
                    if let previousTempBasal = self.state.unfinalizedTempBasal, !previousTempBasal.isReconciledWithHistory {
                        self.state.pendingDoses.append(previousTempBasal)
                    }
                    self.state.suspendState = .resumed(startDate)
                }

                // If we were successful, then we know we aren't suspended
                if case .suspended = self.state.suspendState {
                    self.state.suspendState = .resumed(Date())
                }

                self.state.unfinalizedTempBasal = dose
                self.recents.tempBasalEngageState = .stable


                self.storePendingPumpEvents({ (error) in
                    completion(.success(DoseEntry(dose)))
                })

                // Continue below
            } catch let error as PumpCommandError {
                completion(.failure(error))

                // If we got a command-refused error, we might be suspended or bolusing, so update the state accordingly
                if case .arguments(.pumpError(.commandRefused)) = error {
                    do {
                        let status = try session.getCurrentPumpStatus()
                        if case .resumed = self.state.suspendState, status.suspended {
                            self.state.suspendState = .suspended(Date())
                        }
                        self.recents.latestPumpStatus = status
                    } catch {
                        self.log.error("Post-basal suspend state fetch failed: %{public}@", String(describing: error))
                    }
                }
                self.recents.tempBasalEngageState = .stable
                return
            } catch {
                self.recents.tempBasalEngageState = .stable
                completion(.failure(error))
                return
            }

            do {
                // If we haven't fetched history in a while, our preferredInsulinDataSource is probably .reservoir, so
                // let's take advantage of the pump radio being on.
                if self.recents.lastAddedPumpEvents.timeIntervalSinceNow < .minutes(-4) {
                    let clock = try session.getTime()
                    // Check if the clock should be reset
                    if let date = clock.date, abs(date.timeIntervalSinceNow) > .seconds(20) {
                        self.log.error("Pump clock is more than 20 seconds off. Resetting.")
                        self.pumpDelegate.notify({ (delegate) in
                            delegate?.pumpManager(self, didAdjustPumpClockBy: date.timeIntervalSinceNow)
                        })
                        try session.setTimeToNow()
                    }

                    self.fetchPumpHistory { (error) in
                        if let error = error {
                            self.log.error("Post-basal history fetch failed: %{public}@", String(describing: error))
                        }
                    }
                }
            } catch {
                self.log.error("Post-basal time sync failed: %{public}@", String(describing: error))
            }
        }
    }

    public func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> DoseProgressReporter? {
        if let bolus = self.state.unfinalizedBolus, !bolus.finished {
            return MinimedDoseProgressEstimator(dose: DoseEntry(bolus), pumpModel: state.pumpModel, reportingQueue: dispatchQueue)
        }
        return nil
    }
}

extension MinimedPumpManager: PumpOpsDelegate {
    public func pumpOps(_ pumpOps: PumpOps, didChange state: PumpState) {
        self.state.pumpState = state
    }
}

extension MinimedPumpManager: CGMManager {
    public var device: HKDevice? {
        return hkDevice
    }

    public var cgmManagerDelegate: CGMManagerDelegate? {
        get {
            return cgmDelegate.delegate
        }
        set {
            cgmDelegate.delegate = newValue
        }
    }

    public var shouldSyncToRemoteService: Bool {
        return true
    }

    public var providesBLEHeartbeat: Bool {
        return false
    }

    public var managedDataInterval: TimeInterval? {
        return nil
    }

    public var sensorState: SensorDisplayable? {
        return recents.sensorState
    }

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) {
        rileyLinkDeviceProvider.getDevices { (devices) in
            guard let device = devices.firstConnected else {
                completion(.error(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink)))
                return
            }

            let latestGlucoseDate = self.cgmDelegate.call({ (delegate) -> Date in
                return delegate?.startDateToFilterNewData(for: self) ?? Date(timeIntervalSinceNow: TimeInterval(hours: -24))
            })

            guard latestGlucoseDate.timeIntervalSinceNow <= TimeInterval(minutes: -4.5) else {
                completion(.noData)
                return
            }

            self.pumpOps.runSession(withName: "Fetch Enlite History", using: device) { (session) in
                do {
                    let events = try session.getGlucoseHistoryEvents(since: latestGlucoseDate.addingTimeInterval(.minutes(1)))

                    if let latestSensorEvent = events.compactMap({ $0.glucoseEvent as? RelativeTimestampedGlucoseEvent }).last {
                        self.recents.sensorState = EnliteSensorDisplayable(latestSensorEvent)
                    }

                    let unit = HKUnit.milligramsPerDeciliter
                    let glucoseValues: [NewGlucoseSample] = events
                        // TODO: Is the { $0.date > latestGlucoseDate } filter duplicative?
                        .filter({ $0.glucoseEvent is SensorValueGlucoseEvent && $0.date > latestGlucoseDate })
                        .map {
                            let glucoseEvent = $0.glucoseEvent as! SensorValueGlucoseEvent
                            let quantity = HKQuantity(unit: unit, doubleValue: Double(glucoseEvent.sgv))
                            return NewGlucoseSample(date: $0.date, quantity: quantity, isDisplayOnly: false, syncIdentifier: glucoseEvent.glucoseSyncIdentifier ?? UUID().uuidString, device: self.device)
                    }

                    completion(.newData(glucoseValues))
                } catch let error {
                    completion(.error(error))
                }
            }
        }
    }
}
