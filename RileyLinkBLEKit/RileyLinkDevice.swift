//
//  RileyLinkDevice.swift
//  RileyLinkBLEKit
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import CoreBluetooth
import os.log

public enum RileyLinkHardwareType {
    case riley
    case orange
    case ema
    
    var monitorsBattery: Bool {
        return self == .orange
    }
}

/// TODO: Should we be tracking the most recent "pump" RSSI?
public class RileyLinkDevice {
    let manager: PeripheralManager

    private let log = OSLog(category: "RileyLinkDevice")

    // Confined to `manager.queue`
    private var bleFirmwareVersion: BLEFirmwareVersion?

    // Confined to `manager.queue`
    private var radioFirmwareVersion: RadioFirmwareVersion?
    
    public var rlFirmwareDescription: String {
        let versions = [radioFirmwareVersion, bleFirmwareVersion].compactMap { (version: CustomStringConvertible?) -> String? in
            if let version = version {
                return String(describing: version)
            } else {
                return nil
            }
        }

        return versions.joined(separator: " / ")
    }

    private var version: String {
        switch hardwareType {
        case .riley, .ema, .none:
            return rlFirmwareDescription
        case .orange:
            return orangeLinkFirmwareHardwareVersion
        }
    }

    // Confined to `lock`
    private var idleListeningState: IdleListeningState = .disabled

    // Confined to `lock`
    private var lastIdle: Date?
    
    // Confined to `lock`
    // TODO: Tidy up this state/preference machine
    private var isIdleListeningPending = false

    // Confined to `lock`
    private var isTimerTickEnabled = true
    
    /// Serializes access to device state
    private var lock = os_unfair_lock()
    
    private var orangeLinkFirmwareHardwareVersion = "v1.x"
    public var ledOn: Bool = false
    public var vibrationOn: Bool = false
    public var voltage: Float?
    public var batteryLevel: Int?
    
    public var hasOrangeLinkService: Bool {
        return self.manager.peripheral.services?.itemWithUUID(RileyLinkServiceUUID.orange.cbUUID) != nil
    }
    
    public var hardwareType: RileyLinkHardwareType? {
        guard let services = self.manager.peripheral.services else {
            return nil
        }
        
        if services.itemWithUUID(RileyLinkServiceUUID.secureDFU.cbUUID) != nil {
            return .orange
        } else {
            return .riley
        }
        // TODO: detect emalink
    }
    
    /// The queue used to serialize sessions and observe when they've drained
    private let sessionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.rileylink.RileyLinkBLEKit.RileyLinkDevice.sessionQueue"
        queue.maxConcurrentOperationCount = 1

