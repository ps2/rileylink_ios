//
//  NightscoutUploader.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit
import Crypto

public class NightscoutUploader: NSObject {

    enum DexcomSensorError: UInt8 {
        case SensorNotActive = 1
        case SensorNotCalibrated = 5
        case BadRF = 12
    }
    
    public var siteURL: String?
    public var APISecret: String?
    
    var entries: [AnyObject]
    var deviceStatuses: [AnyObject]
    var treatmentsQueue: [AnyObject]
    
    var lastMeterMessageRxTime: NSDate?
    
    var observingPumpEventsSince: NSDate
    
    let defaultNightscoutEntriesPath = "/api/v1/entries.json"
    let defaultNightscoutTreatmentPath = "/api/v1/treatments.json"
    let defaultNightscoutDeviceStatusPath = "/api/v1/devicestatus.json"

    public override init() {
        entries = [AnyObject]()
        treatmentsQueue = [AnyObject]()
        deviceStatuses = [AnyObject]()
        
        let calendar = NSCalendar.currentCalendar()
        observingPumpEventsSince = calendar.dateByAddingUnit(.Day, value: -1, toDate: NSDate(), options: [])!
        
        super.init()
    }
    
    // MARK: - Decoding Treatments
    
    public func processPumpEvents(events: [TimestampedHistoryEvent], source: String, pumpModel: PumpModel) {
        
        // Find valid event times
        let newestEventTime = events.last?.date
        
        // Find the oldest event that might still be updated.
        var oldestUpdatingEventDate: NSDate?

        for event in events {
            switch event.pumpEvent {
            case let bolus as BolusNormalPumpEvent:
                let deliveryFinishDate = event.date.dateByAddingTimeInterval(bolus.duration)
                if newestEventTime == nil || deliveryFinishDate.compare(newestEventTime!) == .OrderedDescending {
                    // This event might still be updated.
                    oldestUpdatingEventDate = event.date
                    break
                }
            default:
                continue
            }
        }
        
        if oldestUpdatingEventDate != nil {
            observingPumpEventsSince = oldestUpdatingEventDate!
        } else if newestEventTime != nil {
            observingPumpEventsSince = newestEventTime!
        }
        NSLog("Updated fetch start time to %@", observingPumpEventsSince)
        
        for treatment in NightscoutPumpEvents.translate(events, eventSource: source) {
            addTreatment(treatment, pumpModel:pumpModel)
        }
        self.flushAll()
    }
    
    func addTreatment(treatment:NightscoutTreatment, pumpModel:PumpModel) {
        var rep = treatment.dictionaryRepresentation
        if rep["created_at"] == nil && rep["timestamp"] != nil {
            rep["created_at"] = rep["timestamp"]
        }
        if rep["created_at"] == nil {
            rep["created_at"] = TimeFormat.timestampStrFromDate(NSDate())
        }
        treatmentsQueue.append(rep)
    }
    
    
    //  Entries [ { sgv: 375,
    //    date: 1432421525000,
    //    dateString: '2015-05-23T22:52:05.000Z',
    //    trend: 1,
    //    direction: 'DoubleUp',
    //    device: 'share2',
    //    type: 'sgv' } ]
    
    public func handlePumpStatus(status: MySentryPumpStatusMessageBody, device: String) {
        
        enum DexcomSensorErrorType: Int {
            case DX_SENSOR_NOT_ACTIVE = 1
            case DX_SENSOR_NOT_CALIBRATED = 5
            case DX_BAD_RF = 12
        }
        
        var recordSGV = true
        
        let glucose: Int = {
            switch status.glucose {
            case .Active(glucose: let glucose):
                return glucose
            case .HighBG:
                return 401
            case .WeakSignal:
                return DexcomSensorErrorType.DX_BAD_RF.rawValue
            case .MeterBGNow, .CalError:
                return DexcomSensorErrorType.DX_SENSOR_NOT_CALIBRATED.rawValue
            case .Lost, .Missing, .Ended, .Unknown, .Off, .Warmup:
                recordSGV = false
                return DexcomSensorErrorType.DX_SENSOR_NOT_ACTIVE.rawValue
            }
        }()
        
        // Create deviceStatus record from this mysentry packet
        
        var nsStatus = [String: AnyObject]()
        
        nsStatus["device"] = device
        nsStatus["created_at"] = TimeFormat.timestampStrFromDate(NSDate())
        
        // TODO: use battery monitoring to post updates if we're not hearing from pump?
        
        let uploaderDevice = UIDevice.currentDevice()
        
        if uploaderDevice.batteryMonitoringEnabled {
            nsStatus["uploader"] = ["battery":uploaderDevice.batteryLevel * 100]
        }
        
        let pumpDate = TimeFormat.timestampStr(status.pumpDateComponents)
        
        nsStatus["pump"] = [
            "clock": pumpDate,
            "iob": [
                "timestamp": pumpDate,
                "bolusiob": status.iob,
            ],
            "reservoir": status.reservoirRemainingUnits,
            "battery": [
                "percent": status.batteryRemainingPercent
            ]
        ]
        
        switch status.glucose {
        case .Active(glucose: _):
            nsStatus["sensor"] = [
                "sensorAge": status.sensorAgeHours,
                "sensorRemaining": status.sensorRemainingHours,
            ]
        default:
            nsStatus["sensorNotActive"] = true
        }
        deviceStatuses.append(nsStatus)
        
        
        // Create SGV entry from this mysentry packet
        if (recordSGV) {
            var entry: [String: AnyObject] = [
                "sgv": glucose,
                "device": device,
                "type": "sgv"
            ]
            if let sensorDateComponents = status.glucoseDateComponents,
                let sensorDate = TimeFormat.timestampAsLocalDate(sensorDateComponents) {
                entry["date"] = sensorDate.timeIntervalSince1970 * 1000
                entry["dateString"] = TimeFormat.timestampStr(sensorDateComponents)
            }
            switch status.previousGlucose {
            case .Active(glucose: let previousGlucose):
                entry["previousSGV"] = previousGlucose
            default:
                entry["previousSGVNotActive"] = true
            }
            entry["direction"] = {
                switch status.glucoseTrend {
                case .Up:
                    return "SingleUp"
                case .UpUp:
                    return "DoubleUp"
                case .Down:
                    return "SingleDown"
                case .DownDown:
                    return "DoubleDown"
                case .Flat:
                    return "Flat"
                }
                }()
            entries.append(entry)
        }
    }
    
