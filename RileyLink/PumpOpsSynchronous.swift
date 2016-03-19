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
  
  func scanForPump() -> FrequencyScanResults {
    
    let frequencies = [916.55, 916.60, 916.65, 916.70, 916.75, 916.80]
    var results = FrequencyScanResults()
    
    defaultWake()
    
    for freq in frequencies {
      let tries = 3
      var trial = FrequencyTrial()
      trial.frequencyMHz = freq
      setBaseFrequency(freq)
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
          // RL Not responding?
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
    results.bestFrequency = sortedTrials.first!.frequencyMHz
    setBaseFrequency(results.bestFrequency)
    
    
    return results
  }

  func updateRegister(addr: UInt8, value: UInt8) {
    let cmd = UpdateRegisterCmd()
    cmd.addr = addr;
    cmd.value = value;
    session.doCmd(cmd, withTimeoutMs: expectedMaxBLELatencyMS)
  }
  
  func setBaseFrequency(freqMhz: Double) {
    let val = Int((freqMhz * 1000000)/(Double(RILEYLINK_FREQ_XTAL)/pow(2.0,16.0)))
  
    updateRegister(UInt8(CC111X_REG_FREQ0), value:UInt8(val & 0xff))
    updateRegister(UInt8(CC111X_REG_FREQ1), value:UInt8((val >> 8) & 0xff))
    updateRegister(UInt8(CC111X_REG_FREQ2), value:UInt8((val >> 16) & 0xff))
    NSLog("Set frequency to %f", freqMhz)
  }
  
  func getHistoryPage(pageNum: Int) -> HistoryFetchResults {
    let frameData = NSMutableData()
    
    var results = HistoryFetchResults()
    
    if !defaultWake() {
      let scanResults = scanForPump()
      if scanResults.error != nil {
        results.error = "Frequency tuning failed: " + scanResults.error!
        return results
      }
    }
    
    results.pumpModel = getPumpModel()
    guard results.pumpModel != nil else {
      results.error = "Unable to get pump model"
      return results
    }
    
    let msg = makePumpMessage(.GetHistoryPage, body: GetHistoryPageCarelinkMessageBody(pageNum: pageNum))
    let firstResponse = runCommandWithArguments(msg)
    
    guard firstResponse != nil else {
      results.error = "Pump did not respond to GetHistory command"
      return results
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
          results.error = "Missed frame " + String(expectedFrameNum)
          return results
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
      results.error = "Unexpected page size: " + String(frameData.length)
      return results
    }
    results.pageData = frameData
    return results
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
  var error: String?
}



