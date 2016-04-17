//
//  PumpOpsSynchronous.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/12/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit
import RileyLinkBLEKit


public enum PumpCommsError: ErrorType {
  case RFCommsFailure(String)
  case UnknownPumpModel
  case RileyLinkTimeout
  case UnknownResponse
}


public class PumpOpsSynchronous: NSObject {

  private static let standardPumpResponseWindow: UInt16 = 180
  private let expectedMaxBLELatencyMS = 1500
  
  public let pump: PumpState
  public let session: RileyLinkCmdSession
  
  public init(pumpState: PumpState, session: RileyLinkCmdSession) {
    self.pump = pumpState
    self.session = session
  }
  
  private func makePumpMessage(messageType: MessageType, body: MessageBody) -> PumpMessage {
    return PumpMessage(packetType: .Carelink, address: pump.pumpID, messageType: messageType, messageBody: body)
  }
  
  internal func sendAndListen(msg: PumpMessage, timeoutMS: UInt16 = standardPumpResponseWindow, repeatCount: UInt8 = 0, msBetweenPackets: UInt8 = 0, retryCount: UInt8 = 3) throws -> PumpMessage {
    let cmd = SendAndListenCmd()
    cmd.packet = RFPacket(data: msg.txData)
    cmd.timeoutMS = timeoutMS
    cmd.repeatCount = repeatCount
    cmd.msBetweenPackets = msBetweenPackets
    cmd.retryCount = retryCount
    cmd.listenChannel = 0

    let totalTimeout = Int(retryCount) * Int(msBetweenPackets) + Int(timeoutMS) + expectedMaxBLELatencyMS

    if session.doCmd(cmd, withTimeoutMs: totalTimeout) {
      guard let data = cmd.receivedPacket.data, message = PumpMessage(rxData: data) else {
        throw PumpCommsError.UnknownResponse
      }
      return message
    }
    throw PumpCommsError.RileyLinkTimeout
  }

  private func wakeup(duration: NSTimeInterval = NSTimeInterval(minutes: 1)) throws {
    guard !pump.isAwake else {
      return
    }
    
    let shortPowerMessage = makePumpMessage(.PowerOn, body: CarelinkShortMessageBody())
    let shortResponse = try sendAndListen(shortPowerMessage, timeoutMS: 15000, repeatCount: 200, msBetweenPackets: 0, retryCount: 0)
    
    guard shortResponse.messageType == .PumpAck else {
      throw PumpCommsError.UnknownResponse
    }
    NSLog("Pump acknowledged wakeup!")

    let longPowerMessage = makePumpMessage(.PowerOn, body: PowerOnCarelinkMessageBody(duration: duration))
    let longResponse = try sendAndListen(longPowerMessage)
    
    guard longResponse.messageType == .PumpAck else {
      throw PumpCommsError.UnknownResponse
    }

    NSLog("Power on for %d minutes", duration.minutes)
    pump.awakeUntil = NSDate(timeIntervalSinceNow: duration)
  }

  private func runCommandWithArguments(msg: PumpMessage) throws -> PumpMessage {
    let shortMsg = makePumpMessage(msg.messageType, body: CarelinkShortMessageBody())
    let shortResponse = try sendAndListen(shortMsg)
    
    guard shortResponse.messageType == .PumpAck else {
      throw PumpCommsError.UnknownResponse
    }
    
    return try sendAndListen(msg)
  }

  internal func pressButton(buttonType: ButtonPressCarelinkMessageBody.ButtonType) throws {
    try wakeup()

    let msg = makePumpMessage(.ButtonPress, body: ButtonPressCarelinkMessageBody(buttonType: buttonType))

    try runCommandWithArguments(msg)

    NSLog("Pump acknowledged button press (with args)!")
  }
  
  internal func getPumpModel() throws -> String {
    try wakeup()

    let msg = makePumpMessage(.GetPumpModel, body: CarelinkShortMessageBody())
    let response = try sendAndListen(msg)
    
    guard response.messageType == .GetPumpModel, let body = response.messageBody as? GetPumpModelCarelinkMessageBody else {
      throw PumpCommsError.UnknownResponse
    }
    
    return body.model
  }
  
