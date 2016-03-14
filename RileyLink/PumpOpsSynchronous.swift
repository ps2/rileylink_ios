//
//  PumpOpsSynchronous.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/12/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit

class PumpOpsSynchronous: NSObject {

  let standardPumpResponseWindow: UInt16 = 180
  let expectedMaxBLELatencyMS = 1500
  
  let pump: PumpState
  let session: RileyLinkCmdSession
  
  init(pumpState: PumpState, session: RileyLinkCmdSession) {
    self.pump = pumpState
    self.session = session
  }
  
  func makePumpMessage(messageType: MessageType, body: MessageBody) -> PumpMessage {
    return PumpMessage.init(packetType: .Carelink, address: pump.pumpId, messageType: messageType, messageBody: body)
  }
  
  func sendAndListen(msg: PumpMessage, timeoutMS: UInt16, repeatCount: UInt8, msBetweenPackets: UInt8, retryCount: UInt8) -> PumpMessage? {
    let cmd = SendAndListenCmd()
    cmd.packet = RFPacket(data: msg.txData)
    cmd.timeoutMS = timeoutMS
    cmd.repeatCount = repeatCount
    cmd.msBetweenPackets = msBetweenPackets
    cmd.retryCount = retryCount
    cmd.listenChannel = 0
    let totalTimeout = Int(retryCount) * Int(msBetweenPackets) + Int(timeoutMS) + expectedMaxBLELatencyMS
    if session.doCmd(cmd, withTimeoutMs: totalTimeout) {
      if let data =  cmd.receivedPacket.data {
        return PumpMessage.init(rxData: data)
      }
    }
    return nil
  }
  
  func sendAndListen(msg: PumpMessage) -> PumpMessage? {
    return sendAndListen(msg, timeoutMS: standardPumpResponseWindow, repeatCount: 0, msBetweenPackets: 0, retryCount: 3)
  }

  func wakeup(durationMinutes: Int) -> Bool {
    if pump.awake {
      return true
    }
    
    let shortPowerMessage = makePumpMessage(.PowerOn, body: CarelinkShortMessageBody())
    let shortResponse = sendAndListen(shortPowerMessage, timeoutMS: 15000, repeatCount: 200, msBetweenPackets: 0, retryCount: 0)
    
    guard let response1 = shortResponse where response1.messageType == .PumpStatusAck else {
      return false
    }
    NSLog("Pump acknowledged wakeup!")

    let longPowerMessage = makePumpMessage(.PowerOn, body: PowerOnCarelinkMessageBody(duration: NSTimeInterval(durationMinutes * 60)))
    let longResponse = sendAndListen(longPowerMessage)
    
    guard let response2 = longResponse where response2.messageType == .PumpStatusAck else {
      return false
    }

    NSLog("Power on for %d minutes", durationMinutes)
    pump.awakeUntil = NSDate(timeIntervalSinceNow: NSTimeInterval(durationMinutes*60))
    return true
  }
  
  func defaultWake() -> Bool {
    return wakeup(1)
  }
  
  func runCommandWithArguments(msg: PumpMessage) -> PumpMessage? {
    let shortMsg = makePumpMessage(msg.messageType, body: CarelinkShortMessageBody())
    let shortResponseOpt = sendAndListen(shortMsg)
    
    guard let shortResponse = shortResponseOpt where shortResponse.messageType == .PumpStatusAck else {
      return nil
    }
    
    return sendAndListen(msg)
  }

  func pressButton(buttonType: ButtonPressCarelinkMessageBody.ButtonType) {
  
    if defaultWake() {
      let msg = makePumpMessage(.ButtonPress, body: ButtonPressCarelinkMessageBody(buttonType: buttonType))
      if runCommandWithArguments(msg) != nil {
        NSLog("Pump acknowledged button press (with args)!")
      }
    }
    
  }
  
