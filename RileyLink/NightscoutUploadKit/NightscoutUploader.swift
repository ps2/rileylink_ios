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
  
  var fetchHistoryScheduled: Bool
  var lastHistoryAttempt: NSDate
  var entries: [AnyObject]
  var deviceStatuses: [AnyObject]
  var treatmentsQueue: [AnyObject]
  
  var lastMeterMessage: MeterMessage
  var activeRileyLink: RileyLinkBLEDevice?
  var getHistoryTimer: NSTimer
  var pumpModel: String?
  var sentTreatments: [AnyObject]
  
  
  let defaultNightscoutEntriesPath = "/api/v1/entries.json"
  let defaultNightscoutTreatmentPath = "/api/v1/treatments.json"
  let defaultNightscoutDeviceStatusPath = "/api/v1/devicestatus.json"
    
  override init() {
    entries = [AnyObject]()
    sentTreatments = [AnyObject]()
    treatmentsQueue = [AnyObject]()
    deviceStatuses = [AnyObject]()
    
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
    let mySentryPacket = MinimedPacket(data: data)
    handlePumpStatus(mySentryPacket, device:nil, rssi:1)
    flushAll()
  }
  
  func testDecodeHistory() {
    let page = NSData(hexadecimalString: "010034003400000020424c05105b0018510c0510095000b44b500000140000000014965c113416c01038d01642d0164cd05056d0010014001400340018514c05105b0006440f6510285000b44b500000580000000058965c0b14a9c034bdc010dfd0010058005800040006444f65107b060040100510200e005b0015651265102d5000784b500000940000000094965c0e22d4c036dec0147ed03492d0010094009400000015655265107b0700401305102610000a7236633465103f0e3663546510c527ad7b0800401505102a13000afd0c443765103f1f0c44b76510c527ad5bfd1544170510005000b455503000000000000030965c08940dd022dfd0010030003000000016445705100af33b663765103f1e3b66776510c527ad7b000040000610000e00070000033305900000006e05900500b253fd090000033301432701f03d00990100003000c0000003010200000000000000000000000000000000000000007b0100400106100208007b020040040610080e007b0300400606100c10000aa216742866103f141674486610c527ad7b0400400a0610140b007b0500400c0610180a000a081e432c66903f211e430c6610c527ad5b0806440c06103d5100b44b503c008400000000c0960100c000c000000006444c06100a3f2a712f66103f072a71ef6610c527ad7b060040100610200e005b00194e106610145000784b500000400000000040965c088af9c03603d00100400040000000194e5066105b0001721166100a5000784b500000200000000020965c0e1c5fc02469c08a59d03663d00100200020001800017251661021001443120610030000003537433206107b060747120610200e00030003000339461206107b0700401306102610005b000c791406100c5000784b500000280000000028965c0b20c0c01c1ad02424d001002800280000000d795406107b0800401506102a1300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005751")!
    decodeHistoryPage(page, pumpModel: "551")
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
  
    if lastHistoryAttempt.timeIntervalSinceNow < (-5 * 60) && !fetchHistoryScheduled {
      NSLog("No fetchHistory for over five minutes.  Triggering one")
      fetchHistory()
    }
    flushAll()
  }
  
  
  func packetReceived(note: NSNotification) {
    let attrs = note.userInfo!
    let packet = attrs["packet"] as! RFPacket
    let device = note.object as! RileyLinkBLEDevice
  
    let mPacket = MinimedPacket(RFPacket: packet)
    addPacket(mPacket device:device)
  
    //TODO: tell RL to sleep for 4 mins to save on RL battery?
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
          NSLog("fetchHistory succeeded.");
          self.decodeHistoryPage(page, pumpModel: pumpModel)
        }
        flushAll()
      })
    } else {
      NSLog("fetchHistory failed: No connected rileylinks to attempt to pull history with.")
      
    }
    
  }
  
  // MARK: - Decoding Treatments
  
  func decodeHistoryPage(data: NSData, pumpModel: String) throws {
    NSLog("Got page: %@", data.hexadecimalString)
    
    let m = PumpModel.byModelNumber(pumpModel)
    
    let page = try HistoryPage(pageData: data, pumpModel: m)
    
    for treatment in NightScoutPumpEvents.translate(page.events) {
      addTreatment(treatment, pumpModel:m)
    }
  }
  
  func addTreatment(treatment:[String: AnyObject], pumpModel:PumpModel) {
    var t = treatment
    t["enteredBy"] = "rileylink://medtronic/" + pumpModel.name
    t["createdAt"] =
    
    
  
  if ([self.sentTreatments member:treatment]) {
  NSLog(@"Already sent %@", treatment);
  } else {
  [self.treatmentsQueue addObject:treatment];
  }
  }
  
  //var DIRECTIONS = {
  //NONE: 0
  //  , DoubleUp: 1
  //  , SingleUp: 2
  //  , FortyFiveUp: 3
  //  , Flat: 4
  //  , FortyFiveDown: 5
  //  , SingleDown: 6
  //  , DoubleDown: 7
  //  , 'NOT COMPUTABLE': 8
  //  , 'RATE OUT OF RANGE': 9
  //};
  
  
  - (NSString*)trendToDirection:(GlucoseTrend)trend {
  switch (trend) {
  case GLUCOSE_TREND_NONE:
  return @"";
  case GLUCOSE_TREND_UP:
  return @"SingleUp";
  case GLUCOSE_TREND_DOUBLE_UP:
  return @"DoubleUp";
  case GLUCOSE_TREND_DOWN:
  return @"SingleDown";
  case GLUCOSE_TREND_DOUBLE_DOWN:
  return @"DoubleDown";
  default:
  return @"NOT COMPUTABLE";
  break;
  }
  }
  
  //  Entries [ { sgv: 375,
  //    date: 1432421525000,
  //    dateString: '2015-05-23T22:52:05.000Z',
  //    trend: 1,
  //    direction: 'DoubleUp',
  //    device: 'share2',
  //    type: 'sgv' } ]
  
  - (void)addPacket:(MinimedPacket*)packet fromDevice:(RileyLinkBLEDevice*)device {
  
  if (RECORD_RAW_PACKETS) {
  [self storeRawPacket:packet fromDevice:device];
  }
  
  if (packet.packetType == PacketTypeSentry &&
  packet.messageType == MESSAGE_TYPE_PUMP_STATUS &&
  [packet.address isEqualToString:[Config sharedInstance].pumpID]) {
  // Make this RL the active one, for history dumping.
  self.activeRileyLink = device;
  [self handlePumpStatus:packet fromDevice:device withRSSI:packet.rssi];
  // Just got a MySentry packet; in 25s would be a good time to poll.
  if (!fetchHistoryScheduled) {
  [self performSelector:@selector(fetchHistory:) withObject:nil afterDelay:25];
  fetchHistoryScheduled = YES;
  }
  // TODO: send ack. also, we can probably wait less than 25s if we ack; the 25s
  // above is mainly to avoid colliding with subsequent packets.
  
  } else if (packet.packetType == PacketTypeMeter) {
  [self handleMeterMessage:packet];
  }
  
  [self flushAll];
  }
  
  - (void) storeRawPacket:(MinimedPacket*)packet fromDevice:(RileyLinkBLEDevice*)device {
  NSDate *now = [NSDate date];
  NSTimeInterval seconds = now.timeIntervalSince1970;
  NSNumber *epochTime = @(seconds * 1000);
  
  NSDictionary *entry =
  @{@"date": epochTime,
  @"dateString": [self.dateFormatter stringFromDate:now],
  @"rfpacket": (packet.data).hexadecimalString,
  @"device": device.deviceURI,
  @"rssi": @(packet.rssi),
  @"type": @"rfpacket"
  };
  [self.entries addObject:entry];
  }
  
  - (void) handlePumpStatus:(MinimedPacket*)packet fromDevice:(RileyLinkBLEDevice*)device withRSSI:(NSInteger)rssi {
  PumpStatusMessage *msg = [[PumpStatusMessage alloc] initWithData:packet.data];
  
  if ([packet.address isEqualToString:[Config sharedInstance].pumpID]) {
  
  NSDate *validTime = msg.sensorTime;
  
  NSInteger glucose = msg.glucose;
  switch (msg.sensorStatus) {
  case SENSOR_STATUS_HIGH_BG:
  glucose = 401;
  break;
  case SENSOR_STATUS_WEAK_SIGNAL:
  glucose = DX_BAD_RF;
  break;
  case SENSOR_STATUS_METER_BG_NOW:
  glucose = DX_SENSOR_NOT_CALIBRATED;
  break;
  case SENSOR_STATUS_LOST:
  case SENSOR_STATUS_MISSING:
  glucose = DX_SENSOR_NOT_ACTIVE;
  validTime = msg.pumpTime;
  break;
  default:
  break;
  }
  
  NSNumber *epochTime = @(validTime.timeIntervalSince1970 * 1000);
  
  NSMutableDictionary *status = [NSMutableDictionary dictionary];
  
  status[@"device"] = device.deviceURI;
  status[@"created_at"] = [self.dateFormatter stringFromDate:[NSDate date]];
  
  // TODO: use battery monitoring to post updates if we're not hearing from pump?
  UIDevice *uploaderDevice = [UIDevice currentDevice];
  if (uploaderDevice.isBatteryMonitoringEnabled) {
  NSNumber *batteryPct = @((int)([UIDevice currentDevice].batteryLevel * 100));
  status[@"uploader"] = @{@"battery":batteryPct};
  }
  
  status[@"pump"] = @{
  @"clock": [self.dateFormatter stringFromDate:validTime],
  @"iob": @{
  @"timestamp": [self.dateFormatter stringFromDate:validTime],
  @"bolusiob": @(msg.activeInsulin),
  },
  @"reservoir": @(msg.insulinRemaining),
  @"battery": @{
  @"percent": @(msg.batteryPct)
  }
  };
  
  if (msg.sensorStatus != SENSOR_STATUS_MISSING) {
  status[@"sensor"] = @{
  @"sensorAge": @(msg.sensorAge),
  @"sensorRemaining": @(msg.sensorRemaining),
  @"sensorStatus": msg.sensorStatusString
  };
  }
  [self.deviceStatuses addObject:status];
  
  // Do not store sgv values if sensor missing; we're likely just
  // using MySentry to gather pump status.
  if (msg.sensorStatus != SENSOR_STATUS_MISSING) {
  NSDictionary *entry =
  @{@"date": epochTime,
  @"dateString": [self.dateFormatter stringFromDate:validTime],
  @"sgv": @(glucose),
  @"previousSGV": @(msg.previousGlucose),
  @"direction": [self trendToDirection:msg.trend],
  @"device": device.deviceURI,
  @"rssi": @(rssi),
  @"type": @"sgv"
  };
  [self.entries addObject:entry];
  }
  
  
  } else {
  NSLog(@"Dropping mysentry packet for pump: %@", packet.address);
  }
  }
  
  - (void) handleMeterMessage:(MinimedPacket*)packet {
  MeterMessage *msg = [[MeterMessage alloc] initWithData:packet.data];
  
  if (msg.isAck) {
  return;
  }
  
  msg.dateReceived = [NSDate date];
  NSTimeInterval seconds = (msg.dateReceived).timeIntervalSince1970;
  NSNumber *epochTime = @(seconds * 1000);
  NSDictionary *entry =
  @{@"date": epochTime,
  @"dateString": [self.dateFormatter stringFromDate:msg.dateReceived],
  @"mbg": @(msg.glucose),
  @"device": @"Contour Next Link",
  @"type": @"mbg"
  };
  
  // Skip duplicates
  if (_lastMeterMessage &&
  [msg.dateReceived timeIntervalSinceDate:_lastMeterMessage.dateReceived] &&
  msg.glucose == _lastMeterMessage.glucose) {
  entry = nil;
  } else {
  [self.entries addObject:entry];
  _lastMeterMessage = msg;
  }
  }
  
  #pragma mark - Uploading
  
  - (void) flushAll {
  
  NSArray *logEntries = [Log popLogEntries];
  if (logEntries.count > 0) {
  NSDate *date = [NSDate date];
  NSTimeInterval seconds = date.timeIntervalSince1970;
  NSNumber *epochTime = @(seconds * 1000);
  
  NSDictionary *entry =
  @{@"date": epochTime,
  @"dateString": [self.dateFormatter stringFromDate:date],
  @"entries": logEntries,
  @"type": @"logs"
  };
  [self.entries addObject:entry];
  }
  
  [self flushDeviceStatuses];
  [self flushEntries];
  [self flushTreatments];
  }
  
  - (void) flushDeviceStatuses {
  
  if (self.deviceStatuses.count == 0) {
  return;
  }
  
  NSArray *inFlightDeviceStatuses = self.deviceStatuses;
  self.deviceStatuses = [[NSMutableArray alloc] init];
  [self reportJSON:inFlightDeviceStatuses toNightScoutEndpoint:defaultNightscoutDeviceStatusPath completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
  if (httpResponse.statusCode != 200) {
  NSLog(@"Requeuing %d device statuses: %@", inFlightDeviceStatuses.count, error);
  [self.deviceStatuses addObjectsFromArray:inFlightDeviceStatuses];
  } else {
  //NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  //NSLog(@"Submitted %d device statuses to nightscout: %@", inFlightDeviceStatuses.count, resp);
  }
  }];
  }
  
  - (void) flushEntries {
  
  if (self.entries.count == 0) {
  return;
  }
  
  NSArray *inFlightEntries = self.entries;
  self.entries = [[NSMutableArray alloc] init];
  [self reportJSON:inFlightEntries toNightScoutEndpoint:defaultNightscoutEntriesPath completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
  if (httpResponse.statusCode != 200) {
  NSLog(@"Requeuing %d sgv entries: %@", inFlightEntries.count, error);
  [self.entries addObjectsFromArray:inFlightEntries];
  } else {
  //NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  //NSLog(@"Submitted %d entries to nightscout: %@", inFlightEntries.count, resp);
  }
  }];
  }
  
  - (void) flushTreatments {
  
  if (self.treatmentsQueue.count == 0) {
  return;
  }
  
  NSArray *inFlightTreatments = self.treatmentsQueue;
  self.treatmentsQueue = [NSMutableArray array];
  [self reportJSON:inFlightTreatments toNightScoutEndpoint:defaultNightscoutTreatmentPath completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
  if (httpResponse.statusCode != 200) {
  NSLog(@"Requeuing %d treatments: %@", inFlightTreatments.count, error);
  [self.treatmentsQueue addObjectsFromArray:inFlightTreatments];
  } else {
  //NSString *resp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  [self.sentTreatments addObjectsFromArray:inFlightTreatments];
  //NSLog(@"Submitted %d treatments to nightscout: %@", inFlightTreatments.count, resp);
  }
  }];
  }
  
  - (void) reportJSON:(NSArray*)outgoingJSON toNightScoutEndpoint:(NSString*)endpoint
  completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
  {
  NSURL *uploadURL = [NSURL URLWithString:endpoint
  relativeToURL:[NSURL URLWithString:self.siteURL]];
  NSMutableURLRequest *request = [[NSURLRequest requestWithURL:uploadURL] mutableCopy];
  NSError *error;
  NSData *sendData = [NSJSONSerialization dataWithJSONObject:outgoingJSON options:NSJSONWritingPrettyPrinted error:&error];
  //NSString *jsonPost = [[NSString alloc] initWithData:sendData encoding:NSUTF8StringEncoding];
  //NSLog(@"Posting to %@, %@", [uploadURL absoluteString], jsonPost);
  request.HTTPMethod = @"POST";
  
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
  [request setValue:(self.APISecret).sha1 forHTTPHeaderField:@"api-secret"];
  
  request.HTTPBody = sendData;
  
  [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:completionHandler] resume];
  }
  

}
