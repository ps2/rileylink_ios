//
//  NightScoutUploader.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/9/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit

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
  var sendEntriesNewerThan: NSDate?
  
  let defaultNightscoutEntriesPath = "/api/v1/entries.json"
  let defaultNightscoutTreatmentPath = "/api/v1/treatments.json"
  let defaultNightscoutDeviceStatusPath = "/api/v1/devicestatus.json"
    
  override init() {
    entries = [AnyObject]()
    treatmentsQueue = [AnyObject]()
    deviceStatuses = [AnyObject]()
    
    super.init()
    
    NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("packetReceived:"), name: RILEYLINK_EVENT_PACKET_RECEIVED, object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("deviceConnected:"), name: RILEYLINK_EVENT_DEVICE_CONNECTED, object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("deviceDisconnected:"), name: RILEYLINK_EVENT_DEVICE_DISCONNECTED, object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("rileyLinkAdded:"), name: RILEYLINK_EVENT_DEVICE_ADDED, object: nil)
    
    UIDevice.currentDevice().batteryMonitoringEnabled = true
    lastHistoryAttempt = nil
    
    getHistoryTimer = NSTimer.scheduledTimerWithTimeInterval(5.0 * 60, target:self, selector:Selector("timerTriggered"), userInfo:nil, repeats:true)
      
    // This triggers one dump right away (in 10s).d
    //[self performSelector:@selector(fetchHistory:) withObject:nil afterDelay:10];
    
    // This is to just test decoding history
    performSelector(Selector("testDecodeHistory"), withObject: nil, afterDelay: 1)
    
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
    let page = NSData(hexadecimalString: "7b0100de080a101122007b0200c0160a102c1c007b0000c0000b1000160007000002be2a900000006e2a90050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de080b101122007b0200c0160b102c1c007b0000c0000c1000160007000002be2b900000006e2b90050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de080c10112200346418d3110c107b0200c0160c102c1c00343233db170c107b0000c0000d1000160007000002be2c900000006e2c90050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de080d101122007b0200c0160d102c1c007b0000c0000e1000160007000002be2d900000006e2d90050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de080e10112200063e033303c74f4e100c3e28d7100e1021001ce2150e1003000000202ce4350e101a000ae5150e101a0120e5150e107b0214c0160e102c1c00030001000112c0160e107b0000c0000f1000160007000001d32e900000006e2e90050000000000000001d301d3640000000000000000000000000000000000000000000000000000000000000000000000007b0100de080f10112200820108db150f1000a2ce8aa0810134e0150f1000a2ce8aa07d0134e0150f1000a2ce8aa0000000000000000000000000000000000000000000000000007b0200c0160f102c1c007b0000c000101000160007000002be2f900000006e2f90050000000000000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de0810101122007b0200c01610102c1c000a5e36d03670103f0b36d0d67010c228060a5b0cd43670103f0b0cd4767010c228067b0000c000111000160007000002be30900000006e309005005d5b5e02000002be02be640000000000000000000000000000000000000000000000000000000000000000000000007b0100de0811101122000a600ada3171103f0c0ada117110c2280601002200220000001dea521110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003e35")!
    do {
      try decodeHistoryPage(page, pumpModel: "523")
      flushAll()
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
    logMemUsage()
  
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
      pumpOps.getHistoryPage(0, completion: { (results) -> Void in
        if let error = results.error {
          NSLog("fetchHistory failed: %@", error);
        } else {
          do {
            try self.decodeHistoryPage(results.pageData!, pumpModel: results.pumpModel!)
            NSLog("fetchHistory succeeded.");
          } catch HistoryPage.Error.InvalidCRC {
            NSLog("CRC error in history page.");
          } catch HistoryPage.Error.UnknownEventType(let eventType) {
            // TODO: Need some way let users submit this error (and the history page)
            // back to us to discover new history events.
            NSLog("Encountered unknown event type %d", eventType)
          } catch {
            NSLog("Unexpected exception...")
          }
        }
        self.flushAll()
      })
    } else {
      NSLog("fetchHistory failed: No connected rileylinks to attempt to pull history with.")
      
    }
    
  }
  
  // MARK: - Decoding Treatments
  
  func decodeHistoryPage(data: NSData, pumpModel: String) throws {
    NSLog("Got page: %@", data.hexadecimalString)
    
    if let m = PumpModel.byModelNumber(pumpModel) {
      let page = try HistoryPage(pageData: data, pumpModel: m)
    
      for treatment in NightScoutPumpEvents.translate(page.events, eventSource: "rileylink://medtronic/" + m.name) {
        addTreatment(treatment, pumpModel:m)
      }
    } else {
      NSLog("Unknown pump model: " + pumpModel)
    }
  }
  
  func addTreatment(treatment:NightscoutTreatment, pumpModel:PumpModel) {
    if sendEntriesNewerThan == nil || treatment.timestamp.timeIntervalSinceDate(sendEntriesNewerThan!) > 0 {
      var rep = treatment.dictionaryRepresentation
      if rep["created_at"] == nil && rep["timestamp"] != nil {
        rep["created_at"] = rep["timestamp"]
      }
      if rep["created_at"] == nil {
        rep["created_at"] = TimeFormat.timestampStrFromDate(NSDate())
      }
      treatmentsQueue.append(rep)
    }
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
      // Just got a MySentry packet; in 25s would be a good time to poll.
      if !fetchHistoryScheduled {
        performSelector(Selector("fetchHistory"), withObject:nil, afterDelay:25)
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
  
  func flushDeviceStatuses() {
  
    if deviceStatuses.count == 0 {
      return
    }
    
    let inFlightDeviceStatuses = deviceStatuses
    deviceStatuses = [AnyObject]()
    reportJSON(inFlightDeviceStatuses, endpoint: defaultNightscoutDeviceStatusPath) { (data, response, error) -> Void in
      let httpResponse = response as! NSHTTPURLResponse
      if httpResponse.statusCode != 200 {
        NSLog("Requeuing %d device statuses: %@", inFlightDeviceStatuses.count, error!)
        self.deviceStatuses += inFlightDeviceStatuses
      } else {
        //NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        //NSLog(@"Submitted %d device statuses to nightscout: %@", inFlightDeviceStatuses.count, resp);
      }
    }
  }
  
  func flushEntries() {
    if (self.entries.count == 0) {
    return;
    }
    
    let inFlightEntries = entries
    entries = [AnyObject]()
    reportJSON(inFlightEntries, endpoint: defaultNightscoutEntriesPath) { (data, response, error) -> Void in
      let httpResponse = response as! NSHTTPURLResponse
      if httpResponse.statusCode != 200 {
        NSLog("Requeuing %d sgv entries: %@", inFlightEntries.count, error!)
        self.entries += inFlightEntries
      } else {
        //NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        //NSLog(@"Submitted %d entries to nightscout: %@", inFlightEntries.count, resp);
      }
    }
  }
  
  func flushTreatments() {
    if (self.treatmentsQueue.count == 0) {
      return;
    }
    
    let inFlightTreatments = treatmentsQueue
    treatmentsQueue = [AnyObject]()
    reportJSON(inFlightTreatments, endpoint: defaultNightscoutTreatmentPath) { (data, response, error) -> Void in
      let httpResponse = response as! NSHTTPURLResponse
      if httpResponse.statusCode != 200 {
        NSLog("Requeuing %d treatments: %@", inFlightTreatments.count, error!)
        self.treatmentsQueue += inFlightTreatments
      }
    }
  }
  
  func reportJSON(json: [AnyObject], endpoint:String, completion: (NSData?, NSURLResponse?, NSError?) -> Void) {
    if let uploadURL = NSURL(string: endpoint, relativeToURL: NSURL(string: siteURL)) {
      let request = NSMutableURLRequest(URL: uploadURL)
      do {
        let sendData = try NSJSONSerialization.dataWithJSONObject(json, options: NSJSONWritingOptions.PrettyPrinted)
        request.HTTPMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.setValue("application/json", forHTTPHeaderField:"Accept")
        request.setValue(self.APISecret.sha1(), forHTTPHeaderField:"api-secret")
        request.HTTPBody = sendData
        
        NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: completion).resume()
      } catch {
        NSLog("Couldn't encode data to json.");
      }
    } else {
      NSLog("Invalid URL: %@, %@", siteURL, endpoint)
    }
  }
  

}
