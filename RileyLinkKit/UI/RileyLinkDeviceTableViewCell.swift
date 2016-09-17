//
//  RileyLinkDeviceTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 8/29/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import CoreBluetooth
import UIKit

public class RileyLinkDeviceTableViewCell: UITableViewCell {
    
    @IBOutlet public weak var connectSwitch: UISwitch!
    
    @IBOutlet weak var nameLabel: UILabel!
    
    @IBOutlet weak var signalLabel: UILabel!

    public static func nib() -> UINib {
        return UINib(nibName: className, bundle: Bundle(for: self))
    }

    public func configureCellWithName(_ name: String?, signal: Int?, peripheralState: CBPeripheralState?) {
        nameLabel.text = name
        signalLabel.text = signal != nil ? "\(signal!) dB" : nil
        
        if let state = peripheralState {
            switch state {
            case .connected:
                connectSwitch.isOn = true
                connectSwitch.isEnabled = true
            case .connecting:
                connectSwitch.isOn = true
                connectSwitch.isEnabled = true
            case .disconnected:
                connectSwitch.isOn = false
                connectSwitch.isEnabled = true
            case .disconnecting:
                connectSwitch.isOn = false
                connectSwitch.isEnabled = false
            }
        } else {
            connectSwitch.isHidden = true
        }
        
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        
        connectSwitch?.removeTarget(nil, action: nil, for: .valueChanged)
    }
    
}


