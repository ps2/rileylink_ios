//
//  TextFieldTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 8/30/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import UIKit


internal protocol TextFieldTableViewControllerDelegate: class {
    func textFieldTableViewControllerDidEndEditing(controller: TextFieldTableViewController)

    func textFieldTableViewControllerDidReturn(controller: TextFieldTableViewController)
}


internal class TextFieldTableViewController: UITableViewController, UITextFieldDelegate {

    private weak var textField: UITextField?

    internal var indexPath: NSIndexPath?

    internal var placeholder: String?

    internal var value: String? {
        didSet {
            delegate?.textFieldTableViewControllerDidEndEditing(self)
        }
    }

    internal var keyboardType = UIKeyboardType.Default

    internal weak var delegate: TextFieldTableViewControllerDelegate?

    internal convenience init() {
        self.init(style: .Grouped)
    }

    internal override func viewDidLoad() {
        super.viewDidLoad()

        tableView.registerNib(TextFieldTableViewCell.nib(), forCellReuseIdentifier: TextFieldTableViewCell.className)
    }

    internal override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        textField?.becomeFirstResponder()
    }

    // MARK: - UITableViewDataSource

    internal override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    internal override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(TextFieldTableViewCell.className, forIndexPath: indexPath) as! TextFieldTableViewCell

        textField = cell.textField

        cell.textField.delegate = self
        cell.textField.text = value
        cell.textField.keyboardType = keyboardType
        cell.textField.placeholder = placeholder

        return cell
    }

    // MARK: - UITextFieldDelegate

    internal func textFieldShouldEndEditing(textField: UITextField) -> Bool {
        value = textField.text

        return true
    }

    internal func textFieldShouldReturn(textField: UITextField) -> Bool {
        value = textField.text

        textField.delegate = nil
        delegate?.textFieldTableViewControllerDidReturn(self)

        return false
    }
}
