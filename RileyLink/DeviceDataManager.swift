//
//  DeviceDataManager.swift
//  RileyLink
//
//  Created by Pete Schwamb on 4/27/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkKit
import RileyLinkBLEKit
import MinimedKit
import NightscoutUploadKit

class DeviceDataManager {

    var getHistoryTimer: Timer?
    
    let rileyLinkManager: RileyLinkDeviceManager
    
    /// Manages remote data (TODO: the lazy initialization isn't thread-safe)
    lazy var remoteDataManager = RemoteDataManager()
    
    var connectedPeripheralIDs: Set<String> = Config.sharedInstance().autoConnectIds as! Set<String> {
        didSet {
            Config.sharedInstance().autoConnectIds = connectedPeripheralIDs
        }
    }
    
    var latestPumpStatusDate: Date?
    
    var latestPumpStatusFromMySentry: MySentryPumpStatusMessageBody? {
        didSet {
            if let update = latestPumpStatusFromMySentry, let timeZone = pumpState?.timeZone {
                var pumpClock = update.pumpDateComponents
                pumpClock.timeZone = timeZone
                latestPumpStatusDate = pumpClock.date
            }
        }
    }
    
    
    var latestPolledPumpStatus: RileyLinkKit.PumpStatus? {
        didSet {
            if let update = latestPolledPumpStatus, let timeZone = pumpState?.timeZone {
                var pumpClock = update.clock
                pumpClock.timeZone = timeZone
                latestPumpStatusDate = pumpClock.date
            }
        }
    }
    
    var pumpID: String? {
        get {
            return pumpState?.pumpID
        }
        set {
            guard newValue?.characters.count == 6 && newValue != pumpState?.pumpID else {
                return
            }
            
            if let pumpID = newValue {
                let pumpState = PumpState(pumpID: pumpID, pumpRegion: pumpRegion)
                
                if let timeZone = self.pumpState?.timeZone {
                    pumpState.timeZone = timeZone
                }
                
                self.pumpState = pumpState
            } else {
                self.pumpState = nil
            }
            
            remoteDataManager.nightscoutUploader?.reset()
            
            Config.sharedInstance().pumpID = pumpID
        }
    }
    
