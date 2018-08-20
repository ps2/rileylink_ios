//
//  RileyLinkPumpManager.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import RileyLinkBLEKit


open class RileyLinkPumpManager {
    public init(rileyLinkPumpManagerState: RileyLinkPumpManagerState, rileyLinkManager: RileyLinkDeviceManager? = nil) {
        lockedRileyLinkPumpManagerState = Locked(rileyLinkPumpManagerState)

        self.rileyLinkManager = rileyLinkManager ?? RileyLinkDeviceManager(autoConnectIDs: rileyLinkPumpManagerState.connectedPeripheralIDs)

        // Listen for device notifications
        NotificationCenter.default.addObserver(self, selector: #selector(receivedRileyLinkPacketNotification(_:)), name: .DevicePacketReceived, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(receivedRileyLinkTimerTickNotification(_:)), name: .DeviceTimerDidTick, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceStateDidChange(_:)), name: .DeviceStateDidChange, object: nil)
    }

    /// Manages all the RileyLinks
    public let rileyLinkManager: RileyLinkDeviceManager

    open var rileyLinkPumpManagerState: RileyLinkPumpManagerState {
        get {
            return lockedRileyLinkPumpManagerState.value
        }
        set {
            lockedRileyLinkPumpManagerState.value = newValue
        }
    }
    private let lockedRileyLinkPumpManagerState: Locked<RileyLinkPumpManagerState>

    // TODO: Eveluate if this is necessary
    public let queue = DispatchQueue(label: "com.loopkit.RileyLinkPumpManager", qos: .utility)

    /// Isolated to queue
    // TODO: Put this on each RileyLinkDevice?
    private var lastTimerTick: Date = .distantPast

    // TODO: Isolate to queue
    open var deviceStates: [UUID: DeviceState] = [:]

    /// Called when one of the connected devices receives a packet outside of a session
    ///
    /// - Parameters:
    ///   - device: The device
    ///   - packet: The received packet
    open func device(_ device: RileyLinkDevice, didReceivePacket packet: RFPacket) { }

    open func deviceTimerDidTick(_ device: RileyLinkDevice) { }

    // MARK: - CustomDebugStringConvertible
    
    open var debugDescription: String {
        return [
            "## RileyLinkPumpManager",
            "rileyLinkPumpManagerState: \(String(reflecting: rileyLinkPumpManagerState))",
            "lastTimerTick: \(String(describing: lastTimerTick))",
            "deviceStates: \(String(reflecting: deviceStates))",
            "",
            String(reflecting: rileyLinkManager),
        ].joined(separator: "\n")
    }
}


// MARK: - RileyLink Updates
extension RileyLinkPumpManager {
    @objc private func deviceStateDidChange(_ note: Notification) {
        guard
            let device = note.object as? RileyLinkDevice,
            let deviceState = note.userInfo?[RileyLinkDevice.notificationDeviceStateKey] as? RileyLinkKit.DeviceState
        else {
            return
        }

        queue.async {
            self.deviceStates[device.peripheralIdentifier] = deviceState
        }
    }

    /**
     Called when a new idle message is received by the RileyLink.

     Only MySentryPumpStatus messages are handled.

     - parameter note: The notification object
     */
    @objc private func receivedRileyLinkPacketNotification(_ note: Notification) {
        guard let device = note.object as? RileyLinkDevice,
            let packet = note.userInfo?[RileyLinkDevice.notificationPacketKey] as? RFPacket
        else {
            return
        }

        self.device(device, didReceivePacket: packet)
    }

    @objc private func receivedRileyLinkTimerTickNotification(_ note: Notification) {
        guard let device = note.object as? RileyLinkDevice else {
            return
        }

        // TODO: Do we need a queue?
        queue.async {
            self.lastTimerTick = Date()

            self.deviceTimerDidTick(device)
        }
    }

    open func connectToRileyLink(_ device: RileyLinkDevice) {
        rileyLinkPumpManagerState.connectedPeripheralIDs.insert(device.peripheralIdentifier.uuidString)
        rileyLinkManager.connect(device)
    }

    open func disconnectFromRileyLink(_ device: RileyLinkDevice) {
        rileyLinkPumpManagerState.connectedPeripheralIDs.remove(device.peripheralIdentifier.uuidString)
        rileyLinkManager.disconnect(device)
    }
}
