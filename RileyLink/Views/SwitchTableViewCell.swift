//
//  SwitchTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/13/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import RileyLinkKit

class SwitchTableViewCell: UITableViewCell, IdentifiableClass {

    @IBOutlet weak var titleLabel: UILabel!

    @IBOutlet var `switch`: UISwitch?

    override func prepareForReuse() {
        super.prepareForReuse()

        `switch`?.removeTarget(nil, action: nil, for: .valueChanged)
    }

}
