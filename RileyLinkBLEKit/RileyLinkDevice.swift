//
//  RileyLinkDevice.swift
//  RileyLinkBLEKit
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import CoreBluetooth
import os.log


/// TODO: Should we be tracking the most recent "pump" RSSI?
public class RileyLinkDevice {
    let manager: PeripheralManager

    private let log = OSLog(category: "RileyLinkDevice")

    // Confined to `manager.queue`
    private(set) var bleFirmwareVersion: BLEFirmwareVersion?

    // Confined to `manager.queue`
    private(set) var radioFirmwareVersion: RadioFirmwareVersion?

    // Confined to `queue`
    private var idleListeningState: IdleListeningState = .disabled {
        didSet {
            switch (oldValue, idleListeningState) {
            case (.disabled, .enabled):
                assertIdleListening(forceRestart: true)
            case (.enabled, .enabled):
                assertIdleListening(forceRestart: false)
            default:
                break
            }
        }
    }

    // Confined to `queue`
    private var lastIdle: Date?
    
    // Confined to `queue`
    // TODO: Tidy up this state/preference machine
    private var isIdleListeningPending = false

    // Confined to `queue`
    private var isTimerTickEnabled = true

    /// Serializes access to device state
    private let queue = DispatchQueue(label: "com.rileylink.RileyLinkBLEKit.RileyLinkDevice.queue", qos: .userInitiated)

    /// The queue used to serialize sessions and observe when they've drained
    private let sessionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.rileylink.RileyLinkBLEKit.RileyLinkDevice.sessionQueue"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1

        return queue
    }()

    private var sessionQueueOperationCountObserver: NSKeyValueObservation!

    init(peripheralManager: PeripheralManager) {
        self.manager = peripheralManager
        sessionQueue.underlyingQueue = peripheralManager.queue

        peripheralManager.delegate = self

        sessionQueueOperationCountObserver = sessionQueue.observe(\.operationCount) { [unowned self] (queue, change) in
            if let newValue = change.newValue, newValue == 0 {
                self.assertIdleListening(forceRestart: true)
            }
        }
    }
}


// MARK: - Peripheral operations. Thread-safe.
extension RileyLinkDevice {
    public var name: String? {
        return manager.peripheral.name
    }

    public var deviceURI: String {
        return "rileylink://\(name ?? peripheralIdentifier.uuidString)"
    }

    public var peripheralIdentifier: UUID {
        return manager.peripheral.identifier
    }

    public var peripheralState: CBPeripheralState {
        return manager.peripheral.state
    }

    public func readRSSI() {
        guard case .connected = manager.peripheral.state, case .poweredOn = manager.central.state else {
            return
        }
        manager.peripheral.readRSSI()
    }

    public func setCustomName(_ name: String) {
        manager.setCustomName(name)
    }
}


// MARK: - Status management
extension RileyLinkDevice {
    public struct Status {
        public let lastIdle: Date?

        public let name: String?

        public let bleFirmwareVersion: BLEFirmwareVersion?

        public let radioFirmwareVersion: RadioFirmwareVersion?
    }

    public func getStatus(_ completion: @escaping (_ status: Status) -> Void) {
        queue.async {
            let lastIdle = self.lastIdle

            self.manager.queue.async {
                completion(Status(
                    lastIdle: lastIdle,
                    name: self.name,
                    bleFirmwareVersion: self.bleFirmwareVersion,
                    radioFirmwareVersion: self.radioFirmwareVersion
                ))
            }
        }
    }
}


// MARK: - Command session management
extension RileyLinkDevice {
    public func runSession(withName name: String, _ block: @escaping (_ session: CommandSession) -> Void) {
        sessionQueue.addOperation(manager.configureAndRun({ [weak self] (manager) in
            self?.log.debug("======================== %{public}@ ===========================", name)
            block(CommandSession(manager: manager, responseType: self?.bleFirmwareVersion?.responseType ?? .buffered))
            self?.log.debug("------------------------ %{public}@ ---------------------------", name)
        }))
    }
}


// MARK: - Idle management
extension RileyLinkDevice {
    public enum IdleListeningState {
        case enabled(timeout: TimeInterval, channel: UInt8)
        case disabled
    }

    func setIdleListeningState(_ state: IdleListeningState) {
        queue.async {
            self.idleListeningState = state
        }
    }

    public func assertIdleListening(forceRestart: Bool = false) {
        queue.async {
            guard case .enabled(timeout: let timeout, channel: let channel) = self.idleListeningState else {
                return
            }

            guard case .connected = self.manager.peripheral.state, case .poweredOn = self.manager.central.state else {
                return
            }

            guard forceRestart || (self.lastIdle ?? .distantPast).timeIntervalSinceNow < -timeout else {
                return
            }
            
            guard !self.isIdleListeningPending else {
                return
            }
            
            self.isIdleListeningPending = true
            self.log.debug("Enqueuing idle listening")

            self.manager.startIdleListening(idleTimeout: timeout, channel: channel) { (error) in
                self.queue.async {
                    if let error = error {
                        self.log.error("Unable to start idle listening: %@", String(describing: error))
                    } else {
                        self.lastIdle = Date()
                        NotificationCenter.default.post(name: .DeviceDidStartIdle, object: self)
                    }
                    self.isIdleListeningPending = false
                }
            }
        }
    }
}


