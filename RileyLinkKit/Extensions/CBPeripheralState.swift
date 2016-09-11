//
//  CBPeripheralState.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/5/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import CoreBluetooth


extension CBPeripheralState {

    // MARK: - CustomStringConvertible

    var description: String {
        switch self {
        case .connected:
            return NSLocalizedString("Connected", comment: "The connected state")
        case .connecting:
            return NSLocalizedString("Connecting", comment: "The in-progress connecting state")
        case .disconnected:
            return NSLocalizedString("Disconnected", comment: "The disconnected state")
        case .disconnecting:
            return NSLocalizedString("Disconnecting", comment: "The in-progress disconnecting state")
        }
    }
}
