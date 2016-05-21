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
    
    private var observingPumpEventsSince: NSDate
    
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

    var pumpID: String? = Config.sharedInstance().pumpID {
        didSet {
            if pumpID?.characters.count != 6 {
                pumpID = nil
            }
            
            if let pumpID = pumpID {
                let pumpState = PumpState(pumpID: pumpID)
                
                if let timeZone = pumpTimeZone {
                    pumpState.timeZone = timeZone
                }
                
                rileyLinkManager.pumpState = pumpState
            } else {
                rileyLinkManager.pumpState = nil
            }
            
            Config.sharedInstance().pumpID = pumpID
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
        
        if status != latestPumpStatus {
            latestPumpStatus = status
            
            if status.batteryRemainingPercent == 0 {
                //NotificationManager.sendPumpBatteryLowNotification()
            }
            let source = "rileylink://medtronic/\(device.name)"
            if Config.sharedInstance().uploadEnabled {
                nightscoutUploader.handlePumpStatus(status, device: source)
            }
            
            // Sentry packets are sent in groups of 3, 5s apart. Wait 11s to avoid conflicting comms.
            let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(11 * NSEC_PER_SEC))
            dispatch_after(delay, dispatch_get_main_queue()) {
                self.getPumpHistory(device)
            }
        }
    }
    
    private func getPumpHistory(device: RileyLinkDevice) {
        device.ops!.getHistoryEventsSinceDate(observingPumpEventsSince) { (response) -> Void in
            switch response {
            case .Success(let (events, pumpModel)):
                NSLog("fetchHistory succeeded.")
                self.handleNewHistoryEvents(events, pumpModel: pumpModel)
                NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.PumpEventsUpdatedNotification, object: self)
                
            case .Failure(let error):
                NSLog("History fetch failed: %@", String(error))
            }
        }
    }
    
    private func handleNewHistoryEvents(events: [PumpEvent], pumpModel: PumpModel) {
        // TODO: get insulin doses from history
        // TODO: upload events to Nightscout
        let source = "rileylink://medtronic/\(pumpModel)"
        if Config.sharedInstance().uploadEnabled {
            nightscoutUploader.processPumpEvents(events, source: source, pumpModel: pumpModel)
        }
    }
    
    // MARK: - Initialization
    
    static let sharedManager = DeviceDataManager()

    init() {
        
        let pumpState: PumpState?
        
        if let pumpID = pumpID {
            pumpState = PumpState(pumpID: pumpID)
            
            if let timeZone = pumpTimeZone {
                pumpState?.timeZone = timeZone
            }
        } else {
            pumpState = nil
        }
        
        rileyLinkManager = RileyLinkDeviceManager(
            pumpState: pumpState,
            autoConnectIDs: connectedPeripheralIDs
        )
        
        nightscoutUploader = NightscoutUploader()
        nightscoutUploader.siteURL = Config.sharedInstance().nightscoutURL
        nightscoutUploader.APISecret = Config.sharedInstance().nightscoutAPISecret
        
        
        let calendar = NSCalendar.currentCalendar()
        observingPumpEventsSince = calendar.dateByAddingUnit(.Day, value: -1, toDate: NSDate(), options: [])!
        
        getHistoryTimer = NSTimer.scheduledTimerWithTimeInterval(5.0 * 60, target:self, selector:#selector(DeviceDataManager.timerTriggered), userInfo:nil, repeats:true)
        
        // This triggers one history fetch right away (in 10s)
        //performSelector(#selector(DeviceDataManager.fetchHistory), withObject: nil, afterDelay: 10)
        
        // This is to just test decoding history
        //performSelector(Selector("testDecodeHistory"), withObject: nil, afterDelay: 1)
        
        // Test storing MySentry packet:
        //[self performSelector:@selector(testHandleMySentry) withObject:nil afterDelay:10];
        
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