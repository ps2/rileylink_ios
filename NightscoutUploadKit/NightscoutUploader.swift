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

public enum UploadError: Error {
    case httpError(status: Int, body: String)
    case missingTimezone
    case unauthorized
}

private let defaultNightscoutEntriesPath = "/api/v1/entries.json"
private let defaultNightscoutTreatmentPath = "/api/v1/treatments.json"
private let defaultNightscoutDeviceStatusPath = "/api/v1/devicestatus.json"
private let defaultNightscoutAuthTestPath = "/api/v1/experiments/test"

public class NightscoutUploader {

    enum DexcomSensorError: Int {
        case sensorNotActive = 1
        case sensorNotCalibrated = 5
        case badRF = 12
    }
    
    public var siteURL: URL
    public var apiSecret: String
    
    private(set) var entries = [[String: Any]]()
    private(set) var deviceStatuses = [[String: Any]]()
    private(set) var treatmentsQueue = [NightscoutTreatment]()
    
    private(set) var lastMeterMessageRxTime: Date?
    
    public private(set) var observingPumpEventsSince: Date!
    
    private(set) var lastStoredTreatmentTimestamp: Date? {
        get {
            return UserDefaults.standard.lastStoredTreatmentTimestamp
        }
        set {
            UserDefaults.standard.lastStoredTreatmentTimestamp = newValue
        }
    }

    public var errorHandler: ((_ error: Error, _ context: String) -> Void)?

    public func reset() {
        observingPumpEventsSince = Date(timeIntervalSinceNow: TimeInterval(hours: -24))
        lastStoredTreatmentTimestamp = nil
    }

    public init(siteURL: URL, APISecret: String) {
        self.siteURL = siteURL
        self.apiSecret = APISecret
        
        observingPumpEventsSince = lastStoredTreatmentTimestamp ?? Date(timeIntervalSinceNow: TimeInterval(hours: -24))
    }
    
    // MARK: - Processing data from pump

