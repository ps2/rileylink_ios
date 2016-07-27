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

public enum UploadError: ErrorType {
    case HTTPError(status: Int, body: String)
    case MissingTimezone
    case Unauthorized
}

private let defaultNightscoutEntriesPath = "/api/v1/entries.json"
private let defaultNightscoutTreatmentPath = "/api/v1/treatments.json"
private let defaultNightscoutDeviceStatusPath = "/api/v1/devicestatus.json"
private let defaultNightscoutAuthTestPath = "/api/v1/experiments/test"

public class NightscoutUploader {

    enum DexcomSensorError: Int {
        case SensorNotActive = 1
        case SensorNotCalibrated = 5
        case BadRF = 12
    }
    
    public var siteURL: NSURL
    public var APISecret: String
    
    private(set) var entries = [[String: AnyObject]]()
    private(set) var deviceStatuses = [[String: AnyObject]]()
    private(set) var treatmentsQueue = [NightscoutTreatment]()
    
    private(set) var lastMeterMessageRxTime: NSDate?
    
    public private(set) var observingPumpEventsSince: NSDate!
    
    private(set) var lastStoredTreatmentTimestamp: NSDate? {
        get {
            return NSUserDefaults.standardUserDefaults().lastStoredTreatmentTimestamp
        }
        set {
            NSUserDefaults.standardUserDefaults().lastStoredTreatmentTimestamp = newValue
        }
    }

    public var errorHandler: ((error: ErrorType, context: String) -> Void)?

    public func reset() {
        observingPumpEventsSince = NSDate(timeIntervalSinceNow: NSTimeInterval(hours: -24))
        lastStoredTreatmentTimestamp = nil
    }

    public init(siteURL: NSURL, APISecret: String) {
        self.siteURL = siteURL
        self.APISecret = APISecret
        
        observingPumpEventsSince = lastStoredTreatmentTimestamp ?? NSDate(timeIntervalSinceNow: NSTimeInterval(hours: -24))
    }
    
    // MARK: - Processing data from pump
    
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
        
