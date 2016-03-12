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
  var pumpModel: String?
  
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
    lastHistoryAttempt = NSDate()
    
    getHistoryTimer = NSTimer.scheduledTimerWithTimeInterval(5.0 * 60, target:self, selector:Selector("timerTriggered"), userInfo:nil, repeats:true)
      
    // This triggers one dump right away (in 10s).d
    //[self performSelector:@selector(fetchHistory:) withObject:nil afterDelay:10];
    
    // This is to just test decoding history
    //[self performSelector:@selector(testDecodeHistory) withObject:nil afterDelay:1];
    
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
    let page = NSData(hexadecimalString: "010034003400000020424c05105b0018510c0510095000b44b500000140000000014965c113416c01038d01642d0164cd05056d0010014001400340018514c05105b0006440f6510285000b44b500000580000000058965c0b14a9c034bdc010dfd0010058005800040006444f65107b060040100510200e005b0015651265102d5000784b500000940000000094965c0e22d4c036dec0147ed03492d0010094009400000015655265107b0700401305102610000a7236633465103f0e3663546510c527ad7b0800401505102a13000afd0c443765103f1f0c44b76510c527ad5bfd1544170510005000b455503000000000000030965c08940dd022dfd0010030003000000016445705100af33b663765103f1e3b66776510c527ad7b000040000610000e00070000033305900000006e05900500b253fd090000033301432701f03d00990100003000c0000003010200000000000000000000000000000000000000007b0100400106100208007b020040040610080e007b0300400606100c10000aa216742866103f141674486610c527ad7b0400400a0610140b007b0500400c0610180a000a081e432c66903f211e430c6610c527ad5b0806440c06103d5100b44b503c008400000000c0960100c000c000000006444c06100a3f2a712f66103f072a71ef6610c527ad7b060040100610200e005b00194e106610145000784b500000400000000040965c088af9c03603d00100400040000000194e5066105b0001721166100a5000784b500000200000000020965c0e1c5fc02469c08a59d03663d00100200020001800017251661021001443120610030000003537433206107b060747120610200e00030003000339461206107b0700401306102610005b000c791406100c5000784b500000280000000028965c0b20c0c01c1ad02424d001002800280000000d795406107b0800401506102a1300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005751")!
    do {
      try decodeHistoryPage(page, pumpModel: "551")
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
      let pumpOps = PumpOps(pumpState: appDelegate.pump, andDevice:rl)
      
      pumpOps.getHistoryPage(0, withHandler: { (res: [NSObject : AnyObject]) -> Void in
        if let error = res["error"] {
          NSLog("fetchHistory failed: %@", error as! String);
        } else {
          let page = res["pageData"] as! NSData
          let pumpModel = res["pumpModel"] as! String
          NSLog("Avg RSSI for history dump: %@", res["avgRSSI"] as! NSNumber);
          do {
            try self.decodeHistoryPage(page, pumpModel: pumpModel)
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
      treatmentsQueue.append(treatment)
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
        performSelector(Selector("fetchHistory:"), withObject:nil, afterDelay:25)
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
      
      nsStatus["pump"] = [
        "clock": TimeFormat.timestampStrFromDate(status.pumpDate),
        "iob": [
          "timestamp": TimeFormat.timestampStrFromDate(status.pumpDate),
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
      if let sensorDate = status.glucoseDate {
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