    public func handleMeterMessage(msg: MeterMessage) {
        
        // TODO: Should only accept meter messages from specified meter ids.
        // Need to add an interface to allow user to specify linked meters.
        
        if msg.ackFlag {
            return
        }
        
        let date = NSDate()
        let epochTime = date.timeIntervalSince1970 * 1000
        let entry = [
            "date": epochTime,
            "dateString": TimeFormat.timestampStrFromDate(date),
            "mbg": msg.glucose,
            "device": "Contour Next Link",
            "type": "mbg"
        ]
        
        // Skip duplicates
        if lastMeterMessageRxTime == nil || lastMeterMessageRxTime!.timeIntervalSinceNow < -3 * 60 {
            entries.append(entry)
            lastMeterMessageRxTime = NSDate()
        }
    }
    
    // MARK: - Uploading
    
    func flushAll() {
        
        flushDeviceStatuses()
        flushEntries()
        flushTreatments()
    }
    
    func uploadToNS(json: [AnyObject], endpoint:String, completion: (String?) -> Void) {
        if json.count == 0 {
            completion(nil)
            return
        }
        
        if let siteURL = siteURL,
            let APISecret = APISecret,
            let uploadURL = NSURL(string: endpoint, relativeToURL: NSURL(string: siteURL)) {
            let request = NSMutableURLRequest(URL: uploadURL)
            do {
                let sendData = try NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions.PrettyPrinted)
                request.HTTPMethod = "POST"
                
                request.setValue("application/json", forHTTPHeaderField:"Content-Type")
                request.setValue("application/json", forHTTPHeaderField:"Accept")
                request.setValue(APISecret.SHA1, forHTTPHeaderField:"api-secret")
                request.HTTPBody = sendData
                
                let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) in
                    let httpResponse = response as! NSHTTPURLResponse
                    if let error = error {
                        completion(error.description)
                    } else if httpResponse.statusCode != 200 {
                        completion(String(data: data!, encoding: NSUTF8StringEncoding)!)
                    } else {
                        completion(nil)
                    }
                })
                task.resume()
            } catch {
                completion("Couldn't encode data to json.")
            }
        } else {
            completion("Invalid URL: \(siteURL), \(endpoint)")
        }
    }
    
    func flushDeviceStatuses() {
        let inFlight = deviceStatuses
        deviceStatuses =  [AnyObject]()
        uploadToNS(inFlight, endpoint: defaultNightscoutDeviceStatusPath) { (error) in
            if error != nil {
                NSLog("Uploading device status to nightscout failed: %@", error!)
                // Requeue
                self.deviceStatuses.appendContentsOf(inFlight)
            }
        }
    }
    
    func flushEntries() {
        let inFlight = entries
        entries =  [AnyObject]()
        uploadToNS(inFlight, endpoint: defaultNightscoutEntriesPath) { (error) in
            if error != nil {
                NSLog("Uploading nightscout entries failed: %@", error!)
                // Requeue
                self.entries.appendContentsOf(inFlight)
            }
        }
    }
    
    func flushTreatments() {
        let inFlight = treatmentsQueue
        treatmentsQueue =  [AnyObject]()
        uploadToNS(inFlight, endpoint: defaultNightscoutTreatmentPath) { (error) in
            if error != nil {
                NSLog("Uploading nightscout treatment records failed: %@", error!)
                // Requeue
                self.treatmentsQueue.appendContentsOf(inFlight)
            }
        }
    }
}
