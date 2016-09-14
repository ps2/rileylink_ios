//
//  TextFieldTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 8/30/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import UIKit
import RileyLinkKit

protocol TextFieldTableViewControllerDelegate: class {
    func textFieldTableViewControllerDidEndEditing(_ controller: TextFieldTableViewController)
}


class TextFieldTableViewController: UITableViewController, IdentifiableClass, UITextFieldDelegate {

    @IBOutlet weak var textField: UITextField!

    var indexPath: IndexPath?

    var placeholder: String?

    var value: String? {
        didSet {
            delegate?.textFieldTableViewControllerDidEndEditing(self)
        }
    }

    var keyboardType = UIKeyboardType.default
    var autocapitalizationType = UITextAutocapitalizationType.none

    weak var delegate: TextFieldTableViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        textField.text = value
        textField.keyboardType = keyboardType
        textField.placeholder = placeholder
        textField.autocapitalizationType = autocapitalizationType
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        textField.becomeFirstResponder()
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        value = textField.text

        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        value = textField.text

        textField.delegate = nil

        _ = navigationController?.popViewController(animated: true)

        return false
    }
}