// MARK: - Timer tick management
extension RileyLinkDevice {
    func setTimerTickEnabled(_ enabled: Bool) {
        queue.async {
            self.isTimerTickEnabled = enabled
            self.assertTimerTick()
        }
    }

    func assertTimerTick() {
        queue.async {
            if self.isTimerTickEnabled != self.manager.timerTickEnabled {
                self.manager.setTimerTickEnabled(self.isTimerTickEnabled)
            }
        }
    }
}


// MARK: - CBCentralManagerDelegate Proxying
extension RileyLinkDevice {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if case .poweredOn = central.state {
            assertIdleListening(forceRestart: false)
            assertTimerTick()
        }

        manager.centralManagerDidUpdateState(central)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if case .connected = peripheral.state {
            assertIdleListening(forceRestart: false)
            assertTimerTick()
        }

        manager.centralManager(central, didConnect: peripheral)

        NotificationCenter.default.post(name: .DeviceConnectionStateDidChange, object: self)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NotificationCenter.default.post(name: .DeviceConnectionStateDidChange, object: self)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NotificationCenter.default.post(name: .DeviceConnectionStateDidChange, object: self)
    }
}


extension RileyLinkDevice: PeripheralManagerDelegate {
    // This is called from the central's queue
    func peripheralManager(_ manager: PeripheralManager, didUpdateValueFor characteristic: CBCharacteristic) {
        switch MainServiceCharacteristicUUID(rawValue: characteristic.uuid.uuidString) {
        case .data?:
            if let response = characteristic.value, response.count > 0 {
                if let packet = RFPacket(rfspyResponse: response) {
                    self.log.debug("Idle packet received: %@", response.hexadecimalString)
                    NotificationCenter.default.post(name: .DevicePacketReceived, object: self, userInfo: [RileyLinkDevice.notificationPacketKey: packet])
                } else if let error = RileyLinkResponseError(rawValue: response[0]) {
                    self.log.debug("Idle error received: %@", String(describing: error))
                }
            }

            assertIdleListening(forceRestart: true)
        case .responseCount?:
            // PeripheralManager.Configuration.valueUpdateMacros is responsible for handling this response.
            break
        case .timerTick?:
            NotificationCenter.default.post(name: .DeviceTimerDidTick, object: self)

            assertIdleListening(forceRestart: false)
        case .customName?, .firmwareVersion?, .none:
            break
        }
    }

    func peripheralManager(_ manager: PeripheralManager, didReadRSSI RSSI: NSNumber, error: Error?) {
        NotificationCenter.default.post(
            name: .DeviceRSSIDidChange,
            object: self,
            userInfo: [RileyLinkDevice.notificationRSSIKey: RSSI]
        )
    }

    func peripheralManagerDidUpdateName(_ manager: PeripheralManager) {
        NotificationCenter.default.post(
            name: .DeviceNameDidChange,
            object: self,
            userInfo: nil
        )
    }

    func completeConfiguration(for manager: PeripheralManager) throws {
        // Read bluetooth version to determine compatibility
        let bleVersionString = try manager.readBluetoothFirmwareVersion(timeout: 1)
        bleFirmwareVersion = BLEFirmwareVersion(versionString: bleVersionString)

        let radioVersionString = try manager.readRadioFirmwareVersion(timeout: 1, responseType: bleFirmwareVersion?.responseType ?? .buffered)
        radioFirmwareVersion = RadioFirmwareVersion(versionString: radioVersionString)
    }
}


extension RileyLinkDevice: CustomDebugStringConvertible {
    public var debugDescription: String {
        return [
            "## RileyLinkDevice",
            "name: \(name ?? "")",
            "lastIdle: \(lastIdle ?? .distantPast)",
            "isIdleListeningPending: \(isIdleListeningPending)",
            "isTimerTickEnabled: \(isTimerTickEnabled)",
            "isTimerTickNotifying: \(manager.timerTickEnabled)",
            "radioFirmware: \(String(describing: radioFirmwareVersion))",
            "bleFirmware: \(String(describing: bleFirmwareVersion))",
            "peripheral: \(manager.peripheral)",
            "sessionQueue.operationCount: \(sessionQueue.operationCount)"
        ].joined(separator: "\n")
    }
}


extension RileyLinkDevice {
    public static let notificationPacketKey = "com.rileylink.RileyLinkBLEKit.RileyLinkDevice.NotificationPacket"

    public static let notificationRSSIKey = "com.rileylink.RileyLinkBLEKit.RileyLinkDevice.NotificationRSSI"
}


extension Notification.Name {
    public static let DeviceConnectionStateDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.ConnectionStateDidChange")

    public static let DeviceDidStartIdle = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.DidStartIdle")

    public static let DeviceNameDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.NameDidChange")

    public static let DevicePacketReceived = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.PacketReceived")

    public static let DeviceRSSIDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.RSSIDidChange")

    public static let DeviceTimerDidTick = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.TimerTickDidChange")
}
