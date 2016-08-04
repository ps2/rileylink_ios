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
    
    static let PumpEventsUpdatedNotification = "com.rileylink.notification.PumpEventsUpdated"

    var getHistoryTimer: NSTimer?
    
    let rileyLinkManager: RileyLinkDeviceManager
    
    /// Manages remote data (TODO: the lazy initialization isn't thread-safe)
    lazy var remoteDataManager = RemoteDataManager()
    
    var connectedPeripheralIDs: Set<String> = Config.sharedInstance().autoConnectIds as! Set<String> {
        didSet {
            Config.sharedInstance().autoConnectIds = connectedPeripheralIDs
        }
    }
    
    var latestPumpStatusDate: NSDate?
    
    var latestPumpStatusFromMySentry: MySentryPumpStatusMessageBody? {
        didSet {
            if let update = latestPumpStatusFromMySentry, let timeZone = pumpState?.timeZone {
                let pumpClock = update.pumpDateComponents
                pumpClock.timeZone = timeZone
                latestPumpStatusDate = pumpClock.date
            }
        }
    }
    
    
    var latestPolledPumpStatus: RileyLinkKit.PumpStatus? {
        didSet {
            if let update = latestPolledPumpStatus, let timeZone = pumpState?.timeZone {
                let pumpClock = update.clock
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
                let pumpState = PumpState(pumpID: pumpID)
                
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
    
    var pumpState: PumpState? {
        didSet {
            rileyLinkManager.pumpState = pumpState
            
            if let oldValue = oldValue {
                NSNotificationCenter.defaultCenter().removeObserver(self, name: PumpState.ValuesDidChangeNotification, object: oldValue)
            }
            
            if let pumpState = pumpState {
                NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(pumpStateValuesDidChange(_:)), name: PumpState.ValuesDidChangeNotification, object: pumpState)
            }
        }
    }
    
    @objc private func pumpStateValuesDidChange(note: NSNotification) {
        switch note.userInfo?[PumpState.PropertyKey] as? String {
        case "timeZone"?:
            Config.sharedInstance().pumpTimeZone = pumpState?.timeZone
        case "pumpModel"?:
            if let sentrySupported = pumpState?.pumpModel?.larger {
                rileyLinkManager.idleListeningEnabled = sentrySupported
            }
            Config.sharedInstance().pumpModelNumber = pumpState?.pumpModel?.rawValue
        case "lastHistoryDump"?, "awakeUntil"?:
            break
        default:
            break
        }
    }
    
    var lastHistoryAttempt: NSDate? = nil
    
    var lastRileyLinkHeardFrom: RileyLinkDevice? = nil
    
    
    var rileyLinkManagerObserver: AnyObject? {
        willSet {
            if let observer = rileyLinkManagerObserver {
                NSNotificationCenter.defaultCenter().removeObserver(observer)
            }
        }
    }
    
    var rileyLinkDevicePacketObserver: AnyObject? {
        willSet {
            if let observer = rileyLinkDevicePacketObserver {
                NSNotificationCenter.defaultCenter().removeObserver(observer)
            }
        }
    }
    
    @objc private func receivedRileyLinkManagerNotification(note: NSNotification) {
        NSNotificationCenter.defaultCenter().postNotificationName(note.name, object: self, userInfo: note.userInfo)
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
    @objc private func receivedRileyLinkPacketNotification(note: NSNotification) {
        if let
            device = note.object as? RileyLinkDevice,
            data = note.userInfo?[RileyLinkDevice.IdleMessageDataKey] as? NSData,
            message = PumpMessage(rxData: data)
        {
            switch message.packetType {
            case .MySentry:
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
    
    @objc private func receivedRileyLinkTimerTickNotification(note: NSNotification) {
        self.assertCurrentPumpData()
    }

    
    func connectToRileyLink(device: RileyLinkDevice) {
        connectedPeripheralIDs.insert(device.peripheral.identifier.UUIDString)
        
        rileyLinkManager.connectDevice(device)
    }
    
    func disconnectFromRileyLink(device: RileyLinkDevice) {
        connectedPeripheralIDs.remove(device.peripheral.identifier.UUIDString)
        
        rileyLinkManager.disconnectDevice(device)
    }
    
    private func pumpStatusUpdateReceived(status: MySentryPumpStatusMessageBody, fromDevice device: RileyLinkDevice) {
        status.pumpDateComponents.timeZone = pumpState?.timeZone
        status.glucoseDateComponents?.timeZone = pumpState?.timeZone

        // Avoid duplicates
        if status != latestPumpStatusFromMySentry {
            latestPumpStatusFromMySentry = status
            
            // Sentry packets are sent in groups of 3, 5s apart. Wait 11s to avoid conflicting comms.
            let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(11 * NSEC_PER_SEC))
            dispatch_after(delay, dispatch_get_main_queue()) {
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
            if let pumpDate = status.pumpDateComponents.date {

                let batteryStatus = BatteryStatus(percent: status.batteryRemainingPercent)
                let iobStatus = IOBStatus(timestamp: pumpDate, iob: status.iob)
                
                pumpStatus = NightscoutUploadKit.PumpStatus(clock: pumpDate, pumpID: pumpID, iob: iobStatus, battery: batteryStatus, reservoir: status.reservoirRemainingUnits)
            } else {
                pumpStatus = nil
                print("Could not interpret pump clock: \(status.pumpDateComponents)")
            }

            // Trigger device status upload, even if something is wrong with pumpStatus
            self.uploadDeviceStatus(pumpStatus)

            // Send SGVs
            remoteDataManager.nightscoutUploader?.uploadSGVFromMySentryPumpStatus(status, device: device.deviceURI)
        }
    }
    
    private func uploadDeviceStatus(pumpStatus: NightscoutUploadKit.PumpStatus? /*, loopStatus: LoopStatus */) {
        
        guard let uploader = remoteDataManager.nightscoutUploader else {
            return
        }

        // Gather UploaderStatus
        let uploaderDevice = UIDevice.currentDevice()
        
        let battery: Int?
        if uploaderDevice.batteryMonitoringEnabled {
            battery = Int(uploaderDevice.batteryLevel * 100)
        } else {
            battery = nil
        }
        let uploaderStatus = UploaderStatus(name: uploaderDevice.name, timestamp: NSDate(), battery: battery)

        // Build DeviceStatus
        let deviceStatus = DeviceStatus(device: "rileylink://" + uploaderDevice.name, timestamp: NSDate(), pumpStatus: pumpStatus, uploaderStatus: uploaderStatus)
        
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
        let pumpStatusAgeTolerance = rileyLinkManager.idleListeningEnabled ? NSTimeInterval(minutes: 11) : NSTimeInterval(minutes: 4)
        
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
                case .Success(let status):
                    self.latestPolledPumpStatus = status
                    let battery = BatteryStatus(voltage: status.batteryVolts, status: BatteryIndicator(batteryStatus: status.batteryStatus))
                    status.clock.timeZone = ops.pumpState.timeZone
                    guard let date = status.clock.date else {
                        print("Could not interpret clock")
                        return
                    }
                    let nsPumpStatus = NightscoutUploadKit.PumpStatus(clock: date, pumpID: ops.pumpState.pumpID, iob: nil, battery: battery, suspended: status.suspended, bolusing: status.bolusing, reservoir: status.reservoir)
                    self.uploadDeviceStatus(nsPumpStatus)
                case .Failure:
                    self.troubleshootPumpCommsWithDevice(device)
                }
            })
        }

        if lastHistoryAttempt == nil || lastHistoryAttempt!.timeIntervalSinceNow < (-5 * 60) {
            getPumpHistory(device)
        }

    }

    /**
     Attempts to fix an extended communication failure between a RileyLink device and the pump
     
     - parameter device: The RileyLink device
     */
    private func troubleshootPumpCommsWithDevice(device: RileyLinkDevice) {
        
        // How long we should wait before we re-tune the RileyLink
        let tuneTolerance = NSTimeInterval(minutes: 14)
        
        if device.lastTuned?.timeIntervalSinceNow <= -tuneTolerance {
            device.tunePumpWithResultHandler { (result) in
                switch result {
                case .Success(let scanResult):
                    print("Device auto-tuned to \(scanResult.bestFrequency) MHz")
                case .Failure(let error):
                    print("Device auto-tune failed with error: \(error)")
                }
            }
        }
    }
    
    private func getPumpHistory(device: RileyLinkDevice) {
        lastHistoryAttempt = NSDate()
        
        guard let ops = device.ops else {
            print("Missing pumpOps; is your pumpId configured?")
            return
        }
        
        
        let oneDayAgo = NSDate(timeIntervalSinceNow: NSTimeInterval(hours: -24))
        let observingPumpEventsSince = remoteDataManager.nightscoutUploader?.observingPumpEventsSince ?? oneDayAgo

        
        ops.getHistoryEventsSinceDate(observingPumpEventsSince) { (response) -> Void in
            switch response {
            case .Success(let (events, pumpModel)):
                NSLog("fetchHistory succeeded.")
                self.handleNewHistoryEvents(events, pumpModel: pumpModel, device: device)
                NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.PumpEventsUpdatedNotification, object: self)
                
            case .Failure(let error):
                NSLog("History fetch failed: %@", String(error))
            }
        }
    }
    
    private func handleNewHistoryEvents(events: [TimestampedHistoryEvent], pumpModel: PumpModel, device: RileyLinkDevice) {
        // TODO: get insulin doses from history
        if Config.sharedInstance().uploadEnabled {
            remoteDataManager.nightscoutUploader?.processPumpEvents(events, source: device.deviceURI, pumpModel: pumpModel)
        }
    }
    
    // MARK: - Initialization
    
    static let sharedManager = DeviceDataManager()

    init() {
        
        let pumpID = Config.sharedInstance().pumpID

        var idleListeningEnabled = true
        
        if let pumpID = pumpID {
            let pumpState = PumpState(pumpID: pumpID)
            
            if let timeZone = Config.sharedInstance().pumpTimeZone {
                pumpState.timeZone = timeZone
            }
            
            if let pumpModelNumber = Config.sharedInstance().pumpModelNumber {
                if let model = PumpModel(rawValue: pumpModelNumber) {
                    pumpState.pumpModel = model
                    
                    idleListeningEnabled = model.larger
                }
            }
            
            self.pumpState = pumpState
        }
        
        rileyLinkManager = RileyLinkDeviceManager(
            pumpState: self.pumpState,
            autoConnectIDs: connectedPeripheralIDs
        )
        rileyLinkManager.idleListeningEnabled = idleListeningEnabled

        UIDevice.currentDevice().batteryMonitoringEnabled = true
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(receivedRileyLinkManagerNotification(_:)), name: nil, object: rileyLinkManager)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(receivedRileyLinkPacketNotification(_:)), name: RileyLinkDevice.DidReceiveIdleMessageNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(receivedRileyLinkTimerTickNotification(_:)), name: RileyLinkDevice.DidUpdateTimerTickNotification, object: nil)
        
        if let pumpState = pumpState {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(pumpStateValuesDidChange(_:)), name: PumpState.ValuesDidChangeNotification, object: pumpState)
        }

    }
    
    deinit {
        rileyLinkManagerObserver = nil
        rileyLinkDevicePacketObserver = nil
    }
    
    // MARK: - Device updates
    func rileyLinkAdded(note: NSNotification)
    {
        if let device = note.object as? RileyLinkBLEDevice  {
            device.enableIdleListeningOnChannel(0)
        }
    }
    
}