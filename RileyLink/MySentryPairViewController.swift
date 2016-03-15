//
//  MySentryPairViewController.swift
//  RileyLink
//
//  Created by Pete Schwamb on 2/29/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import MinimedKit

class MySentryPairViewController: UIViewController, UITextFieldDelegate {
  
  enum PairingState {
    case Complete
    case NeedsConfig
    case Ready
    case Started
    case ReceivedFindPacket
    case ReceivedLinkPacket
  }
  
  var device: RileyLinkBLEDevice!
  var wasDismissed = false
 
  @IBOutlet var instructionLabel: UILabel!
  @IBOutlet var deviceIDTextField: UITextField!
  @IBOutlet var startButton: UIButton!
  @IBOutlet var progressView: UIProgressView!
  
  lazy var flailGestureRecognizer: UITapGestureRecognizer = {
    let r = UITapGestureRecognizer.init(target: self, action: Selector("closeKeyboard:"))
    r.cancelsTouchesInView = false;
    r.enabled = false;
    return r
  }()

  var sendCounter: UInt8 = 0
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    deviceIDTextField.text = (device.peripheral.identifier.UUIDString as NSString).substringToIndex(6);
    deviceIDTextField.delegate = self
    
    view.addGestureRecognizer(flailGestureRecognizer)

    textFieldDidEndEditing(deviceIDTextField)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  override func viewDidDisappear(animated: Bool) {
    wasDismissed = true
  }

  
  // MARK: - UITextFieldDelegate
  
  func textFieldDidBeginEditing(textField: UITextField) {
    flailGestureRecognizer.enabled = true
  }
  
  func textFieldDidEndEditing(textField: UITextField) {
    flailGestureRecognizer.enabled = false
  
    if textField.text?.characters.count == 6 {
      state = .Ready
    } else if .Ready == self.state {
      state = .NeedsConfig
    }
  }
  
