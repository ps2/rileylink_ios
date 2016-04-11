//
//  RileyLinkDeviceManager.swift
//  RileyLink
//
//  Created by Nathan Racklyeft on 4/10/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation
import RileyLinkBLEKit


public class RileyLinkDeviceManager {

  public static let DidDiscoverDeviceNotification = "com.rileylink.RileyLinkKit.DidDiscoverDeviceNotification"

  public static let ConnectionStateDidChangeNotification = "com.rileylink.RileyLinkKit.ConnectionStateDidChangeNotification"

  public static let RileyLinkDeviceKey = "com.rileylink.RileyLinkKit.RileyLinkDevice"

  public enum ReadyState {
    case NeedsConfiguration
    case Ready(PumpState)
  }

  public var readyState: ReadyState

  public init(pumpState: PumpState?, autoConnectIDs: Set<String>) {

    if let pumpState = pumpState {
      readyState = .Ready(pumpState)
    } else {
      readyState = .NeedsConfiguration
    }

    self.autoConnectIDs = autoConnectIDs

    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(discoveredBLEDevice(_:)), name: RILEYLINK_EVENT_LIST_UPDATED, object: BLEManager)

    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(connectionStateDidChange(_:)), name: RILEYLINK_EVENT_DEVICE_CONNECTED, object: BLEManager)

    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(connectionStateDidChange(_:)), name: RILEYLINK_EVENT_DEVICE_DISCONNECTED, object: BLEManager)
  }

  private var autoConnectIDs: Set<String>

  public var deviceScanningEnabled: Bool {
    get {
      return BLEManager.scanningEnabled
    }
    set {
      BLEManager.scanningEnabled = newValue
    }
  }

  private var _devices: [RileyLinkDevice] = []

  public var devices: [RileyLinkDevice] {
    return _devices
  }

  public var firstConnectedDevice: RileyLinkDevice? {
    if let index = _devices.indexOf({ $0.peripheral.state == .Connected }) {
      return _devices[index]
    } else {
      return nil
    }
  }

  public func connectDevice(device: RileyLinkDevice) {
    BLEManager.connectPeripheral(device.peripheral)
  }

  public func disconnectDevice(device: RileyLinkDevice) {
    BLEManager.disconnectPeripheral(device.peripheral)
  }

  private let BLEManager = RileyLinkBLEManager()

  // MARK: - RileyLinkBLEManager

  @objc private func discoveredBLEDevice(note: NSNotification) {
    if let BLEDevice = note.userInfo?["device"] as? RileyLinkBLEDevice {
      let device = RileyLinkDevice(BLEDevice: BLEDevice)

      _devices.append(device)

      NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.DidDiscoverDeviceNotification, object: self, userInfo: [self.dynamicType.RileyLinkDeviceKey: device])

    }
  }

  @objc private func connectionStateDidChange(note: NSNotification) {
    if let BLEDevice = note.object as? RileyLinkBLEDevice,
      index = _devices.indexOf({ $0.peripheral == BLEDevice.peripheral }) {
      let device = _devices[index]

      NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.ConnectionStateDidChangeNotification, object: self, userInfo: [self.dynamicType.RileyLinkDeviceKey: device])
    }
  }

}