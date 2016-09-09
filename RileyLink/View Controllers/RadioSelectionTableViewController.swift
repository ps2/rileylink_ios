//
//  RadioSelectionTableViewController.swift
//  Loop
//
//  Created by Nate Racklyeft on 8/26/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import MinimedKit


protocol RadioSelectionTableViewControllerDelegate: class {
    func radioSelectionTableViewControllerDidChangeSelectedIndex(controller: RadioSelectionTableViewController)
}


class RadioSelectionTableViewController: UITableViewController, IdentifiableClass {

    var options = [String]()

    var selectedIndex: Int? {
        didSet {
            if let oldValue = oldValue where oldValue != selectedIndex {
                tableView.cellForRowAtIndexPath(NSIndexPath(forRow: oldValue, inSection: 0))?.accessoryType = .None
            }

            if let selectedIndex = selectedIndex where oldValue != selectedIndex {
                tableView.cellForRowAtIndexPath(NSIndexPath(forRow: selectedIndex, inSection: 0))?.accessoryType = .Checkmark

                delegate?.radioSelectionTableViewControllerDidChangeSelectedIndex(self)
            }
        }
    }

    var contextHelp: String?

    weak var delegate: RadioSelectionTableViewControllerDelegate?

    convenience init() {
        self.init(style: .Grouped)
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell") ?? UITableViewCell(style: .Default, reuseIdentifier: "Cell")

        cell.textLabel?.text = options[indexPath.row]
        cell.accessoryType = selectedIndex == indexPath.row ? .Checkmark : .None

        return cell
    }

    override func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return contextHelp
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        selectedIndex = indexPath.row

        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}


extension RadioSelectionTableViewController {
    typealias T = RadioSelectionTableViewController

    static func pumpRegion(value: PumpRegion) -> T {
        let vc = T()

        vc.selectedIndex = value.rawValue
        vc.options = (0..<2).flatMap({ PumpRegion(rawValue: $0) }).map { String($0) }
        vc.contextHelp = NSLocalizedString("Pump Region is listed on the back of your pump as two of the last three characters of the model string, which reads something like this: MMT-551NAB, or MMT-515LWWS.  If your model has an \"NA\" in it, then the region is NorthAmerica.  If your model has an \"WW\" in it, then the region is WorldWide.", comment: "Instructions on selecting the pump region")
        return vc
    }
}
