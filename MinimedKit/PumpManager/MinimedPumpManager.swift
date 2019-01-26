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


public class MinimedPumpManager: RileyLinkPumpManager, PumpManager {
    public static let managerIdentifier: String = "Minimed500"

    public init(state: MinimedPumpManagerState, rileyLinkDeviceProvider: RileyLinkDeviceProvider, rileyLinkConnectionManager: RileyLinkConnectionManager? = nil, pumpOps: PumpOps? = nil) {
        self.state = state

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

    public var rawState: PumpManager.RawStateValue {
        return state.rawValue
    }

    // TODO: apply lock
    public private(set) var state: MinimedPumpManagerState {
        didSet {
            pumpManagerDelegate?.pumpManagerDidUpdateState(self)
        }
    }
    
    override public var rileyLinkConnectionManagerState: RileyLinkConnectionManagerState? {
        get {
            return state.rileyLinkConnectionManagerState
        }
        set {
            state.rileyLinkConnectionManagerState = newValue
        }
    }

    public weak var cgmManagerDelegate: CGMManagerDelegate?

    public weak var pumpManagerDelegate: PumpManagerDelegate?

    public let log = OSLog(category: "MinimedPumpManager")

    // MARK: - CGMManager

    public private(set) var sensorState: SensorDisplayable?

    // MARK: - Pump data

    /// TODO: Isolate to queue
    fileprivate var latestPumpStatusFromMySentry: MySentryPumpStatusMessageBody? {
        didSet {
            if let sensorState = latestPumpStatusFromMySentry {
                self.sensorState = sensorState
            }
        }
    }

    // TODO: Isolate to queue
    private var latestPumpStatus: PumpStatus?

    // TODO: Isolate to queue
    private var lastAddedPumpEvents: Date = .distantPast

    // Battery monitor
    private func observeBatteryDuring(_ block: () -> Void) {
        let oldVal = pumpBatteryChargeRemaining
        block()
        pumpManagerDelegate?.pumpManagerDidUpdatePumpBatteryChargeRemaining(self, oldValue: oldVal)
    }

    // MARK: - PumpManager

    // TODO: Isolate to queue
    // Returns a value in the range 0 - 1
    public var pumpBatteryChargeRemaining: Double? {
        if let status = latestPumpStatusFromMySentry {
            return Double(status.batteryRemainingPercent) / 100
        } else if let status = latestPumpStatus {
            return batteryChemistry.chargeRemaining(at: status.batteryVolts)
        } else {
            return nil
        }
    }

    public func updateBLEHeartbeatPreference() {
        queue.async {
            /// Controls the management of the RileyLink timer tick, which is a reliably-changing BLE
            /// characteristic which can cause the app to wake. For most users, the G5 Transmitter and
            /// G4 Receiver are reliable as hearbeats, but users who find their resources extremely constrained
            /// due to greedy apps or older devices may choose to always enable the timer by always setting `true`
            self.rileyLinkDeviceProvider.timerTickEnabled = self.isPumpDataStale || (self.pumpManagerDelegate?.pumpManagerShouldProvideBLEHeartbeat(self) == true)
        }
    }

    public var pumpRecordsBasalProfileStartEvents: Bool {
        return state.pumpModel.recordsBasalProfileStartEvents
    }

    public var pumpReservoirCapacity: Double {
        return Double(state.pumpModel.reservoirCapacity)
    }

    public var pumpTimeZone: TimeZone {
        return state.timeZone
    }

    public static let localizedTitle = LocalizedString("Minimed 500/700 Series", comment: "Generic title of the minimed pump manager")

    public var localizedTitle: String {
        return String(format: LocalizedString("Minimed %@", comment: "Pump title (1: model number)"), state.pumpModel.rawValue)
    }

    // MARK: - RileyLink Updates

    override public func device(_ device: RileyLinkDevice, didReceivePacket packet: RFPacket) {
        guard let data = MinimedPacket(encodedData: packet.data)?.data,
            let message = PumpMessage(rxData: data),
            message.address.hexadecimalString == state.pumpID,
            case .mySentry = message.packetType
        else {
            return
        }

        queue.async {
            switch message.messageBody {
            case let body as MySentryPumpStatusMessageBody:
                self.updatePumpStatus(body, from: device)
            case is MySentryAlertMessageBody, is MySentryAlertClearedMessageBody:
                break
            case let body:
                // TODO: I think we've learned everything we're going to learn here.
                self.log.error("Unknown MySentry Message: %d: %{public}@", message.messageType.rawValue, body.txData.hexadecimalString)
            }
        }
    }

    override public func deviceTimerDidTick(_ device: RileyLinkDevice) {
        self.pumpManagerDelegate?.pumpManagerBLEHeartbeatDidFire(self)
    }

    // MARK: - CustomDebugStringConvertible

    override public var debugDescription: String {
        return [
            "## MinimedPumpManager",
            "isPumpDataStale: \(isPumpDataStale)",
            "latestPumpStatus: \(String(describing: latestPumpStatus))",
            "latestPumpStatusFromMySentry: \(String(describing: latestPumpStatusFromMySentry))",
            "lastAddedPumpEvents: \(lastAddedPumpEvents)",
            "pumpBatteryChargeRemaining: \(String(reflecting: pumpBatteryChargeRemaining))",
            "state: \(String(reflecting: state))",
            "sensorState: \(String(describing: sensorState))",
            "",
            "pumpOps: \(String(reflecting: pumpOps))",
            "",
            super.debugDescription,
        ].joined(separator: "\n")
    }

    /**
     Attempts to fix an extended communication failure between a RileyLink device and the pump

     - parameter device: The RileyLink device
     */
    private func troubleshootPumpComms(using device: RileyLinkDevice) {
        /// TODO: Isolate to queue?
        // Ensuring timer tick is enabled will allow more tries to bring the pump data up-to-date.
        updateBLEHeartbeatPreference()

        // How long we should wait before we re-tune the RileyLink
        let tuneTolerance = TimeInterval(minutes: 14)

        let lastTuned = state.lastTuned ?? .distantPast

        if lastTuned.timeIntervalSinceNow <= -tuneTolerance {
            pumpOps.runSession(withName: "Tune pump", using: device) { (session) in
                do {
                    let scanResult = try session.tuneRadio()
                    self.log.default("Device %{public}@ auto-tuned to %{public}@ MHz", device.name ?? "", String(describing: scanResult.bestFrequency))
                } catch let error {
                    self.log.error("Device %{public}@ auto-tune failed with error: %{public}@", device.name ?? "", String(describing: error))
                    self.rileyLinkDeviceProvider.deprioritize(device, completion: nil)
                    if let error = error as? LocalizedError {
                        self.pumpManagerDelegate?.pumpManager(self, didError: PumpManagerError.communication(MinimedPumpManagerError.tuneFailed(error)))
                    }
                }
            }
        } else {
            rileyLinkDeviceProvider.deprioritize(device, completion: nil)
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
        dispatchPrecondition(condition: .onQueue(queue))

        log.default("MySentry message received")

        var pumpDateComponents = status.pumpDateComponents
        var glucoseDateComponents = status.glucoseDateComponents

        let timeZone = state.timeZone
        pumpDateComponents.timeZone = timeZone
        glucoseDateComponents?.timeZone = timeZone

        // The pump sends the same message 3x, so ignore it if we've already seen it.
        guard status != latestPumpStatusFromMySentry, let pumpDate = pumpDateComponents.date else {
            return
        }

        // Ignore status messages without some semblance of recency.
        guard abs(pumpDate.timeIntervalSinceNow) < .minutes(5) else {
            log.error("Ignored MySentry status due to date mismatch: %{public}@ in %{public}", String(describing: pumpDate), String(describing: timeZone))
            return
        }

        observeBatteryDuring {
            latestPumpStatusFromMySentry = status
        }

        device.getStatus { (deviceStatus) in
            // Trigger device status upload, even if something is wrong with pumpStatus
            self.queue.async {

                let pumpManagerStatus = PumpManagerStatus(
                    date: pumpDate,
                    timeZone: timeZone,
                    device: deviceStatus.device(pumpID: self.state.pumpID, pumpModel: self.state.pumpModel),
                    lastValidFrequency: self.state.lastValidFrequency,
                    lastTuned: self.state.lastTuned,
                    battery: PumpManagerStatus.BatteryStatus(percent: Double(status.batteryRemainingPercent) / 100),
                    isSuspended: nil,
                    isBolusing: nil,
                    remainingReservoir: HKQuantity(unit: .internationalUnit(), doubleValue: status.reservoirRemainingUnits)
                )

                self.pumpManagerDelegate?.pumpManager(self, didUpdateStatus: pumpManagerStatus)

                switch status.glucose {
                case .active(glucose: let glucose):
                    // Enlite data is included
                    if let date = glucoseDateComponents?.date {
                        let sample = NewGlucoseSample(
                            date: date,
                            quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: Double(glucose)),
                            isDisplayOnly: false,
                            syncIdentifier: status.glucoseSyncIdentifier ?? UUID().uuidString,
                            device: deviceStatus.device(pumpID: self.state.pumpID, pumpModel: self.state.pumpModel)
                        )

                        self.cgmManagerDelegate?.cgmManager(self, didUpdateWith: .newData([sample]))
                    }
                case .off:
                    // Enlite is disabled, so assert glucose from another source
                    self.pumpManagerDelegate?.pumpManagerBLEHeartbeatDidFire(self)
                default:
                    // Anything else is an Enlite error
                    // TODO: Provide info about status.glucose
                    self.cgmManagerDelegate?.cgmManager(self, didUpdateWith: .error(PumpManagerError.deviceState(nil)))
                }
            }
        }

        // Sentry packets are sent in groups of 3, 5s apart. Wait 11s before allowing the loop data to continue to avoid conflicting comms.
        queue.asyncAfter(deadline: .now() + .seconds(11)) {
            self.updateReservoirVolume(status.reservoirRemainingUnits, at: pumpDate, withTimeLeft: TimeInterval(minutes: Double(status.reservoirRemainingMinutes)))
        }
    }

    /**
     Store a new reservoir volume and notify observers of new pump data.

     - parameter units:    The number of units remaining
     - parameter date:     The date the reservoir was read
     - parameter timeLeft: The approximate time before the reservoir is empty
     */
    private func updateReservoirVolume(_ units: Double, at date: Date, withTimeLeft timeLeft: TimeInterval?) {
        pumpManagerDelegate?.pumpManager(self, didReadReservoirValue: units, at: date) { (result) in
            /// TODO: Isolate to queue

            switch result {
            case .failure:
                break
            case .success(let (_, _, areStoredValuesContinuous)):
                // Run a loop as long as we have fresh, reliable pump data.
                if self.state.preferredInsulinDataSource == .pumpHistory || !areStoredValuesContinuous {
                    self.fetchPumpHistory { (error) in
                        if let error = error as? PumpManagerError {
                            self.pumpManagerDelegate?.pumpManager(self, didError: error)
                        }

                        if error == nil || areStoredValuesContinuous {
                            self.pumpManagerDelegate?.pumpManagerRecommendsLoop(self)
                        }
                    }
                } else {
                    self.pumpManagerDelegate?.pumpManagerRecommendsLoop(self)
                }
            }

            // New reservoir data means we may want to adjust our timer tick requirements
            self.updateBLEHeartbeatPreference()
        }
    }

    /// TODO: Isolate to queue
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
                    guard let startDate = self.pumpManagerDelegate?.startDateToFilterNewPumpEvents(for: self) else {
                        preconditionFailure("pumpManagerDelegate cannot be nil")
                    }

                    let (events, model) = try session.getHistoryEvents(since: startDate)

                    self.pumpManagerDelegate?.pumpManager(self, didReadPumpEvents: events.pumpEvents(from: model), completion: { (error) in
                        if error == nil {
                            self.lastAddedPumpEvents = Date()
                        }

                        completion(error)
                    })
                } catch let error {
                    self.troubleshootPumpComms(using: device)

                    completion(PumpManagerError.communication(error as? LocalizedError))
                }
            }
        }
    }

    /// TODO: Isolate to queue
    private var isPumpDataStale: Bool {
        // How long should we wait before we poll for new pump data?
        let pumpStatusAgeTolerance = rileyLinkDeviceProvider.idleListeningEnabled ? TimeInterval(minutes: 6) : TimeInterval(minutes: 4)

        return isReservoirDataOlderThan(timeIntervalSinceNow: -pumpStatusAgeTolerance)
    }

    private func isReservoirDataOlderThan(timeIntervalSinceNow: TimeInterval) -> Bool {
        var lastReservoirDate = pumpManagerDelegate?.startDateToFilterNewReservoirEvents(for: self) ?? .distantPast

        // Look for reservoir data from MySentry that hasn't yet been written (due to 11-second imposed delay)
        if let sentryStatus = latestPumpStatusFromMySentry {
            var components = sentryStatus.pumpDateComponents
            components.timeZone = state.timeZone

            lastReservoirDate = max(components.date ?? .distantPast, lastReservoirDate)
        }

        return lastReservoirDate.timeIntervalSinceNow <= timeIntervalSinceNow
    }

    /**
     Ensures pump data is current by either waking and polling, or ensuring we're listening to sentry packets.
     */
    /// TODO: Isolate to queue
    public func assertCurrentPumpData() {
        rileyLinkDeviceProvider.assertIdleListening(forcingRestart: true)

        guard isPumpDataStale else {
            return
        }

        self.log.default("Pump data is stale, fetching.")

        rileyLinkDeviceProvider.getDevices { (devices) in
            guard let device = devices.firstConnected else {
                let error = PumpManagerError.connection(MinimedPumpManagerError.noRileyLink)
                self.log.error("No devices found while fetching pump data")
                self.pumpManagerDelegate?.pumpManager(self, didError: error)
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
                        self.pumpManagerDelegate?.pumpManager(self, didAdjustPumpClockBy: date.timeIntervalSinceNow)
                        try session.setTimeToNow()

                        guard let newDate = try session.getTime().date else {
                            throw PumpManagerError.configuration(MinimedPumpManagerError.noDate)
                        }

                        date = newDate
                    }

                    self.observeBatteryDuring {
                        self.latestPumpStatus = status
                    }

                    self.updateReservoirVolume(status.reservoir, at: date, withTimeLeft: nil)

                    device.getStatus { (deviceStatus) in
                        self.queue.async {
                            let pumpManagerStatus = PumpManagerStatus(
                                date: date,
                                timeZone: session.pump.timeZone,
                                device: deviceStatus.device(pumpID: self.state.pumpID, pumpModel: self.state.pumpModel),
                                lastValidFrequency: self.state.lastValidFrequency,
                                lastTuned: self.state.lastTuned,
                                battery: PumpManagerStatus.BatteryStatus(
                                    voltage: status.batteryVolts,
                                    state: {
                                        switch status.batteryStatus {
                                        case .normal:
                                            return .normal
                                        case .low:
                                            return .low
                                        case .unknown:
                                            return nil
                                        }
                                    }()
                                ),
                                isSuspended: status.suspended,
                                isBolusing: status.bolusing,
                                remainingReservoir: HKQuantity(unit: .internationalUnit(), doubleValue: status.reservoir)
                            )

                            self.pumpManagerDelegate?.pumpManager(self, didUpdateStatus: pumpManagerStatus)
                        }
                    }
                } catch let error {
                    self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
                    self.pumpManagerDelegate?.pumpManager(self, didError: PumpManagerError.communication(error as? LocalizedError))
                    self.troubleshootPumpComms(using: device)
                }
            }
        }
    }

    // TODO: Isolate to queue
    public func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (_ units: Double, _ date: Date) -> Void, completion: @escaping (_ error: Error?) -> Void) {
        guard units > 0 else {
            completion(nil)
            return
        }

        // If we don't have recent pump data, or the pump was recently rewound, read new pump data before bolusing.
        let shouldReadReservoir = isReservoirDataOlderThan(timeIntervalSinceNow: .minutes(-6))

        pumpOps.runSession(withName: "Bolus", using: rileyLinkDeviceProvider.firstConnectedDevice) { (session) in
            guard let session = session else {
                completion(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink))
                return
            }

            if shouldReadReservoir {
                do {
                    let reservoir = try session.getRemainingInsulin()

                    self.pumpManagerDelegate?.pumpManager(self, didReadReservoirValue: reservoir.units, at: reservoir.clock.date!) { _ in
                        // Ignore result
                    }
                } catch let error as PumpOpsError {
                    self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
                    completion(SetBolusError.certain(error))
                    return
                } catch let error as PumpCommandError {
                    self.log.error("Failed to fetch pump status: %{public}@", String(describing: error))
                    switch error {
                    case .arguments(let error):
                        completion(SetBolusError.certain(error))
                    case .command(let error):
                        completion(SetBolusError.certain(error))
                    }
                    return
                } catch let error {
                    completion(error)
                    return
                }
            }

            do {
                willRequest(units, Date())
                try session.setNormalBolus(units: units)
                completion(nil)
            } catch let error {
                self.log.error("Failed to bolus: %{public}@", String(describing: error))
                completion(error)
            }
        }
    }

    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        pumpOps.runSession(withName: "Set Temp Basal", using: rileyLinkDeviceProvider.firstConnectedDevice) { (session) in
            guard let session = session else {
                completion(.failure(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink)))
                return
            }

            do {
                let response = try session.setTempBasal(unitsPerHour, duration: duration)

                let now = Date()
                let endDate = now.addingTimeInterval(response.timeRemaining)
                let startDate = endDate.addingTimeInterval(-duration)
                completion(.success(DoseEntry(
                    type: .tempBasal,
                    startDate: startDate,
                    endDate: endDate,
                    value: response.rate,
                    unit: .unitsPerHour
                )))

                // Continue below
            } catch let error {
                completion(.failure(error))
                return
            }

            do {
                // If we haven't fetched history in a while, our preferredInsulinDataSource is probably .reservoir, so
                // let's take advantage of the pump radio being on.
                if self.lastAddedPumpEvents.timeIntervalSinceNow < .minutes(-4) {
                    let clock = try session.getTime()
                    // Check if the clock should be reset
                    if let date = clock.date, abs(date.timeIntervalSinceNow) > .seconds(20) {
                        self.log.error("Pump clock is more than 20 seconds off. Resetting.")
                        self.pumpManagerDelegate?.pumpManager(self, didAdjustPumpClockBy: date.timeIntervalSinceNow)
                        try session.setTimeToNow()
                    }

                    self.fetchPumpHistory { (error) in
                        if let error = error {
                            self.log.error("Post-basal history fetch failed: %{public}@", String(describing: error))
                        }
                    }
                }
            } catch let error {
                self.log.error("Post-basal time sync failed: %{public}@", String(describing: error))
            }
        }
    }

    // MARK: - Configuration

    // MARK: Pump
    
    // TODO
    public func getOpsForDevice(_ device: RileyLinkDevice, completion: @escaping (_ pumpOps: PumpOps) -> Void) {
        queue.async {
            completion(self.pumpOps)
        }
    }


    public private(set) var pumpOps: PumpOps!

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


