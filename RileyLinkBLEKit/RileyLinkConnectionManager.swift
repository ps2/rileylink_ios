//
//  RileyLinkConnectionManager.swift
//  RileyLinkBLEKit
//
//  Created by Pete Schwamb on 8/16/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public protocol RileyLinkConnectionManagerDelegate {
    func rileyLinkConnectionManagerDidUpdateState(_ rileyLinkConnectionManager: RileyLinkConnectionManager)
}

public class RileyLinkConnectionManager {
    
    public typealias RawStateValue = [String : Any]
    
    /// The current, serializable state of the manager
    public var rawState: RawStateValue {
        return [
            "autoConnectIDs": Array(autoConnectIDs)
        ]
    }
    
    public var deviceProvider: RileyLinkDeviceProvider {
        return rileyLinkDeviceManager
    }
    
    public var delegate: RileyLinkConnectionManagerDelegate?
    
    private let rileyLinkDeviceManager: RileyLinkDeviceManager
    private var autoConnectIDs: Set<String> {
        didSet {
            delegate?.rileyLinkConnectionManagerDidUpdateState(self)
        }
    }
    
    public init(autoConnectIDs: Set<String>) {
        self.rileyLinkDeviceManager = RileyLinkDeviceManager(autoConnectIDs: autoConnectIDs)
        self.autoConnectIDs = autoConnectIDs
    }
    
    public convenience init?(rawValue: RawStateValue) {
        guard let autoConnectIDs = rawValue["autoConnectIDs"] as? [String] else {
            return nil
        }
        self.init(autoConnectIDs: Set(autoConnectIDs))
    }
    
    public var connectingCount: Int {
        return self.autoConnectIDs.count
    }
    
    public func shouldConnectTo(_ deviceID: String) -> Bool {
        return self.autoConnectIDs.contains(deviceID)
    }
    
    public func connect(_ device: RileyLinkDevice) {
        autoConnectIDs.insert(device.peripheralIdentifier.uuidString)
        rileyLinkDeviceManager.connect(device)
    }
    
    public func disconnect(_ device: RileyLinkDevice) {
        autoConnectIDs.remove(device.peripheralIdentifier.uuidString)
        rileyLinkDeviceManager.disconnect(device)
    }

    public func setScanningEnabled(_ enabled: Bool) {
        rileyLinkDeviceManager.setScanningEnabled(enabled)
    }
}

public protocol RileyLinkDeviceProvider: class {
    func getDevices(_ completion: @escaping (_ devices: [RileyLinkDevice]) -> Void)
    var idleListeningEnabled: Bool { get }
    var timerTickEnabled: Bool { get set }
    func deprioritize(_ device: RileyLinkDevice, _ completion: (() -> Void)?)
    func assertIdleListening(forcingRestart: Bool)
    var idleListeningState: RileyLinkDevice.IdleListeningState { get set }

    var debugDescription: String { get }
}

extension RileyLinkDeviceManager: RileyLinkDeviceProvider {}
