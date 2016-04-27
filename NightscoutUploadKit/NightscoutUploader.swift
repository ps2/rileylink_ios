//
//  NightScoutUploader.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit
//import RileyLinkKit
//import RileyLinkBLEKit


class NightScoutUploader: NSObject {

  enum DexcomSensorError: UInt8 {
    case SensorNotActive = 1
    case SensorNotCalibrated = 5
    case BadRF = 12
  }
  
  var siteURL: String = ""
  var APISecret: String = ""
  
  var fetchHistoryScheduled: Bool = false
  var lastHistoryAttempt: NSDate?
  var entries: [AnyObject]
  var deviceStatuses: [AnyObject]
  var treatmentsQueue: [AnyObject]
  
  var lastMeterMessageRxTime: NSDate?
  var activeRileyLink: RileyLinkBLEDevice?
  var getHistoryTimer: NSTimer?
  
  // TODO: since some treatments update, we should instead keep track of the time
  // of the most recent non-mutating event, and send all events newer than that.
  //var sentTreatments: [AnyObject]
  var observingPumpEventsSince: NSDate
  
  let defaultNightscoutEntriesPath = "/api/v1/entries.json"
  let defaultNightscoutTreatmentPath = "/api/v1/treatments.json"
  let defaultNightscoutDeviceStatusPath = "/api/v1/devicestatus.json"
    
  override init() {
    entries = [AnyObject]()
    treatmentsQueue = [AnyObject]()
    deviceStatuses = [AnyObject]()
    
    let calendar = NSCalendar.currentCalendar()
    observingPumpEventsSince = calendar.dateByAddingUnit(.Day, value: -1, toDate: NSDate(), options: [])!
    
    super.init()
    
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(NightScoutUploader.packetReceived(_:)), name: RILEYLINK_EVENT_PACKET_RECEIVED, object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(NightScoutUploader.deviceConnected(_:)), name: RILEYLINK_EVENT_DEVICE_CONNECTED, object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(NightScoutUploader.deviceDisconnected(_:)), name: RILEYLINK_EVENT_DEVICE_DISCONNECTED, object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(NightScoutUploader.rileyLinkAdded(_:)), name: RILEYLINK_EVENT_DEVICE_ADDED, object: nil)
    
    UIDevice.currentDevice().batteryMonitoringEnabled = true
    lastHistoryAttempt = nil
    
