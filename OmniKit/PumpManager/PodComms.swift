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

protocol PodCommsDelegate: class {
    func podComms(_ podComms: PodComms, didChange podState: PodState)
}

class PodComms : CustomDebugStringConvertible {
    
    private var configuredDevices: Set<RileyLinkDevice> = Set()
    
    weak var delegate: PodCommsDelegate?
    
    weak var messageLogger: MessageLogger?

    private let sessionQueue = DispatchQueue(label: "com.rileylink.OmniKit.PodComms", qos: .utility)

    public let log = OSLog(category: "PodComms")
    
    private var podState: PodState? {
        didSet {
            if let podState = podState {
                self.delegate?.podComms(self, didChange: podState)
            }
        }
    }
    
    init(podState: PodState?) {
        self.podState = podState
        self.delegate = nil
        self.messageLogger = nil
    }
    
    
    // This is just a testing function for spoofing PDM packets, or other times when you need to generate a custom packet
    private func sendPacket(session: CommandSession) throws {
        
        let packetNumber = 19
        let messageNumber = 0x24 >> 2
        let address: UInt32 = 0x1f0b3554
        
        let cmd = GetStatusCommand(podInfoType: .normal)
        
        let message = Message(address: address, messageBlocks: [cmd], sequenceNum: messageNumber)

        var dataRemaining = message.encoded()

        let sendPacket = Packet(address: address, packetType: .pdm, sequenceNum: packetNumber, data: dataRemaining)
        dataRemaining = dataRemaining.subdata(in: sendPacket.data.count..<dataRemaining.count)
        
        let _ = try session.sendAndListen(sendPacket.encoded(), repeatCount: 0, timeout: .milliseconds(333), retryCount: 0, preambleExtension: .milliseconds(127))
        
        throw PodCommsError.emptyResponse
    }

    
    private func assignAddress(commandSession: CommandSession) throws {
        
        // Testing
        //try sendPacket(session: commandSession)
        
        let messageTransportState = MessageTransportState(packetNumber: 0, messageNumber: 0)
        
        // Create random address with 20 bits.  Can we use all 24 bits?
        let address = 0x1f000000 | (arc4random() & 0x000fffff)
        
        let transport = PodMessageTransport(session: commandSession, address: 0xffffffff, ackAddress: address, state: messageTransportState)
        transport.messageLogger = messageLogger
        
        // Assign Address
        let assignAddress = AssignAddressCommand(address: address)
        
        let message = Message(address: 0xffffffff, messageBlocks: [assignAddress], sequenceNum: transport.messageNumber)
        
        let response = try transport.sendMessage(message)

        if let fault = response.fault {
            self.log.error("Pod Fault: %@", String(describing: fault))
            throw PodCommsError.podFault(fault: fault)
        }
        
        guard let config = response.messageBlocks[0] as? VersionResponse else {
            let responseType = response.messageBlocks[0].blockType
            throw PodCommsError.unexpectedResponse(response: responseType)
        }
        
        // Pairing state should be addressAssigned
        self.podState = PodState(
            address: address,
            piVersion: String(describing: config.piVersion),
            pmVersion: String(describing: config.pmVersion),
            lot: config.lot,
            tid: config.tid
        )
    }
    
    private func configurePod(podState: PodState, timeZone: TimeZone, commandSession: CommandSession) throws {
        
        let transport = PodMessageTransport(session: commandSession, address: 0xffffffff, ackAddress: podState.address, state: podState.messageTransportState)
        transport.messageLogger = messageLogger
        
        let dateComponents = ConfigurePodCommand.dateComponents(date: Date(), timeZone: timeZone)
        let setupPod = ConfigurePodCommand(address: podState.address, dateComponents: dateComponents, lot: podState.lot, tid: podState.tid)
        
        let message = Message(address: 0xffffffff, messageBlocks: [setupPod], sequenceNum: transport.messageNumber)

        let response: Message
        do {
            response = try transport.sendMessage(message)
        } catch let error {
            if case PodCommsError.podAckedInsteadOfReturningResponse = error {
                // Pod alread configured...
                self.podState?.setupProgress = .podConfigured
                return
            }
            throw error
        }

        if let fault = response.fault {
            self.log.error("Pod Fault: %@", String(describing: fault))
            throw PodCommsError.podFault(fault: fault)
        }

        guard let config = response.messageBlocks[0] as? VersionResponse else {
            let responseType = response.messageBlocks[0].blockType
            throw PodCommsError.unexpectedResponse(response: responseType)
        }

        self.podState?.setupProgress = .podConfigured
        
        guard config.setupState == .paired else {
            throw PodCommsError.invalidData
        }
    }
    
    func pair(using deviceSelector: @escaping (_ completion: @escaping (_ device: RileyLinkDevice?) -> Void) -> Void, timeZone: TimeZone, messageLogger: MessageLogger?, completion: @escaping (Error?) -> Void)
    {
        deviceSelector { (device) in
            guard let device = device else {
                completion(PodCommsError.noRileyLinkAvailable)
                return
            }

            device.runSession(withName: "Pair Pod") { (commandSession) in
                do {
                    self.configureDevice(device, with: commandSession)
                    
                    if self.podState == nil {
                        try self.assignAddress(commandSession: commandSession)
                    }
                    
                    guard let podState = self.podState else {
                        completion(PodCommsError.noPodPaired)
                        return
                    }
                    
                    try self.configurePod(podState: podState, timeZone: timeZone, commandSession: commandSession)

                    completion(nil)
                } catch let error {
                    completion(error)
                }
            }
        }
    }
    
    enum SessionRunResult {
        case success(session: PodCommsSession)
        case failure(PodCommsError)
    }
    
    // Synchronous
    func runSession(withName name: String, using deviceSelector: @escaping (_ completion: @escaping (_ device: RileyLinkDevice?) -> Void) -> Void, _ block: @escaping (_ result: SessionRunResult) -> Void) {
        
        let semaphore = DispatchSemaphore(value: 0)
        sessionQueue.async {
            guard let podState = self.podState else {
                block(.failure(PodCommsError.noPodPaired))
                semaphore.signal()
                return
            }
            
            deviceSelector { (device) in
                guard let device = device else {
                    block(.failure(PodCommsError.noRileyLinkAvailable))
                    semaphore.signal()
                    return
                }
            
                device.runSession(withName: name) { (commandSession) in
                    self.configureDevice(device, with: commandSession)
                    let transport = PodMessageTransport(session: commandSession, address: podState.address, state: podState.messageTransportState)
                    transport.messageLogger = self.messageLogger
                    let podSession = PodCommsSession(podState: podState, transport: transport, delegate: self)
                    block(.success(session: podSession))
                    semaphore.signal()
                }
            }
        }
        semaphore.wait()
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
    
    // MARK: - CustomDebugStringConvertible
    
    var debugDescription: String {
        return [
            "## PodComms",
            "configuredDevices: \(configuredDevices.map { $0.peripheralIdentifier })",
            ""
            ].joined(separator: "\n")
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
    func podCommsSession(_ podCommsSession: PodCommsSession, didChange state: PodState) {
        self.podState = state
    }
}
