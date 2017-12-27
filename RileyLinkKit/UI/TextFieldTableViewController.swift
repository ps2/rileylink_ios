//
//  TextFieldTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 8/30/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import UIKit


internal protocol TextFieldTableViewControllerDelegate: class {
    func textFieldTableViewControllerDidEndEditing(_ controller: TextFieldTableViewController)

    func textFieldTableViewControllerDidReturn(_ controller: TextFieldTableViewController)
}


internal class TextFieldTableViewController: UITableViewController, UITextFieldDelegate {

    private weak var textField: UITextField?

    internal var indexPath: IndexPath?

    internal var placeholder: String?

    internal var value: String? {
        didSet {
            delegate?.textFieldTableViewControllerDidEndEditing(self)
        }
    }

    internal var keyboardType = UIKeyboardType.default

    internal weak var delegate: TextFieldTableViewControllerDelegate?

    internal convenience init() {
        self.init(style: .grouped)
    }

    internal override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TextFieldTableViewCell.nib(), forCellReuseIdentifier: TextFieldTableViewCell.className)
    }

    internal override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        textField?.becomeFirstResponder()
    }

    // MARK: - UITableViewDataSource

    internal override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    internal override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldTableViewCell.className, for: indexPath) as! TextFieldTableViewCell

        textField = cell.textField

        cell.textField.delegate = self
        cell.textField.text = value
        cell.textField.keyboardType = keyboardType
        cell.textField.placeholder = placeholder
        cell.textField.autocapitalizationType = .words

        return cell
    }

    // MARK: - UITextFieldDelegate

    internal func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        value = textField.text

        return true
    }

    internal func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        value = textField.text

        textField.delegate = nil
        delegate?.textFieldTableViewControllerDidReturn(self)

        return false
    }
}