        return queue
    }()

    private var sessionQueueOperationCountObserver: NSKeyValueObservation!

    init(peripheralManager: PeripheralManager) {
        self.manager = peripheralManager
        sessionQueue.underlyingQueue = peripheralManager.queue

        peripheralManager.delegate = self

        sessionQueueOperationCountObserver = sessionQueue.observe(\.operationCount, options: [.new]) { [weak self] (queue, change) in
            if let newValue = change.newValue, newValue == 0 {
                self?.log.debug("Session queue operation count is now empty")
                self?.assertIdleListening(forceRestart: true)
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
        guard case .connected = manager.peripheral.state, case .poweredOn? = manager.central?.state else {
            return
        }
        manager.peripheral.readRSSI()
    }

    public func setCustomName(_ name: String) {
        manager.setCustomName(name)
    }
    
    public func updateBatteryLevel() {
        manager.readBatteryLevel { value in
            if let batteryLevel = value {
                NotificationCenter.default.post(
                    name: .DeviceBatteryLevelUpdated,
                    object: self,
                    userInfo: [RileyLinkDevice.batteryLevelKey: batteryLevel]
                )
                self.batteryLevel = batteryLevel
            }
        }
    }
    
    public func orangeAction(_ command: OrangeLinkCommand) {
        log.debug("orangeAction: %@", "\(command)")
        manager.orangeAction(command)
    }
    
    public func orangeSetAction(index: Int, open: Bool) {
        log.debug("orangeSetAction: %@, %@", "\(index)", "\(open)")
        manager.setAction(index: index, open: open)
    }
    
    public func orangeWritePwd() {
        log.debug("orangeWritePwd")
        manager.orangeWritePwd()
    }
    
    public func orangeClose() {
        log.debug("orangeClose")
        manager.orangeClose()
    }
    
    public func orangeReadSet() {
        log.debug("orangeReadSet")
        manager.orangeReadSet()
    }
    
    public func orangeReadVDC() {
        log.debug("orangeReadVDC")
        manager.orangeReadVDC()
    }
    
    public func findDevice() {
        log.debug("findDevice")
        manager.findDevice()
    }
    
    public func setDiagnosticeLEDModeForBLEChip(_ mode: RileyLinkLEDMode) {
        manager.setLEDMode(mode: mode)
    }
    
    public func readDiagnosticLEDModeForBLEChip(completion: @escaping (RileyLinkLEDMode?) -> Void) {
        manager.readDiagnosticLEDMode(completion: completion)
    }

    /// Asserts that the caller is currently on the session queue
    public func assertOnSessionQueue() {
        dispatchPrecondition(condition: .onQueue(manager.queue))
    }

    /// Schedules a closure to execute on the session queue after a specified time
    ///
    /// - Parameters:
    ///   - deadline: The time after which to execute
    ///   - execute: The closure to execute
    public func sessionQueueAsyncAfter(deadline: DispatchTime, execute: @escaping () -> Void) {
        manager.queue.asyncAfter(deadline: deadline, execute: execute)
    }
}


extension RileyLinkDevice: Equatable, Hashable {
    public static func ==(lhs: RileyLinkDevice, rhs: RileyLinkDevice) -> Bool {
        return lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(peripheralIdentifier)
    }
}


// MARK: - Status management
extension RileyLinkDevice {
    public struct Status {
        public let lastIdle: Date?

        public let name: String?
        
        public let version: String

        public let ledOn: Bool
        public let vibrationOn: Bool
        public let voltage: Float?
        public let battery: Int?
    }

    public func getStatus(_ completion: @escaping (_ status: Status) -> Void) {
        os_unfair_lock_lock(&lock)
        let lastIdle = self.lastIdle
        os_unfair_lock_unlock(&lock)

        self.manager.queue.async {
            completion(Status(
                lastIdle: lastIdle,
                name: self.name,
                version: self.version,
                ledOn: self.ledOn,
                vibrationOn: self.vibrationOn,
                voltage: self.voltage,
                battery: self.batteryLevel
            ))
        }
    }
}


// MARK: - Command session management
// CommandSessions are a way to serialize access to the RileyLink command/response facility.
// All commands that send data out on the RL data characteristic need to be in a command session.
// Accessing other characteristics on the RileyLink can be done without a command session.
extension RileyLinkDevice {
    public func runSession(withName name: String, _ block: @escaping (_ session: CommandSession) -> Void) {
        sessionQueue.addOperation(manager.configureAndRun({ [weak self] (manager) in
            self?.log.default("======================== %{public}@ ===========================", name)
            let bleFirmwareVersion = self?.bleFirmwareVersion
            let radioFirmwareVersion = self?.radioFirmwareVersion

            if bleFirmwareVersion == nil || radioFirmwareVersion == nil {
                self?.log.error("Running session with incomplete configuration: bleFirmwareVersion %{public}@, radioFirmwareVersion: %{public}@", String(describing: bleFirmwareVersion), String(describing: radioFirmwareVersion))
            }

            block(CommandSession(manager: manager, responseType: bleFirmwareVersion?.responseType ?? .buffered, firmwareVersion: radioFirmwareVersion ?? .unknown))
            self?.log.default("------------------------ %{public}@ ---------------------------", name)
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
        os_unfair_lock_lock(&lock)
        let oldValue = idleListeningState
        idleListeningState = state
        os_unfair_lock_unlock(&lock)

        switch (oldValue, state) {
        case (.disabled, .enabled):
            assertIdleListening(forceRestart: true)
        case (.enabled, .enabled):
            assertIdleListening(forceRestart: false)
        default:
            break
        }
    }

    public func assertIdleListening(forceRestart: Bool = false) {
        os_unfair_lock_lock(&lock)
        guard case .enabled(timeout: let timeout, channel: let channel) = self.idleListeningState else {
            os_unfair_lock_unlock(&lock)
            return
        }

        guard case .connected = self.manager.peripheral.state, case .poweredOn? = self.manager.central?.state else {
            os_unfair_lock_unlock(&lock)
            return
        }

        guard forceRestart || (self.lastIdle ?? .distantPast).timeIntervalSinceNow < -timeout else {
            os_unfair_lock_unlock(&lock)
            return
        }

        guard !self.isIdleListeningPending else {
            os_unfair_lock_unlock(&lock)
            return
        }

        self.isIdleListeningPending = true
        os_unfair_lock_unlock(&lock)

        self.manager.startIdleListening(idleTimeout: timeout, channel: channel) { (error) in
            os_unfair_lock_lock(&self.lock)
            self.isIdleListeningPending = false

            if let error = error {
                self.log.error("Unable to start idle listening: %@", String(describing: error))
                os_unfair_lock_unlock(&self.lock)
            } else {
                self.lastIdle = Date()
                self.log.debug("Started idle listening")
                os_unfair_lock_unlock(&self.lock)
                NotificationCenter.default.post(name: .DeviceDidStartIdle, object: self)
            }
        }
    }
}


// MARK: - Timer tick management
extension RileyLinkDevice {
    func setTimerTickEnabled(_ enabled: Bool) {
        os_unfair_lock_lock(&lock)
        self.isTimerTickEnabled = enabled
        os_unfair_lock_unlock(&lock)
        self.assertTimerTick()
    }

    func assertTimerTick() {
        os_unfair_lock_lock(&self.lock)
        let isTimerTickEnabled = self.isTimerTickEnabled
        os_unfair_lock_unlock(&self.lock)

        if isTimerTickEnabled != self.manager.timerTickEnabled {
            self.manager.setTimerTickEnabled(isTimerTickEnabled)
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
        log.debug("didConnect %@", peripheral)
        if case .connected = peripheral.state {
            assertIdleListening(forceRestart: false)
            assertTimerTick()
        }

        manager.centralManager(central, didConnect: peripheral)
        NotificationCenter.default.post(name: .DeviceConnectionStateDidChange, object: self)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log.debug("didDisconnectPeripheral %@", peripheral)
        NotificationCenter.default.post(name: .DeviceConnectionStateDidChange, object: self)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log.debug("didFailToConnect %@", peripheral)
        NotificationCenter.default.post(name: .DeviceConnectionStateDidChange, object: self)
    }
}


extension RileyLinkDevice: PeripheralManagerDelegate {
    func peripheralManager(_ manager: PeripheralManager, didUpdateNotificationStateFor characteristic: CBCharacteristic) {
//        switch OrangeServiceCharacteristicUUID(rawValue: characteristic.uuid.uuidString) {
//        case .orange, .orangeNotif:
//            manager.writePsw = true
//            orangeWritePwd()
//        default:
//            break
//        }
        log.debug("Did didUpdateNotificationStateFor %@", characteristic)
    }
    
    // If PeripheralManager receives a response on the data queue, without an outstanding request,
    // it will pass the update to this method, which is called on the central's queue.
    // This is how idle listen responses are handled
    func peripheralManager(_ manager: PeripheralManager, didUpdateValueFor characteristic: CBCharacteristic) {
        log.debug("Did UpdateValueFor %@", characteristic)
        switch MainServiceCharacteristicUUID(rawValue: characteristic.uuid.uuidString) {
        case .data?:
            guard let value = characteristic.value, value.count > 0 else {
                return
            }

            self.manager.queue.async {
                if let responseType = self.bleFirmwareVersion?.responseType {
                    let response: PacketResponse?

                    switch responseType {
                    case .buffered:
                        var buffer =  ResponseBuffer<PacketResponse>(endMarker: 0x00)
                        buffer.append(value)
                        response = buffer.responses.last
                    case .single:
                        response = PacketResponse(data: value)
                    }

                    if let response = response {
                        switch response.code {
                        case .commandInterrupted:
                            self.log.debug("Received commandInterrupted during idle; assuming device is still listening.")
                            return
                        case .rxTimeout, .zeroData, .invalidParam, .unknownCommand:
                            self.log.debug("Idle error received: %@", String(describing: response.code))
                        case .success:
                            if let packet = response.packet {
                                self.log.debug("Idle packet received: %@", value.hexadecimalString)
                                NotificationCenter.default.post(
                                    name: .DevicePacketReceived,
                                    object: self,
                                    userInfo: [RileyLinkDevice.notificationPacketKey: packet]
                                )
                            }
                        }
                    } else {
                        self.log.error("Unknown idle response: %@", value.hexadecimalString)
                    }
                } else {
                    self.log.error("Skipping parsing characteristic value update due to missing BLE firmware version")
                }
                self.assertIdleListening(forceRestart: true)
            }
        case .responseCount?:
            // PeripheralManager.Configuration.valueUpdateMacros is responsible for handling this response.
            break
        case .timerTick?:
            NotificationCenter.default.post(name: .DeviceTimerDidTick, object: self)
            assertIdleListening(forceRestart: false)
        case .customName?, .firmwareVersion?, .ledMode?, .none:
            break
        }
        
        switch OrangeServiceCharacteristicUUID(rawValue: characteristic.uuid.uuidString) {
        case .orange, .orangeNotif:
            guard let data = characteristic.value, !data.isEmpty else { return }
            if data.first == 0xbb {
                guard let data = characteristic.value, data.count > 6 else { return }
                if data[1] == 0x09, data[2] == 0xaa {
                    orangeLinkFirmwareHardwareVersion = "FW\(data[3]).\(data[4])/HW\(data[5]).\(data[6])"
                    NotificationCenter.default.post(name: .DeviceStatusUpdated, object: self)
                }
            } else if data.first == 0xdd {
                guard let data = characteristic.value, data.count > 2 else { return }
                if data[1] == 0x01 {
                    guard let data = characteristic.value, data.count > 5 else { return }
                    ledOn = (data[3] != 0)
                    vibrationOn = (data[4] != 0)
                    NotificationCenter.default.post(name: .DeviceStatusUpdated, object: self)
                } else if data[1] == 0x03 {
                    guard var data = characteristic.value, data.count > 4 else { return }
                    data = Data(data[3...4])
                    let int = UInt16(bigEndian: data.withUnsafeBytes { $0.load(as: UInt16.self) })
                    voltage = Float(int) / 1000
                    NotificationCenter.default.post(name: .DeviceStatusUpdated, object: self)
                }
            }
        default:
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
        log.default("Reading firmware versions for PeripheralManager configuration")
        let bleVersionString = try manager.readBluetoothFirmwareVersion(timeout: 1)
        bleFirmwareVersion = BLEFirmwareVersion(versionString: bleVersionString)

        let radioVersionString = try manager.readRadioFirmwareVersion(timeout: 1, responseType: bleFirmwareVersion?.responseType ?? .buffered)
        radioFirmwareVersion = RadioFirmwareVersion(versionString: radioVersionString)
        
        try manager.setOrangeNotifyOn()
    }
}


extension RileyLinkDevice: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        os_unfair_lock_lock(&lock)
        let lastIdle = self.lastIdle
        let isIdleListeningPending = self.isIdleListeningPending
        let isTimerTickEnabled = self.isTimerTickEnabled
        os_unfair_lock_unlock(&lock)

        return [
            "## RileyLinkDevice",
            "* name: \(name ?? "")",
            "* lastIdle: \(lastIdle ?? .distantPast)",
            "* isIdleListeningPending: \(isIdleListeningPending)",
            "* isTimerTickEnabled: \(isTimerTickEnabled)",
            "* isTimerTickNotifying: \(manager.timerTickEnabled)",
            "* radioFirmware: \(String(describing: radioFirmwareVersion))",
            "* bleFirmware: \(String(describing: bleFirmwareVersion))",
            "* peripheralManager: \(manager)",
            "* sessionQueue.operationCount: \(sessionQueue.operationCount)"
        ].joined(separator: "\n")
    }
}


extension RileyLinkDevice {
    public static let notificationPacketKey = "com.rileylink.RileyLinkBLEKit.RileyLinkDevice.NotificationPacket"

    public static let notificationRSSIKey = "com.rileylink.RileyLinkBLEKit.RileyLinkDevice.NotificationRSSI"
    
    public static let batteryLevelKey = "com.rileylink.RileyLinkBLEKit.RileyLinkDevice.BatteryLevel"
}


extension Notification.Name {
    public static let DeviceConnectionStateDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.ConnectionStateDidChange")

    public static let DeviceDidStartIdle = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.DidStartIdle")

    public static let DeviceNameDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.NameDidChange")

    public static let DevicePacketReceived = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.PacketReceived")

    public static let DeviceRSSIDidChange = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.RSSIDidChange")

    public static let DeviceTimerDidTick = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.TimerTickDidChange")
    
    public static let DeviceStatusUpdated = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.DeviceStatusUpdated")

    public static let DeviceBatteryLevelUpdated = Notification.Name(rawValue: "com.rileylink.RileyLinkBLEKit.BatteryLevelUpdated")
}
