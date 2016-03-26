//
//  PumpOpsSynchronous.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/12/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit

public enum PumpCommsError: ErrorType {
  case RFCommsFailure(String)
  case UnknownPumpModel
  case RileyLinkTimeout
}

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
    
    guard let response1 = shortResponse where response1.messageType == .PumpAck else {
      return false
    }
    NSLog("Pump acknowledged wakeup!")

    let longPowerMessage = makePumpMessage(.PowerOn, body: PowerOnCarelinkMessageBody(duration: NSTimeInterval(durationMinutes * 60)))
    let longResponse = sendAndListen(longPowerMessage)
    
    guard let response2 = longResponse where response2.messageType == .PumpAck else {
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
    
    guard let shortResponse = shortResponseOpt where shortResponse.messageType == .PumpAck else {
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
    
    guard defaultWake() else {
      return nil
    }

    let msg = makePumpMessage(.GetPumpModel, body: CarelinkShortMessageBody())
    let responseOpt = sendAndListen(msg)
    
    guard let response = responseOpt where response.messageType == .GetPumpModel else {
      return nil
    }
    
    return (response.messageBody as! GetPumpModelCarelinkMessageBody).model
  }
  
  func getBatteryVoltage() -> GetBatteryCarelinkMessageBody? {
    
    guard defaultWake() else {
      return nil
    }
    
    let msg = makePumpMessage(.GetBattery, body: CarelinkShortMessageBody())
    let responseOpt = sendAndListen(msg)
  
    guard let response = responseOpt where response.messageType == .GetBattery else {
      return nil
    }
    return response.messageBody as? GetBatteryCarelinkMessageBody
  }
  
  func updateRegister(addr: UInt8, value: UInt8) throws {
    let cmd = UpdateRegisterCmd()
    cmd.addr = addr;
    cmd.value = value;
    if !session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS) {
      throw PumpCommsError.RileyLinkTimeout
    }
  }
  
  func setBaseFrequency(freqMhz: Double) throws {
    let val = Int((freqMhz * 1000000)/(Double(RILEYLINK_FREQ_XTAL)/pow(2.0,16.0)))
    
    try updateRegister(UInt8(CC111X_REG_FREQ0), value:UInt8(val & 0xff))
    try updateRegister(UInt8(CC111X_REG_FREQ1), value:UInt8((val >> 8) & 0xff))
    try updateRegister(UInt8(CC111X_REG_FREQ2), value:UInt8((val >> 16) & 0xff))
    NSLog("Set frequency to %f", freqMhz)
  }

  
  func scanForPump() throws -> FrequencyScanResults {
    
    let frequencies = [916.55, 916.60, 916.65, 916.70, 916.75, 916.80]
    var results = FrequencyScanResults()
    
    defaultWake()
    
    for freq in frequencies {
      let tries = 3
      var trial = FrequencyTrial()
      trial.frequencyMHz = freq
      try setBaseFrequency(freq)
      var sumRSSI = 0
      for _ in 1...tries {
        let msg = makePumpMessage(.GetPumpModel, body: CarelinkShortMessageBody())
        let cmd = SendAndListenCmd()
        cmd.packet = RFPacket(data: msg.txData)
        cmd.timeoutMS = standardPumpResponseWindow
        if session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS) {
          if let data =  cmd.receivedPacket.data,
            let response = PumpMessage.init(rxData: data) where response.messageType == .GetPumpModel {
              sumRSSI += Int(cmd.receivedPacket.rssi)
              trial.successes += 1
          }
        } else {
          throw PumpCommsError.RileyLinkTimeout
        }
        trial.tries += 1
      }
      // Mark each failure as a -99 rssi, so we can use highest rssi as best freq
      sumRSSI += -99 * (trial.tries - trial.successes)
      trial.avgRSSI = Double(sumRSSI) / Double(trial.tries)
      results.trials.append(trial)
    }
    let sortedTrials = results.trials.sort({ (a, b) -> Bool in
      return a.avgRSSI > b.avgRSSI
    })
    if sortedTrials.first!.successes > 0 {
      results.bestFrequency = sortedTrials.first!.frequencyMHz
      try setBaseFrequency(results.bestFrequency)
    }
    
    return results
  }

  func getHistoryEventsSinceDate(startDate: NSDate) throws -> ([PumpEvent], PumpModel) {
    
    if !defaultWake() {
      try scanForPump()
    }
    
    guard let pumpModelStr = getPumpModel() else {
      throw PumpCommsError.RFCommsFailure("getPumpModel failed")
    }
    
    guard let pumpModel = PumpModel.byModelNumber(pumpModelStr) else {
      throw PumpCommsError.UnknownPumpModel
    }
    
    var pageNum = 0
    var events = [PumpEvent]()
    while pageNum < 16 {
      NSLog("Fetching page %d", pageNum)
      let pageData = try getHistoryPage(pageNum)
      NSLog("Fetched page %d: %@", pageNum, pageData.hexadecimalString)
      let page = try HistoryPage(pageData: pageData, pumpModel: pumpModel)
      var eventIdxBeforeStartDate = -1
      for (reverseIndex, event) in page.events.reverse().enumerate() {
        if event is TimestampedPumpEvent {
          let event = event as! TimestampedPumpEvent
          if let date = TimeFormat.timestampAsLocalDate(event.timestamp) {
            if date.compare(startDate) == .OrderedAscending  {
              NSLog("Found event (%@) before startDate(%@)", date, startDate);
              eventIdxBeforeStartDate = page.events.count - reverseIndex
              break
            }
          }
        }
      }
      if eventIdxBeforeStartDate >= 0 {
        let slice = page.events[eventIdxBeforeStartDate..<(page.events.count)]
        events.insertContentsOf(slice, at: 0)
        break
      }
      events.insertContentsOf(page.events, at: 0)
      pageNum += 1
    }
    return (events, pumpModel)
  }
  
  func getHistoryPage(pageNum: Int) throws -> NSData {
    let frameData = NSMutableData()
    
    let msg = makePumpMessage(.GetHistoryPage, body: GetHistoryPageCarelinkMessageBody(pageNum: pageNum))
    let firstResponse = runCommandWithArguments(msg)
    
    guard firstResponse != nil else {
      throw PumpCommsError.RFCommsFailure("Pump not responding to GetHistory command")
    }
    
    var expectedFrameNum = 1
    var curResp = firstResponse!.messageBody as! GetHistoryPageCarelinkMessageBody
    
    while(expectedFrameNum == curResp.frameNumber) {
      frameData.appendData(curResp.frame)
      expectedFrameNum += 1
      let msg = makePumpMessage(.PumpAck, body: CarelinkShortMessageBody())
      if !curResp.lastFrame {
        let resp = sendAndListen(msg)
        guard resp != nil else {
          throw PumpCommsError.RFCommsFailure("Did not receive frame data from pump")
        }
        guard resp!.packetType == .Carelink && resp!.messageType == .GetHistoryPage else {
          throw PumpCommsError.RFCommsFailure("Bad packet type or message type. Possible interference.")
        }
        curResp = resp!.messageBody as! GetHistoryPageCarelinkMessageBody
      } else {
        let cmd = SendPacketCmd()
        cmd.packet = RFPacket(data: msg.txData)
        session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS)
        break
      }
    }
    
    guard frameData.length == 1024 else {
      throw PumpCommsError.RFCommsFailure("Short history page: " + String(frameData.length) + " bytes. Expected 1024")
    }
    return frameData
  }
}

struct HistoryFetchResults {
  var error: String?
  var pumpModel: String?
  var pageData: NSData?
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
}