  internal func getBatteryVoltage() throws -> GetBatteryCarelinkMessageBody {
    try wakeup()
    
    let msg = makePumpMessage(.GetBattery, body: CarelinkShortMessageBody())
    let response = try sendAndListen(msg)
  
    guard response.messageType == .GetBattery, let body = response.messageBody as? GetBatteryCarelinkMessageBody else {
      throw PumpCommsError.UnknownResponse
    }
    return body
  }
  
  private func updateRegister(addr: UInt8, value: UInt8) throws {
    let cmd = UpdateRegisterCmd()
    cmd.addr = addr;
    cmd.value = value;
    if !session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS) {
      throw PumpCommsError.RileyLinkTimeout
    }
  }
  
  private func setBaseFrequency(freqMhz: Double) throws {
    let val = Int((freqMhz * 1000000)/(Double(RILEYLINK_FREQ_XTAL)/pow(2.0,16.0)))
    
    try updateRegister(UInt8(CC111X_REG_FREQ0), value:UInt8(val & 0xff))
    try updateRegister(UInt8(CC111X_REG_FREQ1), value:UInt8((val >> 8) & 0xff))
    try updateRegister(UInt8(CC111X_REG_FREQ2), value:UInt8((val >> 16) & 0xff))
    NSLog("Set frequency to %f", freqMhz)
  }

  
  internal func scanForPump() throws -> FrequencyScanResults {
    
    let frequencies = [916.55, 916.60, 916.65, 916.70, 916.75, 916.80]
    var results = FrequencyScanResults()

    do {
      try wakeup()
    } catch {
      // Continue anyway
    }
    
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
        cmd.timeoutMS = self.dynamicType.standardPumpResponseWindow
        if session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS) {
          if let data =  cmd.receivedPacket.data,
            let response = PumpMessage(rxData: data) where response.messageType == .GetPumpModel {
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

  internal func getHistoryEventsSinceDate(startDate: NSDate) throws -> ([PumpEvent], PumpModel) {

    do {
      try wakeup()
    } catch _ as PumpCommsError {
      try scanForPump()
    }

    guard let pumpModelStr = try? getPumpModel() else {
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
      NSLog("Fetched page %d: %@", pageNum, pageData)
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
  
  private func getHistoryPage(pageNum: Int) throws -> NSData {
    let frameData = NSMutableData()
    
    let msg = makePumpMessage(.GetHistoryPage, body: GetHistoryPageCarelinkMessageBody(pageNum: pageNum))
    
    guard let firstResponse = try? runCommandWithArguments(msg) else {
      throw PumpCommsError.RFCommsFailure("Pump not responding to GetHistory command")
    }
    
    var expectedFrameNum = 1
    var curResp = firstResponse.messageBody as! GetHistoryPageCarelinkMessageBody
    
    while(expectedFrameNum == curResp.frameNumber) {
      frameData.appendData(curResp.frame)
      expectedFrameNum += 1
      let msg = makePumpMessage(.PumpAck, body: CarelinkShortMessageBody())
      if !curResp.lastFrame {
        guard let resp = try? sendAndListen(msg) else {
          throw PumpCommsError.RFCommsFailure("Did not receive frame data from pump")
        }
        guard resp.packetType == .Carelink && resp.messageType == .GetHistoryPage else {
          throw PumpCommsError.RFCommsFailure("Bad packet type or message type. Possible interference.")
        }
        curResp = resp.messageBody as! GetHistoryPageCarelinkMessageBody
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

public struct FrequencyTrial {
  public var tries: Int = 0
  public var successes: Int = 0
  public var avgRSSI: Double = -99
  public var frequencyMHz: Double = 0
}

public struct FrequencyScanResults {
  public var trials = [FrequencyTrial]()
  public var bestFrequency: Double = 0
}