    var pumpRegion: PumpRegion {
        get {
            return PumpRegion(rawValue: Config.sharedInstance().pumpRegion) ?? .northAmerica
        }
        set {
            self.pumpState?.pumpRegion = newValue
            Config.sharedInstance().pumpRegion = newValue.rawValue
        }
    }

    
    var pumpState: PumpState? {
        didSet {
            rileyLinkManager.pumpState = pumpState
            
            if let oldValue = oldValue {
                NotificationCenter.default.removeObserver(self, name: .PumpStateValuesDidChange, object: oldValue)
            }
            
            if let pumpState = pumpState {
                NotificationCenter.default.addObserver(self, selector: #selector(pumpStateValuesDidChange(_:)), name: .PumpStateValuesDidChange, object: pumpState)
            }
        }
    }
    
    @objc private func pumpStateValuesDidChange(_ note: Notification) {
        switch note.userInfo?[PumpState.PropertyKey] as? String {
        case "timeZone"?:
            Config.sharedInstance().pumpTimeZone = pumpState?.timeZone
        case "pumpModel"?:
            if let sentrySupported = pumpState?.pumpModel?.hasMySentry {
                rileyLinkManager.idleListeningEnabled = sentrySupported
            }
            Config.sharedInstance().pumpModelNumber = pumpState?.pumpModel?.rawValue
        case "lastHistoryDump"?, "awakeUntil"?:
            break
        default:
            break
        }
    }
    
    var lastHistoryAttempt: Date? = nil
    
    var lastGlucoseAttempt: Date? = nil
    
    var lastRileyLinkHeardFrom: RileyLinkDevice? = nil
    
    
    var rileyLinkManagerObserver: Any? {
        willSet {
            if let observer = rileyLinkManagerObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    var rileyLinkDevicePacketObserver: Any? {
        willSet {
            if let observer = rileyLinkDevicePacketObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    @objc private func receivedRileyLinkManagerNotification(_ note: Notification) {
        NotificationCenter.default.post(name: note.name, object: self, userInfo: note.userInfo)
    }
    
    func preferredRileyLink() -> RileyLinkDevice? {
        if let device = lastRileyLinkHeardFrom {
            return device
        }
        return self.rileyLinkManager.firstConnectedDevice
    }
    
    /**
     Called when a new idle message is received by the RileyLink.
     
     Only MySentryPumpStatus messages are handled.
     
     - parameter note: The notification object
     */
    @objc private func receivedRileyLinkPacketNotification(_ note: Notification) {
        if  let
            device = note.object as? RileyLinkDevice,
            let data = note.userInfo?[RileyLinkDevice.IdleMessageDataKey] as? Data,
            let message = PumpMessage(rxData: data)
        {
            switch message.packetType {
            case .mySentry:
                switch message.messageBody {
                case let body as MySentryPumpStatusMessageBody:
                    pumpStatusUpdateReceived(body, fromDevice: device)
                default:
                    break
                }
            default:
                break
            }
        }
    }
    
    @objc private func receivedRileyLinkTimerTickNotification(_ note: Notification) {
        self.assertCurrentPumpData()
    }

    
    func connectToRileyLink(_ device: RileyLinkDevice) {
        connectedPeripheralIDs.insert(device.peripheral.identifier.uuidString)
        
        rileyLinkManager.connectDevice(device)
    }
    
    func disconnectFromRileyLink(_ device: RileyLinkDevice) {
        connectedPeripheralIDs.remove(device.peripheral.identifier.uuidString)
        
        rileyLinkManager.disconnectDevice(device)
    }
    
    private func pumpStatusUpdateReceived(_ status: MySentryPumpStatusMessageBody, fromDevice device: RileyLinkDevice) {

        var pumpDateComponents = status.pumpDateComponents
        var glucoseDateComponents = status.glucoseDateComponents

        pumpDateComponents.timeZone = pumpState?.timeZone
        glucoseDateComponents?.timeZone = pumpState?.timeZone

        // Avoid duplicates
        if status != latestPumpStatusFromMySentry {
            latestPumpStatusFromMySentry = status
            
            // Sentry packets are sent in groups of 3, 5s apart. Wait 11s to avoid conflicting comms.
            let delay = DispatchTime.now() + .seconds(11)
            DispatchQueue.main.asyncAfter(deadline: delay) {
                self.getPumpHistory(device)
            }
            
            if status.batteryRemainingPercent == 0 {
                //NotificationManager.sendPumpBatteryLowNotification()
            }
            
            guard Config.sharedInstance().uploadEnabled, let pumpID = pumpID else {
                return
            }
            
            // Gather PumpStatus from MySentry packet
            let pumpStatus: NightscoutUploadKit.PumpStatus?
            if let pumpDate = pumpDateComponents.date {

                let batteryStatus = BatteryStatus(percent: status.batteryRemainingPercent)
                let iobStatus = IOBStatus(timestamp: pumpDate, iob: status.iob)
                
                pumpStatus = NightscoutUploadKit.PumpStatus(clock: pumpDate, pumpID: pumpID, iob: iobStatus, battery: batteryStatus, reservoir: status.reservoirRemainingUnits)
            } else {
                pumpStatus = nil
                print("Could not interpret pump clock: \(pumpDateComponents)")
            }

            // Trigger device status upload, even if something is wrong with pumpStatus
            self.uploadDeviceStatus(pumpStatus)

            // Send SGVs
            remoteDataManager.nightscoutUploader?.uploadSGVFromMySentryPumpStatus(status, device: device.deviceURI)
        }
    }
    
    private func uploadDeviceStatus(_ pumpStatus: NightscoutUploadKit.PumpStatus? /*, loopStatus: LoopStatus */) {
        
        guard let uploader = remoteDataManager.nightscoutUploader else {
            return
        }

        // Gather UploaderStatus
        let uploaderDevice = UIDevice.current
        let uploaderStatus = UploaderStatus(name: uploaderDevice.name, timestamp: Date(), battery: uploaderDevice.batteryLevel)

        // Build DeviceStatus
        let deviceStatus = DeviceStatus(device: "rileylink://" + uploaderDevice.name, timestamp: Date(), pumpStatus: pumpStatus, uploaderStatus: uploaderStatus)
        
        uploader.uploadDeviceStatus(deviceStatus)
    }
    
    /**
     Ensures pump data is current by either waking and polling, or ensuring we're listening to sentry packets.
     */
    private func assertCurrentPumpData() {
        guard let device = rileyLinkManager.firstConnectedDevice else {
            return
        }
        
        device.assertIdleListening()
        
        // How long should we wait before we poll for new pump data?
        let pumpStatusAgeTolerance = rileyLinkManager.idleListeningEnabled ? TimeInterval(minutes: 11) : TimeInterval(minutes: 4)
        
        // If we don't yet have pump status, or it's old, poll for it.
        if latestPumpStatusDate == nil || latestPumpStatusDate!.timeIntervalSinceNow <= -pumpStatusAgeTolerance {
            guard let device = rileyLinkManager.firstConnectedDevice else {
                return
            }
            
            guard let ops = device.ops else {
                self.troubleshootPumpCommsWithDevice(device)
                return
            }
            
            ops.readPumpStatus({ (result) in
                switch result {
                case .success(let status):
                    self.latestPolledPumpStatus = status
                    let battery = BatteryStatus(voltage: status.batteryVolts, status: BatteryIndicator(batteryStatus: status.batteryStatus))
                    var clock = status.clock
                    clock.timeZone = ops.pumpState.timeZone
                    guard let date = clock.date else {
                        print("Could not interpret clock")
                        return
                    }
                    let nsPumpStatus = NightscoutUploadKit.PumpStatus(clock: date, pumpID: ops.pumpState.pumpID, iob: nil, battery: battery, suspended: status.suspended, bolusing: status.bolusing, reservoir: status.reservoir)
                    self.uploadDeviceStatus(nsPumpStatus)
                case .failure:
                    self.troubleshootPumpCommsWithDevice(device)
                }
            })
        }

        if lastHistoryAttempt == nil || lastHistoryAttempt!.timeIntervalSinceNow < TimeInterval(minutes: -5) {
            getPumpHistory(device)
        }

    }

    /**
     Attempts to fix an extended communication failure between a RileyLink device and the pump
     
     - parameter device: The RileyLink device
     */
    private func troubleshootPumpCommsWithDevice(_ device: RileyLinkDevice) {
        
        // How long we should wait before we re-tune the RileyLink
        let tuneTolerance = TimeInterval(minutes: 14)
        
        if device.lastTuned == nil || device.lastTuned!.timeIntervalSinceNow <= -tuneTolerance {
            device.tunePump { (result) in
                switch result {
                case .success(let scanResult):
                    print("Device auto-tuned to \(scanResult.bestFrequency) MHz")
                case .failure(let error):
                    print("Device auto-tune failed with error: \(error)")
                }
            }
        }
    }
    
    private func getPumpHistory(_ device: RileyLinkDevice) {
        lastHistoryAttempt = Date()
        
        guard let ops = device.ops else {
            print("Missing pumpOps; is your pumpId configured?")
            return
        }
        
        
        let oneDayAgo = Date(timeIntervalSinceNow: TimeInterval(hours: -24))
        let observingPumpEventsSince = remoteDataManager.nightscoutUploader?.observingPumpEventsSince ?? oneDayAgo
        
        
        ops.getHistoryEvents(since: observingPumpEventsSince) { (response) -> Void in
            switch response {
            case .success(let (events, pumpModel)):
                NSLog("fetchHistory succeeded.")
                self.handleNewHistoryEvents(events, pumpModel: pumpModel, device: device)
                NotificationCenter.default.post(name: .PumpEventsUpdated, object: self)
            case .failure(let error):
                NSLog("History fetch failed: %@", String(describing: error))
            }
            self.getPumpGlucoseHistory(device)
        }
    }
    
    private func handleNewHistoryEvents(_ events: [TimestampedHistoryEvent], pumpModel: PumpModel, device: RileyLinkDevice) {
        // TODO: get insulin doses from history
        if Config.sharedInstance().uploadEnabled {
            remoteDataManager.nightscoutUploader?.processPumpEvents(events, source: device.deviceURI, pumpModel: pumpModel)
        }
    }
    
    private func getPumpGlucoseHistory(_ device: RileyLinkDevice) {
        lastGlucoseAttempt = Date()
        
        guard let ops = device.ops else {
            print("Missing pumpOps; is your pumpId configured?")
            return
        }
        
        
        let oneDayAgo = Date(timeIntervalSinceNow: TimeInterval(hours: -24))
        let observingPumpEventsSince = remoteDataManager.nightscoutUploader?.observingPumpEventsSince ?? oneDayAgo
        
        
        ops.getGlucoseHistoryEvents(since: observingPumpEventsSince) { (response) -> Void in
            switch response {
            case .success(let events):
                NSLog("fetchGlucoseHistory succeeded.")
                self.handleNewGlucoseHistoryEvents(events, device: device)
                //NotificationCenter.default.post(name: .PumpEventsUpdated, object: self)
                
            case .failure(let error):
                NSLog("Glucose History fetch failed: %@", String(describing: error))
            }
        }
    }
    
    private func handleNewGlucoseHistoryEvents(_ events: [TimestampedGlucoseEvent], device: RileyLinkDevice) {
        if Config.sharedInstance().uploadEnabled {
            remoteDataManager.nightscoutUploader?.processGlucoseEvents(events, source: device.deviceURI)
        }
    }
    
    // MARK: - Initialization
    
    static let sharedManager = DeviceDataManager()

    init() {
        
        let pumpID = Config.sharedInstance().pumpID

        var idleListeningEnabled = true
        
        let pumpRegion = PumpRegion(rawValue: Config.sharedInstance().pumpRegion) ?? .northAmerica
        
        if let pumpID = pumpID {
            let pumpState = PumpState(pumpID: pumpID, pumpRegion: pumpRegion)
            
            if let timeZone = Config.sharedInstance().pumpTimeZone {
                pumpState.timeZone = timeZone
            }
            
            if let pumpModelNumber = Config.sharedInstance().pumpModelNumber {
                if let model = PumpModel(rawValue: pumpModelNumber) {
                    pumpState.pumpModel = model
                    
                    idleListeningEnabled = model.hasMySentry
                }
            }
            
            self.pumpState = pumpState
        }
        
        rileyLinkManager = RileyLinkDeviceManager(
            pumpState: self.pumpState,
            autoConnectIDs: connectedPeripheralIDs
        )
        rileyLinkManager.idleListeningEnabled = idleListeningEnabled

        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(receivedRileyLinkManagerNotification(_:)), name: nil, object: rileyLinkManager)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedRileyLinkPacketNotification(_:)), name: .RileyLinkDeviceDidReceiveIdleMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedRileyLinkTimerTickNotification(_:)), name: .RileyLinkDeviceDidUpdateTimerTick, object: nil)
        
        if let pumpState = pumpState {
            NotificationCenter.default.addObserver(self, selector: #selector(pumpStateValuesDidChange(_:)), name: .PumpStateValuesDidChange, object: pumpState)
        }

    }
    
    deinit {
        rileyLinkManagerObserver = nil
        rileyLinkDevicePacketObserver = nil
    }
    
    // MARK: - Device updates
    func rileyLinkAdded(_ note: Notification)
    {
        if let device = note.object as? RileyLinkBLEDevice  {
            device.enableIdleListening(onChannel: 0)
        }
    }
    
}


extension Notification.Name {
    static let PumpEventsUpdated = Notification.Name(rawValue: "com.rileylink.notification.PumpEventsUpdated")
    static let GlucoseEventsUpdated = Notification.Name(rawValue: "com.rileylink.notification.GlucoseEventsUpdated")
}

