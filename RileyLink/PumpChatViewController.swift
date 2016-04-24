//
//  PumpChatViewController.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/12/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit
import RileyLinkKit
import RileyLinkBLEKit


class PumpChatViewController: UIViewController {
  
  @IBOutlet var output: UITextView!
  @IBOutlet var batteryVoltage: UILabel!
  @IBOutlet var pumpIdLabel: UILabel!
  
  var pumpOps: PumpOps!
  var device: RileyLinkBLEDevice!

  override func viewDidLoad() {
    super.viewDidLoad()

    pumpIdLabel.text = "PumpID: \(Config.sharedInstance().pumpID ?? "nil")"
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    pumpOps = PumpOps(pumpState:appDelegate.pump, device:device)
  }

  override func didReceiveMemoryWarning() {
      super.didReceiveMemoryWarning()
      // Dispose of any resources that can be recreated.
  }
  
  func addOutputMessage(msg: String)
  {
    output.text = output.text.stringByAppendingFormat("%@\n", msg)
    NSLog("addOutputMessage: %@", msg)
  }
  
  @IBAction func dumpHistoryButtonPressed(sender: UIButton) {
    let calendar = NSCalendar.currentCalendar()
    let oneDayAgo = calendar.dateByAddingUnit(.Day, value: -1, toDate: NSDate(), options: [])
    pumpOps.getHistoryEventsSinceDate(oneDayAgo!) { (response) -> Void in
      switch response {
      case .Success(let (events, _)):
        for event in events {
          self.addOutputMessage(String(format:"Event: %@", event.dictionaryRepresentation))
          NSLog("Event: %@", event.dictionaryRepresentation)
        }
      case .Failure(let error):
        let errorMsg = String(format:"History fetch failed: %@", String(error))
        self.addOutputMessage(errorMsg)
      }
    }
  }
  
  @IBAction func pressDownButtonPressed(sender: UIButton) {
    pumpOps.pressButton()
  }
  
  @IBAction func queryPumpButtonPressed(sender: UIButton) {
    pumpOps.getPumpModel { (model) -> Void in
      if let model = model {
        self.addOutputMessage(String(format:"Pump Model: %@", model))
      } else {
        self.addOutputMessage("Get pump model failed.")
      }
    }
  
    pumpOps.getBatteryVoltage { (results) -> Void in
      if let results = results {
        self.addOutputMessage(String(format:"Battery Level: %@, %0.02f volts", results.status, results.volts))
      } else {
        self.addOutputMessage("Get battery voltage failed.")        
      }
    }
  }
  
  
  @IBAction func tuneButtonPressed(sender: UIButton) {
    pumpOps.tunePump { (result) -> Void in
      switch result {
      case .Success(let scanResults):
        for trial in scanResults.trials {
          self.addOutputMessage(String(format:"Trial: %0.02f - %d, %0.01f", trial.frequencyMHz, trial.successes, trial.avgRSSI))
        }
        self.addOutputMessage(String(format:"Best Freq: %0.02f", scanResults.bestFrequency))
      case .Failure(let error):
        let errorMsg = String(format:"Tune failed: %@", String(error))
        self.addOutputMessage(errorMsg)
      }
    }
  }
}
