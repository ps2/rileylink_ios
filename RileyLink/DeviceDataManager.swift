//
//  DeviceDataManager.swift
//  RileyLink
//
//  Created by Pete Schwamb on 4/27/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkKit
import RileyLinkKitUI
import RileyLinkBLEKit
import MinimedKit
import NightscoutUploadKit

class DeviceDataManager {

    let rileyLinkManager: RileyLinkDeviceManager
    
    /// Manages remote data
    let remoteDataManager = RemoteDataManager()
    
    private var connectedPeripheralIDs: Set<String> = Config.sharedInstance().autoConnectIds as! Set<String> {
        didSet {
            Config.sharedInstance().autoConnectIds = connectedPeripheralIDs
        }
    }

    var deviceStates: [UUID: DeviceState] = [:]

    private(set) var pumpOps: PumpOps? {
        didSet {
            if pumpOps == nil {
                UserDefaults.standard.pumpState = nil
            }
        }
    }

    private(set) var pumpSettings: PumpSettings? {
        get {
            return UserDefaults.standard.pumpSettings
        }
        set {
            if let settings = newValue {
                if let pumpOps = pumpOps {
                    pumpOps.updateSettings(settings)
                } else {
                    pumpOps = PumpOps(pumpSettings: settings, pumpState: nil, delegate: self)
                }
            } else {
                pumpOps = nil
            }

            UserDefaults.standard.pumpSettings = newValue
        }
    }

    func setPumpID(_ pumpID: String?) {
        var newValue = pumpID

        if newValue?.count != 6 {
            newValue = nil
        }

        if let newValue = newValue {
            if pumpSettings != nil {
                pumpSettings?.pumpID = newValue
            } else {
                pumpSettings = PumpSettings(pumpID: newValue)
            }
        }
    }

    func setPumpRegion(_ pumpRegion: PumpRegion) {
        pumpSettings?.pumpRegion = pumpRegion
    }
    
    var pumpState: PumpState? {
        return UserDefaults.standard.pumpState
    }