    /**
     Enqueues pump history events for upload, with automatic retry management.
     
     - parameter events:    An array of timestamped history events. Only types with known Nightscout mappings will be uploaded.
     - parameter source:    The device identifier to display in Nightscout
     - parameter pumpModel: The pump model info associated with the events
     */
    public func processPumpEvents(_ events: [TimestampedHistoryEvent], source: String, pumpModel: PumpModel) {
        
        // Find valid event times
        let newestEventTime = events.last?.date
        
        // Find the oldest event that might still be updated.
        var oldestUpdatingEventDate: Date?

        for event in events {
            switch event.pumpEvent {
            case let bolus as BolusNormalPumpEvent:
                let deliveryFinishDate = event.date.addingTimeInterval(bolus.duration)
                if newestEventTime == nil || deliveryFinishDate.compare(newestEventTime!) == .orderedDescending {
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

    /**
     Attempts to upload pump history events.
     
     This method will not retry if the network task failed.
     
     - parameter pumpEvents: An array of timestamped history events. Only types with known Nightscout mappings will be uploaded.
     - parameter source:     The device identifier to display in Nightscout
     - parameter pumpModel:  The pump model info associated with the events
     - parameter completionHandler: A closure to execute when the task completes. It has a single argument for any error that might have occurred during the upload.
     */
    public func upload(_ pumpEvents: [TimestampedHistoryEvent], forSource source: String, from pumpModel: PumpModel, completionHandler: @escaping (Error?) -> Void) {
        let treatments = NightscoutPumpEvents.translate(pumpEvents, eventSource: source).map { $0.dictionaryRepresentation }

        uploadToNS(treatments, endpoint: defaultNightscoutTreatmentPath, completion: completionHandler)
    }

    public func uploadDeviceStatus(_ status: DeviceStatus) {
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
    
    public func uploadSGVFromMySentryPumpStatus(_ status: MySentryPumpStatusMessageBody, device: String) {
        
        var recordSGV = true
        let glucose: Int = {
            switch status.glucose {
            case .active(glucose: let glucose):
                return glucose
            case .highBG:
                return 401
            case .weakSignal:
                return DexcomSensorError.badRF.rawValue
            case .meterBGNow, .calError:
                return DexcomSensorError.sensorNotCalibrated.rawValue
            case .lost, .missing, .ended, .unknown, .off, .warmup:
                recordSGV = false
                return DexcomSensorError.sensorNotActive.rawValue
            }
        }()
        

        // Create SGV entry from this mysentry packet
        if (recordSGV) {
            var entry: [String: Any] = [
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
            case .active(glucose: let previousGlucose):
                entry["previousSGV"] = previousGlucose
            default:
                entry["previousSGVNotActive"] = true
            }
            entry["direction"] = {
                switch status.glucoseTrend {
                case .up:
                    return "SingleUp"
                case .upUp:
                    return "DoubleUp"
                case .down:
                    return "SingleDown"
                case .downDown:
                    return "DoubleDown"
                case .flat:
                    return "Flat"
                }
                }()
            entries.append(entry)
        }
        flushAll()
    }
    
    public func handleMeterMessage(_ msg: MeterMessage) {
        
        // TODO: Should only accept meter messages from specified meter ids.
        // Need to add an interface to allow user to specify linked meters.
        
        if msg.ackFlag {
            return
        }
        
        let date = Date()
        let epochTime = date.timeIntervalSince1970 * 1000
        let entry: [String: Any] = [
            "date": epochTime,
            "dateString": TimeFormat.timestampStrFromDate(date),
            "mbg": msg.glucose,
            "device": "Contour Next Link",
            "type": "mbg"
        ]
        
        // Skip duplicates
        if lastMeterMessageRxTime == nil || lastMeterMessageRxTime!.timeIntervalSinceNow.minutes < -3 {
            entries.append(entry)
            lastMeterMessageRxTime = Date()
        }
    }
    
    // MARK: - Uploading
    
    func flushAll() {
        flushDeviceStatuses()
        flushEntries()
        flushTreatments()
    }
    
    func uploadToNS(_ json: [Any], endpoint:String, completion: @escaping (Error?) -> Void) {
        if json.count == 0 {
            completion(nil)
            return
        }
        
        let uploadURL = siteURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiSecret.sha1, forHTTPHeaderField: "api-secret")

        do {
            let sendData = try JSONSerialization.data(withJSONObject: json, options: [])

            let task = URLSession.shared.uploadTask(with: request, from: sendData, completionHandler: { (data, response, error) in
                if let error = error {
                    completion(error)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse ,
                    httpResponse.statusCode != 200 {
                    completion(UploadError.httpError(status: httpResponse.statusCode, body:String(data: data!, encoding: String.Encoding.utf8)!))
                } else {
                    completion(nil)
                }
            }) 
            task.resume()
        } catch let error {
            completion(error)
        }
    }
    
    func flushDeviceStatuses() {
        let inFlight = deviceStatuses
        deviceStatuses = []
        uploadToNS(inFlight as [Any], endpoint: defaultNightscoutDeviceStatusPath) { (error) in
            if let error = error {
                self.errorHandler?(error, "Uploading device status")
                // Requeue
                self.deviceStatuses.append(contentsOf: inFlight)
            }
        }
    }
    
    func flushEntries() {
        let inFlight = entries
        entries = []
        uploadToNS(inFlight as [Any], endpoint: defaultNightscoutEntriesPath) { (error) in
            if let error = error {
                self.errorHandler?(error, "Uploading nightscout entries")
                // Requeue
                self.entries.append(contentsOf: inFlight)
            }
        }
    }
    
    func flushTreatments() {
        let inFlight = treatmentsQueue
        treatmentsQueue = []
        uploadToNS(inFlight.map({$0.dictionaryRepresentation}), endpoint: defaultNightscoutTreatmentPath) { (error) in
            if let error = error {
                self.errorHandler?(error, "Uploading nightscout treatment records")
                // Requeue
                self.treatmentsQueue.append(contentsOf: inFlight)
            } else {
                if let last = inFlight.last {
                    self.lastStoredTreatmentTimestamp = last.timestamp
                }
            }
        }
    }
    
    public func checkAuth(_ completion: @escaping (Error?) -> Void) {
        
        let testURL = siteURL.appendingPathComponent(defaultNightscoutAuthTestPath)
        
        var request = URLRequest(url: testURL)
        
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.setValue("application/json", forHTTPHeaderField:"Accept")
        request.setValue(apiSecret.sha1, forHTTPHeaderField:"api-secret")
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            if let error = error {
                completion(error)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse ,
                httpResponse.statusCode != 200 {
                    if httpResponse.statusCode == 401 {
                        completion(UploadError.unauthorized)
                    } else {
                        let error = UploadError.httpError(status: httpResponse.statusCode, body:String(data: data!, encoding: String.Encoding.utf8)!)
                        completion(error)
                    }
            } else {
                completion(nil)
            }
        })
        task.resume()
    }
}