    getHistoryTimer = NSTimer.scheduledTimerWithTimeInterval(5.0 * 60, target:self, selector:#selector(NightScoutUploader.timerTriggered), userInfo:nil, repeats:true)
      
    // This triggers one history fetch right away (in 10s)
    //performSelector(#selector(NightScoutUploader.fetchHistory), withObject: nil, afterDelay: 10)
    
    // This is to just test decoding history
    //performSelector(Selector("testDecodeHistory"), withObject: nil, afterDelay: 1)
    
    // Test storing MySentry packet:
    //[self performSelector:@selector(testHandleMySentry) withObject:nil afterDelay:10];
  }
  
  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }
  
  // MARK: - Testing
  
  func testHandleMySentry() {
    let data = NSData(hexadecimalString: "a259705504e9401334001001050000000001d7040205e4000000000054000001240000000000000000dd")!
    let mySentryPacket = PumpMessage(rxData: data)!
    handlePumpStatus(mySentryPacket, device:"testData", rssi:1)
    flushAll()
  }
  
  func testDecodeHistory() {
    let pageData = NSData(hexadecimalString: "7b0100de080a101122007b0200c0160a102c1c007b0000c0000b1000160007000002be2a900000006e2a90050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de080b101122007b0200c0160b102c1c007b0000c0000c1000160007000002be2b900000006e2b90050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de080c10112200346418d3110c107b0200c0160c102c1c00343233db170c107b0000c0000d1000160007000002be2c900000006e2c90050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de080d101122007b0200c0160d102c1c007b0000c0000e1000160007000002be2d900000006e2d90050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de080e10112200063e033303c74f4e100c3e28d7100e1021001ce2150e1003000000202ce4350e101a000ae5150e101a0120e5150e107b0214c0160e102c1c00030001000112c0160e107b0000c0000f1000160007000001d32e900000006e2e90050000000000000001d301d3640000000000000000000000000000000000000000000000000000000000000000000000007b0100de080f10112200820108db150f1000a2ce8aa0810134e0150f1000a2ce8aa07d0134e0150f1000a2ce8aa0000000000000000000000000000000000000000000000000007b0200c0160f102c1c007b0000c000101000160007000002be2f900000006e2f90050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de0810101122007b0200c01610102c1c000a5e36d03670103f0b36d0d67010c228060a5b0cd43670103f0b0cd4767010c228067b0000c000111000160007000002be30900000006e309005005d5b5e02000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de0811101122000a600ada3171103f0c0ada117110c2280601002200220000001dea521110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003e35")!
    do {
      let pumpModel = PumpModel.Model523
      let page = try HistoryPage(pageData: pageData, pumpModel: pumpModel)
      let source = "testing/\(pumpModel)"
      self.processPumpEvents(page.events, source: source, pumpModel: pumpModel)
    } catch _ {
      
    }
  }
  
  
  // MARK: - Device updates
  
  func deviceConnected(note: NSNotification)
  {
    activeRileyLink = note.object as? RileyLinkBLEDevice
  }
  
  func deviceDisconnected(note: NSNotification)
  {
    if activeRileyLink == (note.object as? RileyLinkBLEDevice) {
      activeRileyLink = nil
    }
  }
  
  func rileyLinkAdded(note: NSNotification)
  {
    if let device = note.object as? RileyLinkBLEDevice  {
      device.enableIdleListeningOnChannel(0)
    }
  }
  
  func timerTriggered() {
  
    if lastHistoryAttempt == nil || lastHistoryAttempt!.timeIntervalSinceNow < (-5 * 60) && !fetchHistoryScheduled {
      NSLog("No fetchHistory for over five minutes.  Triggering one")
      fetchHistory()
    }
    flushAll()
  }
  
  
  func packetReceived(note: NSNotification) {
    let attrs = note.userInfo!
    let packet = attrs["packet"] as! RFPacket
    let device = note.object as! RileyLinkBLEDevice
    
    if let data = packet.data {
      
      if let msg = PumpMessage(rxData: data) {
        handlePumpMessage(msg, device:device, rssi: Int(packet.rssi))
        //TODO: tell RL to sleep for 4 mins to save on RL battery?
        
      } else if let msg = MeterMessage(rxData: data) {
        handleMeterMessage(msg)
      }

    }
  }
  
  // MARK: - Polling
  
  func fetchHistory() {
    lastHistoryAttempt = NSDate()
  
    fetchHistoryScheduled = false
    if let device = activeRileyLink where device.state != .Connected {
      activeRileyLink = nil
    }
  
    if (self.activeRileyLink == nil) {
      for item in RileyLinkBLEManager.sharedManager().rileyLinkList {
        if let device = item as? RileyLinkBLEDevice where device.state == .Connected {
          activeRileyLink = device
          break
        }
      }
    }
  
    if let rl = activeRileyLink {
      NSLog("Using RileyLink \"%@\" to fetchHistory.", rl.name!)
      
      let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
      let pumpOps = PumpOps(pumpState: appDelegate.pump, device:rl)
      pumpOps.getHistoryEventsSinceDate(observingPumpEventsSince) { (response) -> Void in
        switch response {
        case .Success(let (events, pumpModel)):
          NSLog("fetchHistory succeeded.")
          let source = "rileylink://medtronic/\(pumpModel)"
          self.processPumpEvents(events, source: source, pumpModel: pumpModel)
        case .Failure(let error):
          // TODO: Check for HistoryPage.Error.UnknownEventType, and let users submit 
          //  back to us to discover new history events.
          NSLog("History fetch failed: %@", String(error))
        }
      }
    } else {
      NSLog("fetchHistory failed: No connected rileylinks to attempt to pull history with.")
    }
  }
  
  // MARK: - Decoding Treatments
  
  func processPumpEvents(events: [PumpEvent], source: String, pumpModel: PumpModel) {
    
    // Find valid event times
    var validEventTimes = [NSDate]()
    for event in events {
      if event is TimestampedPumpEvent {
        let timestamp = (event as! TimestampedPumpEvent).timestamp
        if let date = TimeFormat.timestampAsLocalDate(timestamp) {
          validEventTimes.append(date)
        }
      }
    }
    let newestEventTime = validEventTimes.last
    
    
    // Find the oldest event that might still be updated.
    var oldestUpdatingEventDate: NSDate?
    let cal = NSCalendar.currentCalendar()
    for event in events {
      switch event {
      case is BolusNormalPumpEvent:
        let event = event as! BolusNormalPumpEvent
        if let date = TimeFormat.timestampAsLocalDate(event.timestamp) {
          let duration = NSDateComponents()
          duration.minute = event.duration
          let deliveryFinishDate = cal.dateByAddingComponents(duration, toDate: date, options: NSCalendarOptions(rawValue:0))
          if newestEventTime == nil || deliveryFinishDate?.compare(newestEventTime!) == .OrderedDescending {
            // This event might still be updated.
            oldestUpdatingEventDate = date
            break
          }
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
  
  
//  - (NSString*)trendToDirection:(GlucoseTrend)trend {
//  switch (trend) {
//  case GLUCOSE_TREND_NONE:
//  return @"";
//  case GLUCOSE_TREND_UP:
//  return @"SingleUp";
//  case GLUCOSE_TREND_DOUBLE_UP:
//  return @"DoubleUp";
//  case GLUCOSE_TREND_DOWN:
//  return @"SingleDown";
//  case GLUCOSE_TREND_DOUBLE_DOWN:
//  return @"DoubleDown";
//  default:
//  return @"NOT COMPUTABLE";
//  break;
//  }
//  }
  
  //  Entries [ { sgv: 375,
  //    date: 1432421525000,
  //    dateString: '2015-05-23T22:52:05.000Z',
  //    trend: 1,
  //    direction: 'DoubleUp',
  //    device: 'share2',
  //    type: 'sgv' } ]
  
  func handlePumpMessage(msg: PumpMessage, device: RileyLinkBLEDevice, rssi: Int) {

    if (msg.packetType == .MySentry &&
    msg.messageType == .PumpStatus &&
    (msg.address.hexadecimalString == Config.sharedInstance().pumpID)) {
      // Make this RL the active one, for history dumping.
      activeRileyLink = device
      handlePumpStatus(msg, device:device.deviceURI, rssi:rssi)
      // Just got a MySentry packet; in 11s would be a good time to poll.
      if !fetchHistoryScheduled {
        performSelector(#selector(NightScoutUploader.fetchHistory), withObject:nil, afterDelay:11)
        fetchHistoryScheduled = true
      }
      // TODO: send ack. also, we can probably wait less than 25s if we ack; the 25s
      // above is mainly to avoid colliding with subsequent packets.
    }
    flushAll()
  }
  
  func handlePumpStatus(msg: PumpMessage, device: String, rssi: Int) {
    
    let status: MySentryPumpStatusMessageBody = msg.messageBody as! MySentryPumpStatusMessageBody
    
    if msg.address.hexadecimalString == Config.sharedInstance().pumpID {
      
      enum DexcomSensorErrorType: Int {
        case DX_SENSOR_NOT_ACTIVE = 1
        case DX_SENSOR_NOT_CALIBRATED = 5
        case DX_BAD_RF = 12
      }

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
      var entry: [String: AnyObject] = [
        "sgv": glucose,
        "device": device,
        "rssi": rssi,
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
    } else {
      NSLog("Dropping mysentry packet for pump: %@", msg.address.hexadecimalString);
    }
  }
  
  func handleMeterMessage(msg: MeterMessage) {
    
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
    
    let logEntries = Log.popLogEntries()
    
    if logEntries.count > 0 {
      let date = NSDate()
      let epochTime = date.timeIntervalSince1970 * 1000
      
      let entry = [
        "date": epochTime,
        "dateString": TimeFormat.timestampStrFromDate(date),
        "entries": logEntries,
        "type": "logs"
      ]
      entries.append(entry)
    }
    
    flushDeviceStatuses()
    flushEntries()
    flushTreatments()
  }
  
  func uploadToNS(json: [AnyObject], endpoint:String, completion: (String?) -> Void) {
    if json.count == 0 {
      completion(nil)
      return
    }
    
    if let uploadURL = NSURL(string: endpoint, relativeToURL: NSURL(string: siteURL)) {
      let request = NSMutableURLRequest(URL: uploadURL)
      do {
        let sendData = try NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions.PrettyPrinted)
        request.HTTPMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.setValue("application/json", forHTTPHeaderField:"Accept")
        request.setValue(self.APISecret.sha1(), forHTTPHeaderField:"api-secret")
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
