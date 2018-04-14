//
//  RileyLinkListTableViewController.swift
//  RileyLink
//
//  Created by Pete Schwamb on 5/11/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import RileyLinkBLEKit
import RileyLinkKit
import RileyLinkKitUI


class RileyLinkListTableViewController: UITableViewController {

    private lazy var numberFormatter = NumberFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(RileyLinkDeviceTableViewCell.self, forCellReuseIdentifier: RileyLinkDeviceTableViewCell.className)

        // Register for manager notifications
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDevices), name: .ManagerDevicesDidChange, object: dataManager.rileyLinkManager)

        // Register for device notifications
        for name in [.DeviceConnectionStateDidChange, .DeviceRSSIDidChange, .DeviceNameDidChange] as [Notification.Name] {
            NotificationCenter.default.addObserver(self, selector: #selector(deviceDidUpdate(_:)), name: name, object: nil)
        }

        reloadDevices()
    }

    @objc private func reloadDevices() {
        self.dataManager.rileyLinkManager.getDevices { (devices) in
            DispatchQueue.main.async {
                self.devices = devices
            }
        }
    }

    @objc private func deviceDidUpdate(_ note: Notification) {
        DispatchQueue.main.async {
            if let device = note.object as? RileyLinkDevice, let index = self.devices.index(where: { $0 === device }) {
                if let rssi = note.userInfo?[RileyLinkDevice.notificationRSSIKey] as? Int {
                    self.deviceRSSI[device.peripheralIdentifier] = rssi
                }

                if let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? RileyLinkDeviceTableViewCell {
                    cell.configureCellWithName(device.name,
                        signal: self.numberFormatter.decibleString(from: self.deviceRSSI[device.peripheralIdentifier]),
                        peripheralState: device.peripheralState
                    )
                }
            }
        }
    }

    private var dataManager: DeviceDataManager {
        return DeviceDataManager.sharedManager
    }

    private var devices: [RileyLinkDevice] = [] {
        didSet {
            // Assume only appends are possible when count changes for algorithmic simplicity
            guard oldValue.count < devices.count else {
                tableView.reloadSections(IndexSet(integer: 0), with: .fade)
                return
            }

            tableView.beginUpdates()

            let insertedPaths = (oldValue.count..<devices.count).map { (index) -> IndexPath in
                return IndexPath(row: index, section: 0)
            }
            tableView.insertRows(at: insertedPaths, with: .automatic)

            tableView.endUpdates()
        }
    }

    private var deviceRSSI: [UUID: Int] = [:]

    var rssiFetchTimer: Timer? {
        willSet {
            rssiFetchTimer?.invalidate()
        }
    }

    @objc func updateRSSI() {
        for device in devices {
            device.readRSSI()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        dataManager.rileyLinkManager.setScanningEnabled(true)

        rssiFetchTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(updateRSSI), userInfo: nil, repeats: true)

        updateRSSI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        dataManager.rileyLinkManager.setScanningEnabled(false)

        rssiFetchTimer = nil
    }
    
    // MARK: Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        let deviceCell = tableView.dequeueReusableCell(withIdentifier: RileyLinkDeviceTableViewCell.className) as! RileyLinkDeviceTableViewCell
        
        let device = devices[indexPath.row]
        
        deviceCell.configureCellWithName(
            device.name,
            signal: numberFormatter.decibleString(from: deviceRSSI[device.peripheralIdentifier]),
            peripheralState: device.peripheralState
        )
        
        deviceCell.connectSwitch?.addTarget(self, action: #selector(changeDeviceConnection(_:)), for: .valueChanged)
        
        cell = deviceCell
        return cell
    }
    
    @objc func changeDeviceConnection(_ connectSwitch: UISwitch) {
        let switchOrigin = connectSwitch.convert(CGPoint.zero, to: tableView)
        
        if let indexPath = tableView.indexPathForRow(at: switchOrigin) {
            let device = devices[indexPath.row]
            
            if connectSwitch.isOn {
                dataManager.connectToRileyLink(device)
            } else {
                dataManager.disconnectFromRileyLink(device)
            }
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = devices[indexPath.row]
        let vc = RileyLinkDeviceTableViewController(
            device: device,
            deviceState: dataManager.deviceStates[device.peripheralIdentifier, default: DeviceState()],
            pumpSettings: dataManager.pumpSettings,
            pumpState: dataManager.pumpState,
            pumpOps: dataManager.pumpOps
        )

        show(vc, sender: indexPath)
    }
}
