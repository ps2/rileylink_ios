//
//  BeepType.swift
//  OmniKit
//
//  Created by Joseph Moran on 5/12/19.
//  Copyright © 2019 Pete Schwamb. All rights reserved.
//

import Foundation

// BeepType is used for the $11 Acknowledge Alerts, $19 Configure Alerts, $1E Beep Configure, and $1F Cancel Commands
public enum BeepType: UInt8 {
    case noBeep = 0x0
    case beepBeepBeepBeep = 0x1
    case bipBeepBipBeepBipBeepBipBeep = 0x2
    case bipBip = 0x3
    case beep = 0x4
    case beepBeepBeep = 0x5
    case beeeeeep = 0x6
    case bipBipBipbipBipBip = 0x7
    case beeepBeeep = 0x8
    // 0x9 and 0xA always return an error
    case beepBeep = 0xB
    case beeep = 0xC
    case bipBeeeeep = 0xD
    case fiveSecondBeep = 0xE    // 5 second alarm beep *if* Pod is currently suspended
    case beepConfig_NoBeep = 0xF // For Beep Config Command no beep, else fatal Pod fault $37
}
