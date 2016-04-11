//
//  RileyLinkDevice.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 4/10/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreBluetooth
import RileyLinkBLEKit


public class RileyLinkDevice {

  private var device: RileyLinkBLEDevice

  public var peripheral: CBPeripheral {
    return device.peripheral
  }

  internal init(BLEDevice: RileyLinkBLEDevice) {
    self.device = BLEDevice
  }

}
