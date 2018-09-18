//
//  PodComms.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/7/17.
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkBLEKit
import LoopKit
import os.log

public protocol PodCommsDelegate: class {
    func podComms(_ podComms: PodComms, didChange state: PodState)
}

public class PodComms {
    
    private var configuredDevices: Set<RileyLinkDevice> = Set()
    
    private weak var delegate: PodCommsDelegate?

    private let sessionQueue = DispatchQueue(label: "com.rileylink.OmniKit.PodComms", qos: .utility)

    public let log = OSLog(category: "PodComms")
    
    private var podState: PodState {
        didSet {
            self.delegate?.podComms(self, didChange: podState)
        }
    }

    public init(podState: PodState, delegate: PodCommsDelegate?) {
        self.podState = podState
        self.delegate = delegate
    }
    
    public enum PairResults {
        case success(podState: PodState)
        case failure(Error)
    }
    
    public class func pair(using deviceSelector: @escaping (_ completion: @escaping (_ device: RileyLinkDevice?) -> Void) -> Void, timeZone: TimeZone, completion: @escaping (PairResults) -> Void)
    {
        deviceSelector { (device) in
            guard let device = device else {
                completion(.failure(PodCommsError.noRileyLinkAvailable))
                return
            }

            device.runSession(withName: "Pair Pod") { (commandSession) in
                
                do {
                    try commandSession.configureRadio()
                    
                    // Create random address with 20 bits.  Can we use all 24 bits?
                    let newAddress = 0x1f000000 | (arc4random() & 0x000fffff)
                    
                    let transport = MessageTransport(session: commandSession, address: 0xffffffff, ackAddress: newAddress)
                
                    // Assign Address
                    let assignAddress = AssignAddressCommand(address: newAddress)
                    
                    let response = try transport.send([assignAddress])
                    guard let config1 = response.messageBlocks[0] as? VersionResponse else {
                        let responseType = response.messageBlocks[0].blockType
                        throw PodCommsError.unexpectedResponse(response: responseType)
                    }
                    
                    // Verify address is set
                    let activationDate = Date()
                    let dateComponents = SetupPodCommand.dateComponents(date: activationDate, timeZone: timeZone)
                    let setupPod = SetupPodCommand(address: newAddress, dateComponents: dateComponents, lot: config1.lot, tid: config1.tid)
                    
                    let response2 = try transport.send([setupPod])
                    guard let config2 = response2.messageBlocks[0] as? VersionResponse else {
                        let responseType = response.messageBlocks[0].blockType
                        throw PodCommsError.unexpectedResponse(response: responseType)
                    }
                    
                    guard config2.pairingState == .paired else {
                        throw PodCommsError.invalidData
                    }
                    let newPodState = PodState(
                        address: newAddress,
                        activatedAt: activationDate,
                        timeZone: timeZone,
                        piVersion: String(describing: config2.piVersion),
                        pmVersion: String(describing: config2.pmVersion),
                        lot: config2.lot,
                        tid: config2.tid
                    )
                    completion(.success(podState: newPodState))
                } catch let error {
                    completion(.failure(error))
                }
            }
        }
    }
    
    public enum SessionRunResult {
        case success(session: PodCommsSession)
        case failure(PodCommsError)
    }
    
    public func runSession(withName name: String, using deviceSelector: @escaping (_ completion: @escaping (_ device: RileyLinkDevice?) -> Void) -> Void, _ block: @escaping (_ result: SessionRunResult) -> Void) {
        sessionQueue.async {
            let semaphore = DispatchSemaphore(value: 0)
            
            deviceSelector { (device) in
                guard let device = device else {
                    block(.failure(PodCommsError.noRileyLinkAvailable))
                    semaphore.signal()
                    return
                }
            
                device.runSession(withName: name) { (commandSession) in
                    self.configureDevice(device, with: commandSession)
                    let transport = MessageTransport(session: commandSession, address: self.podState.address)
                    let podSession = PodCommsSession(podState: self.podState, transport: transport, delegate: self)
                    block(.success(session: podSession))
                    semaphore.signal()
                }
            }
            
            semaphore.wait()
        }
    }
    