        for treatment in NightscoutPumpEvents.translate(events, eventSource: source) {
            treatmentsQueue.append(treatment)
        }
        self.flushAll()
    }

    public func getPumpStatusFromMySentryPumpStatus(status: MySentryPumpStatusMessageBody) -> PumpStatus {

        let pumpDate = status.pumpDateComponents.date

        if pumpDate == nil {
            self.errorHandler?(error: UploadError.MissingTimezone, context: "Unable to get status.pumpDateComponents.date from \(status.pumpDateComponents)")
        }

        let pumpStatus = PumpStatus()
        pumpStatus.batteryPct = status.batteryRemainingPercent
        pumpStatus.bolusIOB = status.iob
        pumpStatus.timestamp = pumpDate
        return pumpStatus
    }

    public func uploadDeviceStatus(status: DeviceStatus) {
        deviceStatuses.append(status.dictionaryRepresentation)
        flushAll()
    }
    
    //  Entries [ { sgv: 375,
    //    date: 1432421525000,
    //    dateString: '2015-05-23T22:52:05.000Z',
    //    trend: 1,
    //    direction: 'DoubleUp',
    //    device: 'share2',
    //    type: 'sgv' } ]
    
    public func uploadSGVFromMySentryStatus(status: MySentryPumpStatusMessageBody, device: String) {
        
        var recordSGV = true
        let glucose: Int = {
            switch status.glucose {
            case .Active(glucose: let glucose):
                return glucose
            case .HighBG:
                return 401
            case .WeakSignal:
                return DexcomSensorError.BadRF.rawValue
            case .MeterBGNow, .CalError:
                return DexcomSensorError.SensorNotCalibrated.rawValue
            case .Lost, .Missing, .Ended, .Unknown, .Off, .Warmup:
                recordSGV = false
                return DexcomSensorError.SensorNotActive.rawValue
            }
        }()
        

        // Create SGV entry from this mysentry packet
        if (recordSGV) {
            var entry: [String: AnyObject] = [
                "sgv": glucose,
                "device": device,
                "type": "sgv"
            ]
            if let sensorDateComponents = status.glucoseDateComponents,
                let sensorDate = sensorDateComponents.date {
                entry["date"] = sensorDate.timeIntervalSince1970 * 1000
                entry["dateString"] = TimeFormat.timestampStrFromDate(sensorDate)
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
        flushAll()
    }
    
    public func handleMeterMessage(msg: MeterMessage) {
        
        // TODO: Should only accept meter messages from specified meter ids.
        // Need to add an interface to allow user to specify linked meters.
        
        if msg.ackFlag {
            return
        }
        
        let date = NSDate()
        let epochTime = date.timeIntervalSince1970 * 1000
        let entry: [String: AnyObject] = [
            "date": epochTime,
            "dateString": TimeFormat.timestampStrFromDate(date),
            "mbg": msg.glucose,
            "device": "Contour Next Link",
            "type": "mbg"
        ]
        
        // Skip duplicates
        if lastMeterMessageRxTime == nil || lastMeterMessageRxTime!.timeIntervalSinceNow.minutes < -3 {
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
    
    func uploadToNS(json: [AnyObject], endpoint:String, completion: (ErrorType?) -> Void) {
        if json.count == 0 {
            completion(nil)
            return
        }
        
        let uploadURL = siteURL.URLByAppendingPathComponent(endpoint)
        let request = NSMutableURLRequest(URL: uploadURL)
        do {
            
            let sendData = try NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions.PrettyPrinted)
            request.HTTPMethod = "POST"
            
            request.setValue("application/json", forHTTPHeaderField:"Content-Type")
            request.setValue("application/json", forHTTPHeaderField:"Accept")
            request.setValue(APISecret.SHA1, forHTTPHeaderField:"api-secret")
            request.HTTPBody = sendData
            
            let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) in
                
                if let error = error {
                    completion(error)
                    return
                }
                
                if let httpResponse = response as? NSHTTPURLResponse where
                    httpResponse.statusCode != 200 {
                    completion(UploadError.HTTPError(status: httpResponse.statusCode, body:String(data: data!, encoding: NSUTF8StringEncoding)!))
                } else {
                    completion(nil)
                }
            })
            task.resume()
        } catch let error as NSError {
            completion(error)
        }
    }
    
    func flushDeviceStatuses() {
        let inFlight = deviceStatuses
        deviceStatuses = []
        uploadToNS(inFlight, endpoint: defaultNightscoutDeviceStatusPath) { (error) in
            if let error = error {
                self.errorHandler?(error: error, context: "Uploading device status")
                // Requeue
                self.deviceStatuses.appendContentsOf(inFlight)
            }
        }
    }
    
    func flushEntries() {
        let inFlight = entries
        entries = []
        uploadToNS(inFlight, endpoint: defaultNightscoutEntriesPath) { (error) in
            if let error = error {
                self.errorHandler?(error: error, context: "Uploading nightscout entries")
                // Requeue
                self.entries.appendContentsOf(inFlight)
            }
        }
    }
    
    func flushTreatments() {
        let inFlight = treatmentsQueue
        treatmentsQueue = []
        uploadToNS(inFlight.map({$0.dictionaryRepresentation}), endpoint: defaultNightscoutTreatmentPath) { (error) in
            if let error = error {
                self.errorHandler?(error: error, context: "Uploading nightscout treatment records")
                // Requeue
                self.treatmentsQueue.appendContentsOf(inFlight)
            } else {
                if let last = inFlight.last {
                    self.lastStoredTreatmentTimestamp = last.timestamp
                }
            }
        }
    }
    
    public func checkAuth(completion: (ErrorType?) -> Void) {
        
        let testURL = siteURL.URLByAppendingPathComponent(defaultNightscoutAuthTestPath)
        
        let request = NSMutableURLRequest(URL: testURL)
        
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.setValue("application/json", forHTTPHeaderField:"Accept")
        request.setValue(APISecret.SHA1, forHTTPHeaderField:"api-secret")
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) in
            if let error = error {
                completion(error)
                return
            }
            
            if let httpResponse = response as? NSHTTPURLResponse where
                httpResponse.statusCode != 200 {
                    if httpResponse.statusCode == 401 {
                        completion(UploadError.Unauthorized)
                    } else {
                        let error = UploadError.HTTPError(status: httpResponse.statusCode, body:String(data: data!, encoding: NSUTF8StringEncoding)!)
                        completion(error)
                    }
            } else {
                completion(nil)
            }
        })
        task.resume()
    }
}