    // MARK: - Operation helpers

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
            if let update = latestPolledPumpStatus {
                latestPumpStatusDate = update.clock.date
            }
        }
    }

    var lastHistoryAttempt: Date? = nil
    
    var lastGlucoseEntry: Date = Date(timeIntervalSinceNow: TimeInterval(hours: -24))

    /**
     Called when a new idle message is received by the RileyLink.
     
     Only MySentryPumpStatus messages are handled.
     
     - parameter note: The notification object
     */
    @objc private func receivedRileyLinkPacketNotification(_ note: Notification) {
        guard
            let device = note.object as? RileyLinkDevice,
            let packet = note.userInfo?[RileyLinkDevice.notificationPacketKey] as? RFPacket,
            let decoded = MinimedPacket(encodedData: packet.data),
            let message = PumpMessage(rxData: decoded.data),
            let address = pumpSettings?.pumpID,
            message.address.hexadecimalString == address
        else {
            return
        }

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
    
    @objc private func receivedRileyLinkTimerTickNotification(_ note: Notification) {
        if Config.sharedInstance().uploadEnabled {
            rileyLinkManager.getDevices { (devices) in
                if let device = devices.firstConnected {
                    self.assertCurrentPumpData(from: device)
                }
            }
        }
    }

    @objc private func deviceStateDidChange(_ note: Notification) {
        guard
            let device = note.object as? RileyLinkDevice,
            let deviceState = note.userInfo?[RileyLinkDevice.notificationDeviceStateKey] as? DeviceState
        else {
            return
        }

        deviceStates[device.peripheralIdentifier] = deviceState
    }
    
    func connectToRileyLink(_ device: RileyLinkDevice) {
        connectedPeripheralIDs.insert(device.peripheralIdentifier.uuidString)
        
        rileyLinkManager.connect(device)
    }
    
    func disconnectFromRileyLink(_ device: RileyLinkDevice) {
        connectedPeripheralIDs.remove(device.peripheralIdentifier.uuidString)
        
        rileyLinkManager.disconnect(device)
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
            
            guard Config.sharedInstance().uploadEnabled, let pumpID = pumpSettings?.pumpID else {
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
    private func assertCurrentPumpData(from device: RileyLinkDevice) {
        device.assertIdleListening()
        
        // How long should we wait before we poll for new pump data?
        let pumpStatusAgeTolerance = rileyLinkManager.idleListeningEnabled ? TimeInterval(minutes: 11) : TimeInterval(minutes: 4)
        
        // If we don't yet have pump status, or it's old, poll for it.
        if latestPumpStatusDate == nil || latestPumpStatusDate!.timeIntervalSinceNow <= -pumpStatusAgeTolerance {
            
            guard let pumpOps = pumpOps else {
                self.troubleshootPumpCommsWithDevice(device)
                return
            }

            pumpOps.runSession(withName: "Read pump status", using: device) { (session) in
                do {
                    let status = try session.getCurrentPumpStatus()
                    DispatchQueue.main.async {
                        self.latestPolledPumpStatus = status
                        let battery = BatteryStatus(voltage: status.batteryVolts.converted(to: .volts).value, status: BatteryIndicator(batteryStatus: status.batteryStatus))
                        guard let date = status.clock.date else {
                            print("Could not interpret clock")
                            return
                        }
                        let nsPumpStatus = NightscoutUploadKit.PumpStatus(clock: date, pumpID: status.pumpID, iob: nil, battery: battery, suspended: status.suspended, bolusing: status.bolusing, reservoir: status.reservoir)
                        self.uploadDeviceStatus(nsPumpStatus)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.troubleshootPumpCommsWithDevice(device)
                    }
                }
            }
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

        guard let pumpOps = pumpOps else {
            return
        }

        let deviceState = deviceStates[device.peripheralIdentifier, default: DeviceState()]
        let lastTuned = deviceState.lastTuned ?? .distantPast

        if lastTuned.timeIntervalSinceNow <= -tuneTolerance {
            pumpOps.runSession(withName: "Tune pump", using: device) { (session) in
                do {
                    let scanResult = try session.tuneRadio(current: deviceState.lastValidFrequency)
                    print("Device auto-tuned to \(scanResult.bestFrequency)")

                    DispatchQueue.main.async {
                        self.deviceStates[device.peripheralIdentifier] = DeviceState(lastTuned: Date(), lastValidFrequency: scanResult.bestFrequency)
                    }
                } catch let error {
                    print("Device auto-tune failed with error: \(error)")
                }
            }
        }
    }
    
    private func getPumpHistory(_ device: RileyLinkDevice) {
        lastHistoryAttempt = Date()

        guard let pumpOps = pumpOps else {
            print("Missing pumpOps; is your pumpId configured?")
            return
        }

        let oneDayAgo = Date(timeIntervalSinceNow: TimeInterval(hours: -24))

        pumpOps.runSession(withName: "Get pump history", using: device) { (session) in
            do {
                let (events, pumpModel) = try session.getHistoryEvents(since: oneDayAgo)
                NSLog("fetchHistory succeeded.")
                DispatchQueue.main.async {
                    self.handleNewHistoryEvents(events, pumpModel: pumpModel, device: device)
                }
            } catch let error {
                NSLog("History fetch failed: %@", String(describing: error))
            }

            if Config.sharedInstance().fetchCGMEnabled, self.lastGlucoseEntry.timeIntervalSinceNow < TimeInterval(minutes: -5) {
                self.getPumpGlucoseHistory(device)
            }
        }
    }
    
    private func handleNewHistoryEvents(_ events: [TimestampedHistoryEvent], pumpModel: PumpModel, device: RileyLinkDevice) {
        // TODO: get insulin doses from history
        if Config.sharedInstance().uploadEnabled {
            remoteDataManager.nightscoutUploader?.processPumpEvents(events, source: device.deviceURI, pumpModel: pumpModel)
        }
    }
    
    private func getPumpGlucoseHistory(_ device: RileyLinkDevice) {
        guard let pumpOps = pumpOps else {
            print("Missing pumpOps; is your pumpId configured?")
            return
        }

        pumpOps.runSession(withName: "Get glucose history", using: device) { (session) in
            do {
                let events = try session.getGlucoseHistoryEvents(since: self.lastGlucoseEntry)
                NSLog("fetchGlucoseHistory succeeded.")
                if let latestEntryDate: Date = self.handleNewGlucoseHistoryEvents(events, device: device) {
                    self.lastGlucoseEntry = latestEntryDate
                }
            } catch let error {
                NSLog("Glucose History fetch failed: %@", String(describing: error))
            }
        }
    }
    
    private func handleNewGlucoseHistoryEvents(_ events: [TimestampedGlucoseEvent], device: RileyLinkDevice) -> Date? {
        if Config.sharedInstance().uploadEnabled {
            return remoteDataManager.nightscoutUploader?.processGlucoseEvents(events, source: device.deviceURI)
        }
        return nil
    }
    
    // MARK: - Initialization
    
    static let sharedManager = DeviceDataManager()

    init() {
        rileyLinkManager = RileyLinkDeviceManager(autoConnectIDs: connectedPeripheralIDs)

        var idleListeningEnabled = true
        
        if let pumpSettings = UserDefaults.standard.pumpSettings {
            idleListeningEnabled = self.pumpState?.pumpModel?.hasMySentry ?? true

            self.pumpOps = PumpOps(pumpSettings: pumpSettings, pumpState: self.pumpState, delegate: self)
        }
        
        rileyLinkManager.idleListeningState = idleListeningEnabled ? .enabledWithDefaults : .disabled

        UIDevice.current.isBatteryMonitoringEnabled = true

        // Device observers
        NotificationCenter.default.addObserver(self, selector: #selector(receivedRileyLinkPacketNotification(_:)), name: .DevicePacketReceived, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedRileyLinkTimerTickNotification(_:)), name: .DeviceTimerDidTick, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceStateDidChange(_:)), name: .DeviceStateDidChange, object: nil)
    }
}


extension DeviceDataManager: PumpOpsDelegate {
    func pumpOps(_ pumpOps: PumpOps, didChange state: PumpState) {
        if let sentrySupported = state.pumpModel?.hasMySentry {
            rileyLinkManager.idleListeningState = sentrySupported ? .enabledWithDefaults : .disabled
        }

        UserDefaults.standard.pumpState = state

        NotificationCenter.default.post(
            name: .PumpOpsStateDidChange,
            object: pumpOps,
            userInfo: [PumpOps.notificationPumpStateKey: state]
        )
    }
}