    // Must be called from within the RileyLinkDevice sessionQueue
    private func configureDevice(_ device: RileyLinkDevice, with session: CommandSession) {
        guard !self.configuredDevices.contains(device) else {
            return
        }
        
        do {
            log.debug("configureRadio (omnipod)")
            _ = try session.configureRadio()
        } catch let error {
            log.error("configure Radio failed with error: %{public}@", String(describing: error))
            // Ignore the error and let the block run anyway
            return
        }
        
        NotificationCenter.default.post(name: .DeviceRadioConfigDidChange, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceRadioConfigDidChange(_:)), name: .DeviceRadioConfigDidChange, object: device)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceRadioConfigDidChange(_:)), name: .DeviceConnectionStateDidChange, object: device)
        
        log.debug("added device %{public}@ to configuredDevices", device.name ?? "unknown")
        configuredDevices.insert(device)
    }
    
    @objc private func deviceRadioConfigDidChange(_ note: Notification) {
        guard let device = note.object as? RileyLinkDevice else {
            return
        }
        log.debug("removing device %{public}@ from configuredDevices", device.name ?? "unknown")

        NotificationCenter.default.removeObserver(self, name: .DeviceRadioConfigDidChange, object: device)
        NotificationCenter.default.removeObserver(self, name: .DeviceConnectionStateDidChange, object: device)
        configuredDevices.remove(device)
    }
}

private extension CommandSession {
    
    func configureRadio() throws {
        
        //        SYNC1     |0xDF00|0x54|Sync Word, High Byte
        //        SYNC0     |0xDF01|0xC3|Sync Word, Low Byte
        //        PKTLEN    |0xDF02|0x32|Packet Length
        //        PKTCTRL1  |0xDF03|0x24|Packet Automation Control
        //        PKTCTRL0  |0xDF04|0x00|Packet Automation Control
        //        FSCTRL1   |0xDF07|0x06|Frequency Synthesizer Control
        //        FREQ2     |0xDF09|0x12|Frequency Control Word, High Byte
        //        FREQ1     |0xDF0A|0x14|Frequency Control Word, Middle Byte
        //        FREQ0     |0xDF0B|0x5F|Frequency Control Word, Low Byte
        //        MDMCFG4   |0xDF0C|0xCA|Modem configuration
        //        MDMCFG3   |0xDF0D|0xBC|Modem Configuration
        //        MDMCFG2   |0xDF0E|0x0A|Modem Configuration
        //        MDMCFG1   |0xDF0F|0x13|Modem Configuration
        //        MDMCFG0   |0xDF10|0x11|Modem Configuration
        //        MCSM0     |0xDF14|0x18|Main Radio Control State Machine Configuration
        //        FOCCFG    |0xDF15|0x17|Frequency Offset Compensation Configuration
        //        AGCCTRL1  |0xDF18|0x70|AGC Control
        //        FSCAL3    |0xDF1C|0xE9|Frequency Synthesizer Calibration
        //        FSCAL2    |0xDF1D|0x2A|Frequency Synthesizer Calibration
        //        FSCAL1    |0xDF1E|0x00|Frequency Synthesizer Calibration
        //        FSCAL0    |0xDF1F|0x1F|Frequency Synthesizer Calibration
        //        TEST1     |0xDF24|0x31|Various Test Settings
        //        TEST0     |0xDF25|0x09|Various Test Settings
        //        PA_TABLE0 |0xDF2E|0x60|PA Power Setting 0
        //        VERSION   |0xDF37|0x04|Chip ID[7:0]
        
        try setSoftwareEncoding(.manchester)
        try setPreamble(0x6665)
        try setBaseFrequency(Measurement(value: 433.91, unit: .megahertz))
        try updateRegister(.pktctrl1, value: 0x20)
        try updateRegister(.pktctrl0, value: 0x00)
        try updateRegister(.fsctrl1, value: 0x06)
        try updateRegister(.mdmcfg4, value: 0xCA)
        try updateRegister(.mdmcfg3, value: 0xBC)  // 0xBB for next lower bitrate
        try updateRegister(.mdmcfg2, value: 0x06)
        try updateRegister(.mdmcfg1, value: 0x70)
        try updateRegister(.mdmcfg0, value: 0x11)
        try updateRegister(.deviatn, value: 0x44)
        try updateRegister(.mcsm0, value: 0x18)
        try updateRegister(.foccfg, value: 0x17)
        try updateRegister(.fscal3, value: 0xE9)
        try updateRegister(.fscal2, value: 0x2A)
        try updateRegister(.fscal1, value: 0x00)
        try updateRegister(.fscal0, value: 0x1F)
        
        try updateRegister(.test1, value: 0x31)
        try updateRegister(.test0, value: 0x09)
        try updateRegister(.paTable0, value: 0x84)
        try updateRegister(.sync1, value: 0xA5)
        try updateRegister(.sync0, value: 0x5A)
    }
}

extension PodComms: PodCommsSessionDelegate {
    public func podCommsSession(_ podCommsSession: PodCommsSession, didChange state: PodState) {
        self.podState = state
    }
}
