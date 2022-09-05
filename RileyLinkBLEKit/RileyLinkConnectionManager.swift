//
//  RileyLinkConnectionManager.swift
//  RileyLinkBLEKit
//
//  Created by Pete Schwamb on 8/16/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public protocol RileyLinkConnectionManagerDelegate : AnyObject {
    func rileyLinkConnectionManager(_ rileyLinkConnectionManager: RileyLinkConnectionManager, didChange state: RileyLinkConnectionManagerState)
}

public class RileyLinkConnectionManager {
    
    public typealias RawStateValue = [String : Any]

    /// The current, serializable state of the manager
    public var rawState: RawStateValue {
        return state.rawValue
    }
    
    public private(set) var state: RileyLinkConnectionManagerState {
        didSet {
            delegate?.rileyLinkConnectionManager(self, didChange: state)
        }
    }

    public private(set) var deviceProvider: RileyLinkDeviceProvider
    
    public weak var delegate: RileyLinkConnectionManagerDelegate?
    
    private var autoConnectIDs: Set<String> {
        get {
            return state.autoConnectIDs
        }
        set {
            state.autoConnectIDs = newValue
        }
    }
    
    public init(state: RileyLinkConnectionManagerState) {
        self.deviceProvider = RileyLinkDeviceManager(autoConnectIDs: state.autoConnectIDs)
        self.state = state
    }
    
    public init() {
        self.deviceProvider = RileyLinkDeviceManager(autoConnectIDs: [])
        self.state = RileyLinkConnectionManagerState(autoConnectIDs: [])
    }
    
    public convenience init?(rawValue: RawStateValue) {
        if let state = RileyLinkConnectionManagerState(rawValue: rawValue) {
            self.init(state: state)
        } else {
            return nil
        }
    }
    
    public var connectingCount: Int {
        return self.autoConnectIDs.count
    }
    
    public func shouldConnect(to deviceID: String) -> Bool {
        return self.autoConnectIDs.contains(deviceID)
    }
    
    public func connect(_ device: RileyLinkDevice) {
        autoConnectIDs.insert(device.peripheralIdentifier.uuidString)
        deviceProvider.connect(device)
    }
    
    public func disconnect(_ device: RileyLinkDevice) {
        autoConnectIDs.remove(device.peripheralIdentifier.uuidString)
        deviceProvider.disconnect(device)
    }

    public func setScanningEnabled(_ enabled: Bool) {
        deviceProvider.setScanningEnabled(enabled)
    }
}

public protocol RileyLinkDeviceProvider: AnyObject {
    var idleListeningState: RileyLinkBluetoothDevice.IdleListeningState { get set }
    var idleListeningEnabled: Bool { get }
    var timerTickEnabled: Bool { get set }

    func deprioritize(_ device: RileyLinkDevice, completion: (() -> Void)?)
    func assertIdleListening(forcingRestart: Bool)
    func getDevices(_ completion: @escaping (_ devices: [RileyLinkDevice]) -> Void)
    func connect(_ device: RileyLinkDevice)
    func disconnect(_ device: RileyLinkDevice)
    func setScanningEnabled(_ enabled: Bool)

    var debugDescription: String { get }
}