  func getPumpModel() -> String? {
    
    if defaultWake() {
      let msg = makePumpMessage(.GetPumpModel, body: CarelinkShortMessageBody())
      let responseOpt = sendAndListen(msg)
      
      guard let response = responseOpt where response.messageType == .GetPumpModel else {
        return nil
      }
      
      return (response.messageBody as! GetPumpModelCarelinkMessageBody).model
    }
  }
  
  func getBatteryVoltage() -> GetBatteryCarelinkMessageBody? {
    
    if defaultWake() {
      let msg = makePumpMessage(.GetBattery, body: CarelinkShortMessageBody())
      let responseOpt = sendAndListen(msg)
    
      guard let response = responseOpt where response.messageType == .GetBattery else {
        return nil
      }
      return response.messageBody as? GetBatteryCarelinkMessageBody
    }
  }
  
  func parseFramesIntoHistoryPage(frames: [NSData]) -> NSData? {
    let data = NSMutableData()
    let r = NSMakeRange(6, 64)
    for frame in frames {
      if frame.length < 70 {
        return nil
      }
      data.appendData(frame.subdataWithRange(r))
    }
    return data
  }
  
  struct FrequencyTrial {
    var tries: Int = 0
    var successes: Int = 0
    var avgRSSI: Double = -99
    var frequencyMHz: Double = 0
  }
  
  struct FrequencyScanResults {
    var trials = [FrequencyTrial]()
    var bestFrequency: Double = 0
    var error: String?
  }
  
  func scanForPump() -> FrequencyScanResults {
    
    let frequencies = [916.55, 916.60, 916.65, 916.70, 916.75, 916.80]
    var results = FrequencyScanResults()
    
    guard defaultWake() else {
      results.error = "Unable to wake pump"
      return results
    }
    
    for freq in frequencies {
      var avgRSSI = 0
      let tries = 3
      var trial = FrequencyTrial()
      trial.frequencyMHz = freq
      setBaseFrequency(freq)
      var sumRSSI = 0
      for i in 0...tries {
        let msg = makePumpMessage(.GetPumpModel, body: CarelinkShortMessageBody())
        let cmd = SendAndListenCmd()
        cmd.packet = RFPacket(data: msg.txData)
        cmd.timeoutMS = standardPumpResponseWindow
        var success = false
        var sumRSSI: Double = 0
        if session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS) {
          if let data =  cmd.receivedPacket.data,
            let response = PumpMessage.init(rxData: data) where response.messageType == .GetPumpModel {
              sumRSSI += Double(cmd.receivedPacket.rssi)
              trial.successes += 1
          }
        } else {
          // RL Not responding?
        }
        trial.tries += 1
      }
      // Mark each failure as a -99 rssi, so we can use highest rssi as best freq
      sumRSSI += -99 * (trial.tries - trial.successes)'
      trial.avgRSSI = sumRSSI / trial.tries
    
      avgRSSI = avgRSSI / ((float)tries);
      [scanResults addObject:@(successCount)];
      [rssi addObject:@(avgRSSI)];
    }
    int bestResult = -99, bestIndex = 0;
    for (int i=0; i<rssi.count; i++) {
    NSNumber *result = rssi[i];
    if (result.intValue > bestResult) {
    bestResult = result.intValue;
    bestIndex = i;
    }
    }
    NSMutableDictionary *rval = [NSMutableDictionary dictionary];
    rval[@"frequencies"] = frequencies;
    rval[@"scanResults"] = scanResults;
    rval[@"avgRSSI"] = rssi;
    
    if (totalSuccesses > 0) {
    rval[@"bestFreq"] = frequencies[bestIndex];
    NSLog(@"Scanning found best results at %@MHz (RSSI: %@)", frequencies[bestIndex], rssi[bestIndex]);
    } else {
    rval[@"error"] = @"Pump did not respond on any of the attempted frequencies.";
    }
    [self setBaseFrequency:[frequencies[bestIndex] floatValue]];
    
    NSLog(@"Frequency scan results: %@", rval);
    
