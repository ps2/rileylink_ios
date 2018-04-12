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
    func radioSelectionTableViewControllerDidChangeSelectedIndex(_ controller: RadioSelectionTableViewController)
}


class RadioSelectionTableViewController: UITableViewController, IdentifiableClass {

    var options = [String]()

    var selectedIndex: Int? {
        didSet {
            if let oldValue = oldValue , oldValue != selectedIndex {
                tableView.cellForRow(at: IndexPath(row: oldValue, section: 0))?.accessoryType = .none
            }

            if let selectedIndex = selectedIndex , oldValue != selectedIndex {
                tableView.cellForRow(at: IndexPath(row: selectedIndex, section: 0))?.accessoryType = .checkmark

                delegate?.radioSelectionTableViewControllerDidChangeSelectedIndex(self)
            }
        }
    }

    var contextHelp: String?

    weak var delegate: RadioSelectionTableViewControllerDelegate?

    convenience init() {
        self.init(style: .grouped)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: .default, reuseIdentifier: "Cell")

        cell.textLabel?.text = options[indexPath.row]
        cell.accessoryType = selectedIndex == indexPath.row ? .checkmark : .none

        return cell
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return contextHelp
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndex = indexPath.row

        tableView.deselectRow(at: indexPath, animated: true)
    }
}


extension RadioSelectionTableViewController {
    typealias T = RadioSelectionTableViewController

    static func pumpRegion(_ value: PumpRegion?) -> T {
        let vc = T()

        vc.selectedIndex = value?.rawValue
        vc.options = (0..<2).compactMap({ PumpRegion(rawValue: $0) }).map { String(describing: $0) }
        vc.contextHelp = NSLocalizedString("Pump Region is listed on the back of your pump as two of the last three characters of the model string, which reads something like this: MMT-551NAB, or MMT-515LWWS.  If your model has an \"NA\" in it, then the region is NorthAmerica.  If your model has an \"WW\" in it, then the region is WorldWide.", comment: "Instructions on selecting the pump region")
        return vc
    }
}
