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
    
    var connectedPeripheralIDs: Set<String> = Config.sharedInstance().autoConnectIds as! Set<String> {
        didSet {
            Config.sharedInstance().autoConnectIds = connectedPeripheralIDs
        }
    }
    
    var latestPumpStatus: MySentryPumpStatusMessageBody?
    
    var nightscoutUploader: NightscoutUploader
    
    var pumpTimeZone: NSTimeZone? = Config.sharedInstance().pumpTimeZone {
        didSet {
            Config.sharedInstance().pumpTimeZone = pumpTimeZone
            
            if let pumpTimeZone = pumpTimeZone {
                
                if let pumpState = rileyLinkManager.pumpState {
                    pumpState.timeZone = pumpTimeZone
                }
            }
        }
    }
    
    var pumpWorldwideRadioLocale: Bool = Config.sharedInstance().worldwideRadioLocale {
        didSet {
            Config.sharedInstance().worldwideRadioLocale = pumpWorldwideRadioLocale
            
            if let worldwideRadioLocale = pumpWorldwideRadioLocale {

                if let pumpState = rileyLinkManager.pumpState {
                    pumpState.worldwideRadioLocale = worldwideRadioLocale
                }
            }
        }
    
    }
    
    var pumpID: String? = Config.sharedInstance().pumpID {
        didSet {
            if pumpID?.characters.count != 6 {
                pumpID = nil
            }
            
            if let pumpID = pumpID {
                let pumpState = PumpState(pumpID: pumpID)
                
                if let worldwideRadioLocale = pumpWorldwideRadioLocale {
                    pumpState.worldWideRadioLocale = worldwideRadioLocale
                }
                
                if let timeZone = pumpTimeZone {
                    pumpState.timeZone = timeZone
                }
                
                rileyLinkManager.pumpState = pumpState
            } else {
                rileyLinkManager.pumpState = nil
            }
            
            nightscoutUploader.pumpID = pumpID
            
            Config.sharedInstance().pumpID = pumpID
        }
    }
    
    var nightscoutURL: String? = Config.sharedInstance().nightscoutURL {
        didSet {
            if nightscoutURL?.characters.count == 0 {
                nightscoutURL = nil
            }
            
            if let nightscoutURL = nightscoutURL {
                nightscoutUploader.siteURL = nightscoutURL
            }
            
            Config.sharedInstance().nightscoutURL = nightscoutURL
        }
    }
    
    var nightscoutAPISecret: String? = Config.sharedInstance().nightscoutAPISecret {
        didSet {
            if nightscoutAPISecret?.characters.count == 0 {
                nightscoutAPISecret = nil
            }
            
            if let nightscoutAPISecret = nightscoutAPISecret {
                nightscoutUploader.APISecret = nightscoutAPISecret
            }
            
            Config.sharedInstance().nightscoutAPISecret = nightscoutAPISecret
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
    
    func receivedRileyLinkManagerNotification(note: NSNotification) {
        NSNotificationCenter.defaultCenter().postNotificationName(note.name, object: self, userInfo: note.userInfo)
    }
    
    func preferredRileyLink() -> RileyLinkDevice? {
        if let device = lastRileyLinkHeardFrom {
            return device
        }
        return self.rileyLinkManager.firstConnectedDevice
    }
    
    func receivedRileyLinkPacketNotification(note: NSNotification) {
        if let
            device = note.object as? RileyLinkDevice,
            data = note.userInfo?[RileyLinkDevice.IdleMessageDataKey] as? NSData,
            message = PumpMessage(rxData: data)
        {
            lastRileyLinkHeardFrom = device
            switch message.packetType {
            case .MySentry:
                switch message.messageBody {
                case let body as MySentryPumpStatusMessageBody:
                    updatePumpStatus(body, fromDevice: device)
                case is MySentryAlertMessageBody:
                    break
                    // TODO: de-dupe
                //                    logger?.addMessage(body.dictionaryRepresentation, toCollection: "sentryAlert")
                case is MySentryAlertClearedMessageBody:
                    break
                    // TODO: de-dupe
                //                    logger?.addMessage(body.dictionaryRepresentation, toCollection: "sentryAlert")
                case is UnknownMessageBody:
                    break
                    //logger?.addMessage(body.dictionaryRepresentation, toCollection: "sentryOther")
                default:
                    break
                }
            default:
                break
            }
        }
    }
    
    func connectToRileyLink(device: RileyLinkDevice) {
        connectedPeripheralIDs.insert(device.peripheral.identifier.UUIDString)
        
        rileyLinkManager.connectDevice(device)
    }
    
    func disconnectFromRileyLink(device: RileyLinkDevice) {
        connectedPeripheralIDs.remove(device.peripheral.identifier.UUIDString)
        
        rileyLinkManager.disconnectDevice(device)
    }
    
    private func updatePumpStatus(status: MySentryPumpStatusMessageBody, fromDevice device: RileyLinkDevice) {
        status.pumpDateComponents.timeZone = pumpTimeZone
        status.glucoseDateComponents?.timeZone = pumpTimeZone
        
        if status != latestPumpStatus {
            latestPumpStatus = status
            
            if status.batteryRemainingPercent == 0 {
                //NotificationManager.sendPumpBatteryLowNotification()
            }
            if Config.sharedInstance().uploadEnabled {
                nightscoutUploader.handlePumpStatus(status, device: device.deviceURI)
            }
            
            // Sentry packets are sent in groups of 3, 5s apart. Wait 11s to avoid conflicting comms.
            let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(11 * NSEC_PER_SEC))
            dispatch_after(delay, dispatch_get_main_queue()) {
                self.getPumpHistory(device)
            }
        }
    }
    
    private func getPumpHistory(device: RileyLinkDevice) {
        lastHistoryAttempt = NSDate()
        device.ops!.getHistoryEventsSinceDate(nightscoutUploader.observingPumpEventsSince) { (response) -> Void in
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
        // TODO: upload events to Nightscout
        if Config.sharedInstance().uploadEnabled {
            nightscoutUploader.processPumpEvents(events, source: device.deviceURI, pumpModel: pumpModel)
        }
    }
    
    // MARK: - Initialization
    
    static let sharedManager = DeviceDataManager()

    init() {
        
        let pumpState: PumpState?
        
        if let pumpID = pumpID {
            let worldwideRadioLocale = Config.sharedInstance().worldwideRadioLocale

            pumpState = PumpState(pumpID: pumpID)
            
            if let timeZone = pumpTimeZone {
                pumpState?.timeZone = timeZone
            }

            if let worldwideRadioLocale = pumpWorldwideRadioLocale {
                pumpState?.worldwideRadioLocale = worldwideRadioLocale
            }
} else {
            pumpState = nil
        }
        
        rileyLinkManager = RileyLinkDeviceManager(
            pumpState: pumpState,
            autoConnectIDs: connectedPeripheralIDs
        )
        
        nightscoutUploader = NightscoutUploader(siteURL: nightscoutURL, APISecret: nightscoutAPISecret, pumpID: pumpID)
        nightscoutUploader.errorHandler = { (error: ErrorType, context: String) -> Void in
            print("Error \(error), while \(context)")
        }
        nightscoutUploader.pumpID = pumpID
        
        getHistoryTimer = NSTimer.scheduledTimerWithTimeInterval(5.0 * 60, target:self, selector:#selector(DeviceDataManager.timerTriggered), userInfo:nil, repeats:true)
        
        // This triggers one history fetch right away (in 10s)
//        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(10 * Double(NSEC_PER_SEC)))
//        dispatch_after(delayTime, dispatch_get_main_queue()) {
//            if let rl = DeviceDataManager.sharedManager.preferredRileyLink() {
//                DeviceDataManager.sharedManager.getPumpHistory(rl)
//            }
//        }

        UIDevice.currentDevice().batteryMonitoringEnabled = true
        
        rileyLinkManager.timerTickEnabled = false
        rileyLinkManagerObserver = NSNotificationCenter.defaultCenter().addObserverForName(nil, object: rileyLinkManager, queue: nil) { [weak self] (note) -> Void in
            self?.receivedRileyLinkManagerNotification(note)
        }
        
        // TODO: Use delegation instead.
        rileyLinkDevicePacketObserver = NSNotificationCenter.defaultCenter().addObserverForName(RileyLinkDevice.DidReceiveIdleMessageNotification, object: nil, queue: nil) { [weak self] (note) -> Void in
            self?.receivedRileyLinkPacketNotification(note)
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
    
    @objc func timerTriggered() {
        logMemUsage()
        
        if lastHistoryAttempt == nil || lastHistoryAttempt!.timeIntervalSinceNow < (-5 * 60) {
            NSLog("No fetchHistory for over five minutes.  Triggering one")
            if let device = preferredRileyLink() {
                getPumpHistory(device)
            } else {
                NSLog("No RileyLink available to fetch history with!")
            }
        }
    }
}