    return rval;
  }

  - (void)updateRegister:(uint8_t)addr toValue:(uint8_t)value {
  UpdateRegisterCmd *cmd = [[UpdateRegisterCmd alloc] init];
  cmd.addr = addr;
  cmd.value = value;
  [_session doCmd:cmd withTimeoutMs:EXPECTED_MAX_BLE_LATENCY_MS];
  }
  
  - (void)setBaseFrequency:(float)freqMhz {
  uint32_t val = (freqMhz * 1000000)/(RILEYLINK_FREQ_XTAL/pow(2.0,16.0));
  
  [self updateRegister:CC111X_REG_FREQ0 toValue:val & 0xff];
  [self updateRegister:CC111X_REG_FREQ1 toValue:(val >> 8) & 0xff];
  [self updateRegister:CC111X_REG_FREQ2 toValue:(val >> 16) & 0xff];
  NSLog(@"Set frequency to %f", freqMhz);
  }
  
  - (NSDictionary*) getHistoryPage:(uint8_t)pageNum {
  float rssiSum = 0;
  int rssiCount = 0;
  
  NSMutableDictionary *responseDict = [NSMutableDictionary dictionary];
  NSMutableArray *responses = [NSMutableArray array];
  
  [self wakeIfNeeded];
  
  NSString *pumpModel = [self getPumpModel];
  
  if (!pumpModel) {
  NSDictionary *tuneResults = [self scanForPump];
  if (tuneResults[@"error"]) {
  responseDict[@"error"] = @"Could not find pump, even after scanning.";
  }
  // Try again to get pump model, after scanning/tuning
  pumpModel = [self getPumpModel];
  }
  
  if (!pumpModel) {
  responseDict[@"error"] = @"get model failed";
  return responseDict;
  } else {
  responseDict[@"pumpModel"] = pumpModel;
  }
  
  MinimedPacket *response;
  response = [self sendAndListen:[self msgType:MESSAGE_TYPE_READ_HISTORY withArgs:@"00"].data];
  
  if (response && response.messageType == MESSAGE_TYPE_ACK) {
  rssiSum += response.rssi;
  rssiCount += 1;
  NSLog(@"Pump acked dump msg (0x80)")
  } else {
  NSLog(@"Missing response to initial read history command");
  responseDict[@"error"] = @"Missing response to initial read history command";
  return responseDict;
  }
  
  NSString *dumpHistArgs = [NSString stringWithFormat:@"01%02x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", pageNum];
  
  response = [self sendAndListen:[self msgType:MESSAGE_TYPE_READ_HISTORY withArgs:dumpHistArgs].data];
  
  if (response && response.messageType == MESSAGE_TYPE_READ_HISTORY) {
  rssiSum += response.rssi;
  rssiCount += 1;
  [responses addObject:response.data];
  } else {
  NSLog(@"Read history with args command failed");
  responseDict[@"error"] = @"Read history with args command failed";
  return responseDict;
  }
  
  // Send 15 acks, and expect 15 more dumps
  for (int i=0; i<15; i++) {
  
  response = [self sendAndListen:[self msgType:MESSAGE_TYPE_ACK withArgs:@"00"].data];
  
  if (response && response.messageType == MESSAGE_TYPE_READ_HISTORY) {
  rssiSum += response.rssi;
  rssiCount += 1;
  [responses addObject:response.data];
  } else {
  NSLog(@"Read history segment %d with args command failed", i);
  responseDict[@"error"] = @"Read history with args command failed";
  return responseDict;
  }
  responseDict[@"pageData"] = [self parseFramesIntoHistoryPage:responses];
  }
  
  if (rssiCount > 0) {
  responseDict[@"avgRSSI"] = @((int)(rssiSum / rssiCount));
  }
  
  // Last ack packet doesn't need a response
  SendPacketCmd *cmd = [[SendPacketCmd alloc] init];
  cmd.packet = [[RFPacket alloc] initWithData:[self msgType:MESSAGE_TYPE_ACK withArgs:@"00"].data];
  [_session doCmd:cmd withTimeoutMs:EXPECTED_MAX_BLE_LATENCY_MS];
  return responseDict;


}
