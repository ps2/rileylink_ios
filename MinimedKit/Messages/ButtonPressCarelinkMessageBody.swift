//
//  ButtonPressCarelinkMessageBody.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/12/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class ButtonPressCarelinkMessageBody: CarelinkLongMessageBody {
    
    public enum ButtonType: UInt8 {
        case Act = 0x02
        case Esc = 0x01
        case Down = 0x04
        case Up = 0x03
        case Easy = 0x00
    }
    
    public convenience init(buttonType: ButtonType) {
        let numArgs = 1
        let data = NSData(hexadecimalString: String(format: "%02x%02x", numArgs, buttonType.rawValue))!
        
        self.init(rxData: data)!
    }
    
}