  func textField(textField: UITextField,
    shouldChangeCharactersInRange range: NSRange,
    replacementString string: String) -> Bool {
      let newString = (textField.text! as NSString).stringByReplacingCharactersInRange(range, withString:string)
      
      if newString.characters.count > 6 {
        return false
      } else if newString.characters.count == 6 {
        textField.text = newString
        textField.resignFirstResponder()
        return false
      } else if .Ready == self.state {
        state = .NeedsConfig
      }
      
      return true
  }
  
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    return true
  }

  // MARK: - Other
  
  func listenForPairing() {
    if wasDismissed {
      return
    }
    
    let cmd = GetPacketCmd()
    cmd.listenChannel = 0;
    cmd.timeoutMS = 30000;
    runCommand(cmd)
  }
  
  var state: PairingState = .NeedsConfig {
    didSet {
      if (oldValue == state) {
        return
      }
      switch state {
      case .NeedsConfig:
        startButton.enabled = false
        startButton.hidden = true
        instructionLabel.text = NSLocalizedString(
          "Enter a 6-digit numeric value to identify your MySentry.",
          comment: "Device ID instruction")
        instructionLabel.hidden = false
      case .Ready:
        startButton.enabled = true
        startButton.hidden = false
        progressView.progress = 0
        
        instructionLabel.hidden = true
      case .Started:
        startButton.enabled = false
        startButton.hidden = true
        deviceIDTextField.enabled = false
        progressView.setProgress(1.0 / 4.0, animated:true)
        
        instructionLabel.text = NSLocalizedString(
          "On your pump, go to the Find Device screen and select \"Find Device\"." +
            "\n" +
            "\nMain Menu >" +
            "\nUtilities >" +
            "\nConnect Devices >" +
            "\nOther Devices >" +
            "\nOn >" +
          "\nFind Device",
          comment: "Pump find device instruction")
        instructionLabel.hidden = false
      case .ReceivedFindPacket:
        progressView.setProgress(2.0 / 4.0, animated:true)
        
        instructionLabel.text = NSLocalizedString(
          "Pairing in process, please wait.",
          comment: "Pairing waiting instruction")
      case .ReceivedLinkPacket:
        progressView.setProgress(3.0 / 4.0, animated:true)
        instructionLabel.text = NSLocalizedString(
          "Pump accepted pairing. " +
            "Waiting for MySentry update from pump. " +
          "This could take up to five minutes...",
          comment: "Pairing waiting instruction")
      case .Complete:
        progressView.setProgress(4.0 / 4.0, animated:true)
        
        instructionLabel.text = NSLocalizedString(
          "Congratulations! Pairing is complete.",
          comment: "Pairing waiting instruction")
      }
    }
  }

  // MARK: - Actions
  
  func packetReceived(packet: RFPacket) {
  
    var handled = false
  
    if let data = packet.data, msg = PumpMessage.init(rxData: data) {
      if msg.packetType == PacketType.MySentry &&
        msg.address.hexadecimalString == Config.sharedInstance().pumpID {
          switch (msg.messageType) {
          case MessageType.FindDevice:
            handleFindDevice(msg.messageBody as! FindDeviceMessageBody)
            handled = true
          case MessageType.DeviceLink:
            handleDeviceLink(msg.messageBody as! DeviceLinkMessageBody)
            handled = true
          case MessageType.PumpStatus:
            handlePumpStatus(msg.messageBody as! MySentryPumpStatusMessageBody)
            handled = true
          default:
            NSLog("Unexpected packet received: " + String(msg.messageType))
          }
      }
    }
    if (!handled && .Complete != self.state) {
      // Other random packet; ignore and start listening again.
      performSelector(Selector("listenForPairing"), withObject:nil, afterDelay:0)
    }
  }
  
  func makeCommandForAckAndListen(sequence: UInt8, messageType: MessageType) -> ReceivingPacketCmd {
    let replyString = String(format: "%02x%@%02x%02x%@00%02x000000",
      PacketType.MySentry.rawValue,
      Config.sharedInstance().pumpID,
      MessageType.PumpAck.rawValue,
      sequence,
      self.deviceIDTextField.text!,
      messageType.rawValue)
    let data = NSData.init(hexadecimalString: replyString)
    let send = SendAndListenCmd()
    send.sendChannel = 0
    send.timeoutMS = 180
    send.listenChannel = 0
    send.packet = RFPacket(data: data!)
    return send;
  }
  
  func runCommand(cmd: ReceivingPacketCmd) {
    device.runSession {
      (session: RileyLinkCmdSession) -> Void in
      if (session.doCmd(cmd, withTimeoutMs: 31000)) {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
          let rxPacket = cmd.receivedPacket
          self.packetReceived(rxPacket)
        })
      } else {
        // Timed out. Try again
        self.performSelector(Selector("listenForPairing"), withObject:nil, afterDelay:0)
      }
    }
  }

  func handleFindDevice(msg: FindDeviceMessageBody) {
    if .Started == self.state {
      self.state = .ReceivedFindPacket
    }
  
    let cmd = makeCommandForAckAndListen(msg.sequence, messageType: MessageType.FindDevice)
    runCommand(cmd)
  }
  
  func handleDeviceLink(msg: DeviceLinkMessageBody) {
    if .ReceivedFindPacket == self.state {
      self.state = .ReceivedLinkPacket
    }
  
    let cmd = makeCommandForAckAndListen(msg.sequence, messageType: MessageType.DeviceLink)
    runCommand(cmd)
  }
  
  func handlePumpStatus(msg: MySentryPumpStatusMessageBody) {
    if .ReceivedLinkPacket == self.state {
      self.state = .Complete;
    }
    let cmd = makeCommandForAckAndListen(0, messageType: MessageType.PumpStatus)
    runCommand(cmd)
  }

  func closeKeyboard(recognizer: UITapGestureRecognizer) {
    self.view.endEditing(true)
  }
  
  @IBAction func startPairing(sender: UIButton) {
    if (.Ready == self.state) {
      self.state = .Started
      listenForPairing()
    }
  }


  
  /*
  // MARK: - Navigation
  
  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
  // Get the new view controller using segue.destinationViewController.
  // Pass the selected object to the new view controller.
  }
  */
  
}
