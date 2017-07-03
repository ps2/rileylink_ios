//
//  RileyLinkListTableViewController.swift
//  RileyLink
//
//  Created by Pete Schwamb on 5/11/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import RileyLinkKit

class RileyLinkListTableViewController: UITableViewController {
    
    // Retreive the managedObjectContext from AppDelegate
    let managedObjectContext = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
    
    override func viewDidLoad() {
      super.viewDidLoad()

        tableView.register(RileyLinkDeviceTableViewCell.nib(), forCellReuseIdentifier: RileyLinkDeviceTableViewCell.className)

        dataManagerObserver = NotificationCenter.default.addObserver(forName: nil, object: dataManager, queue: nil) { [weak self = self] (note) -> Void in
            DispatchQueue.main.async {
                if let deviceManager = self?.dataManager.rileyLinkManager {
                    switch note.name {
                    case Notification.Name.DeviceManagerDidDiscoverDevice:
                        self?.tableView.insertRows(at: [IndexPath(row: deviceManager.devices.count - 1, section: 0)], with: .automatic)
                    case Notification.Name.DeviceConnectionStateDidChange,
                         Notification.Name.DeviceRSSIDidChange,
                         Notification.Name.DeviceNameDidChange:
                        if let device = note.userInfo?[RileyLinkDeviceManager.RileyLinkDeviceKey] as? RileyLinkDevice, let index = deviceManager.devices.index(where: { $0 === device }) {
                            self?.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
    
    deinit {
        dataManagerObserver = nil
    }
    
    private var dataManagerObserver: Any? {
        willSet {
            if let observer = dataManagerObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    private var dataManager: DeviceDataManager {
        return DeviceDataManager.sharedManager
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        dataManager.rileyLinkManager.setDeviceScanningEnabled(true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        dataManager.rileyLinkManager.setDeviceScanningEnabled(false)
    }
    
    // MARK: Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataManager.rileyLinkManager.devices.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        let deviceCell = tableView.dequeueReusableCell(withIdentifier: RileyLinkDeviceTableViewCell.className) as! RileyLinkDeviceTableViewCell
        
        let device = dataManager.rileyLinkManager.devices[indexPath.row]
        
        deviceCell.configureCellWithName(device.name,
                                         signal: device.RSSI,
                                         peripheralState: device.peripheral.state
        )
        
        deviceCell.connectSwitch.addTarget(self, action: #selector(deviceConnectionChanged(_:)), for: .valueChanged)
        
        cell = deviceCell
        return cell
    }
    
    func deviceConnectionChanged(_ connectSwitch: UISwitch) {
        let switchOrigin = connectSwitch.convert(CGPoint.zero, to: tableView)
        
        if let indexPath = tableView.indexPathForRow(at: switchOrigin)
        {
            let device = dataManager.rileyLinkManager.devices[indexPath.row]
            
            if connectSwitch.isOn {
                dataManager.connectToRileyLink(device)
            } else {
                dataManager.disconnectFromRileyLink(device)
            }
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = RileyLinkDeviceTableViewController()

        vc.device = dataManager.rileyLinkManager.devices[indexPath.row]

        show(vc, sender: indexPath)
    }
    
    /*
     // Override to support conditional editing of the table view.
     - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
     // Return NO if you do not want the specified item to be editable.
     return YES;
     }
     */
    
    /*
     // Override to support editing the table view.
     - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
     if (editingStyle == UITableViewCellEditingStyleDelete) {
     // Delete the row from the data source
     [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
     } else if (editingStyle == UITableViewCellEditingStyleInsert) {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */
    
    /*
     // Override to support rearranging the table view.
     - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
     }
     */
    
    /*
     // Override to support conditional rearranging of the table view.
     - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
     // Return NO if you do not want the item to be re-orderable.
     return YES;
     }
     */

}