extension MinimedPumpManager: PumpOpsDelegate {
    public func pumpOps(_ pumpOps: PumpOps, didChange state: PumpState) {
        self.state.pumpState = state
    }
}


extension MinimedPumpManager: CGMManager {
    public var shouldSyncToRemoteService: Bool {
        return true
    }

    public var providesBLEHeartbeat: Bool {
        return false
    }

    public var managedDataInterval: TimeInterval? {
        return nil
    }

    public var device: HKDevice? {
        return nil
    }

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) {
        rileyLinkDeviceProvider.getDevices { (devices) in
            guard let device = devices.firstConnected else {
                completion(.error(PumpManagerError.connection(MinimedPumpManagerError.noRileyLink)))
                return
            }

            let latestGlucoseDate = self.cgmManagerDelegate?.startDateToFilterNewData(for: self) ?? Date(timeIntervalSinceNow: TimeInterval(hours: -24))

            guard latestGlucoseDate.timeIntervalSinceNow <= TimeInterval(minutes: -4.5) else {
                completion(.noData)
                return
            }

            self.pumpOps.runSession(withName: "Fetch Enlite History", using: device) { (session) in
                do {
                    let events = try session.getGlucoseHistoryEvents(since: latestGlucoseDate.addingTimeInterval(.minutes(1)))

                    if let latestSensorEvent = events.compactMap({ $0.glucoseEvent as? RelativeTimestampedGlucoseEvent }).last {
                        self.sensorState = EnliteSensorDisplayable(latestSensorEvent)
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

