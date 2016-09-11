//
//  TextFieldTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 5/22/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

class TextFieldTableViewCell: UITableViewCell {

    @IBOutlet var textField: UITextField!

    static func nib() -> UINib {
        return UINib(nibName: className, bundle: Bundle(for: self))
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        textField.delegate = nil
    }
}
