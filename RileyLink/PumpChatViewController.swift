//
//  PumpChatViewController.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/12/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit

class PumpChatViewController: UIViewController {
  
  @IBOutlet var output: UITextView!
  @IBOutlet var batteryVoltage: UILabel!
  @IBOutlet var pumpIdLabel: UILabel!
  
  var pumpOps: PumpOps!
  var device: RileyLinkBLEDevice!

  override func viewDidLoad() {
    super.viewDidLoad()

    pumpIdLabel.text = String(format:"PumpID: %@", Config.sharedInstance().pumpID)
    
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    pumpOps = PumpOps(pumpState:appDelegate.pump, andDevice:device)
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
    pumpOps.getHistoryPage(0) { (res: [NSObject: AnyObject]) -> Void in
      if let error = res["error"] {
        let log = String(format:"Dump of page 0 failed: %@", (error as! String))
        self.addOutputMessage(log)
      } else if let page = res["pageData"],
        let model = res["pumpModel"] {
        NSLog("Got page data: %@", (page as! NSData).hexadecimalString)
        self.decodeHistoryPage((page as! NSData), model:(model as! String))
      } else {
        NSLog("Invalid dictionary response from getHistoryPage()")
      }
    }
  }
  
  func decodeHistoryPage(data: NSData, model: String) {
    if let m = PumpModel.byModelNumber(model) {
      do {
        let page = try HistoryPage(pageData: data, pumpModel: m)
      
        for event in page.events {
          addOutputMessage(String(format:"Event: %@", event.dictionaryRepresentation))
          NSLog("Event: %@", event.dictionaryRepresentation)
        }
      } catch HistoryPage.Error.InvalidCRC {
        addOutputMessage(String(format:"CRC error in history page."))
      } catch HistoryPage.Error.UnknownEventType(let eventType) {
        addOutputMessage(String(format:"Encountered unknown event type %d", eventType))
      } catch {
        NSLog("Unexpected exception...")
      }
    }
  }
  
  @IBAction func pressDownButtonPressed(sender: UIButton) {
    pumpOps.pressButton()
  }
  
  @IBAction func queryPumpButtonPressed(sender: UIButton) {
    pumpOps.getPumpModel { (model: String?) -> Void in
      if let model = model {
        self.addOutputMessage(String(format:"Pump Model: %@", model))
      } else {
        self.addOutputMessage("Get pump model failed.")
      }
    }
  
    pumpOps.getBatteryVoltage { (results) -> Void in
      if let battery = results["status"],
        let volts = results["value"] {
          self.addOutputMessage(String(format:"Battery Level: %@, %0.02f volts", (battery as! String), (volts as! Float)))
      }
    }
  }
  
  
  @IBAction func tuneButtonPressed(sender: UIButton) {
    pumpOps.tunePump { (results) -> Void in
      self.addOutputMessage(String(format:"Tuning results: %@", results))
    }
  }
}
