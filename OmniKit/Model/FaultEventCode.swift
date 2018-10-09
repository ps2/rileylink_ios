//
//  FaultEventCode.swift
//  OmniKit
//
//  Created by Pete Schwamb on 9/28/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation


public struct FaultEventCode: CustomStringConvertible, Equatable {
    let rawValue: UInt8
    
    public enum FaultEventType: UInt8 {
        case noFaults                             = 0x00
        case failedFlashErase                     = 0x01
        case failedFlashStore                     = 0x02
        case tableCorruptionBasalExtraCommand     = 0x03
        case corruptionByte720                    = 0x05
        case errorInResetHelper6                  = 0x06
        case rtcInterruptHandlerCalled            = 0x07
        case valueGreaterThan8                    = 0x08
        case bf0notEqualToBF1                     = 0x0A
        case tableCorruptionTempBasalExtraCommand = 0x0B
        case resetDueToCOP                        = 0x0D
        case resetDueToIllegalOpcode              = 0x0E
        case resetDueToIllegalAddress             = 0x0F
        case resetDueToSAWCOP                     = 0x10
        case corruptionInByte_866                 = 0x11
        case resetDueToLVD                        = 0x12
        case messageLengthGreaterThan0x108        = 0x13
        case subF9AAStateIssuesWithTab10x19       = 0x14
        case corruptionInWord129                  = 0x15
        case corruptionInByte868                  = 0x16
        case corruptionInTab1or3or5or19           = 0x17
        case reservoirEmpty                       = 0x18
        case unexpectedStateAfter80hours          = 0x1C
        case wrongValue0x4008                     = 0x1D
        case table129SumWrong                     = 0x1F
        case problemCalibrateTimer                = 0x23
        case rtcInterruptHandlerCalledByte358     = 0x26
        case missing2hourAlertToFillTank          = 0x27
        case faultEventSetupPod                   = 0x28
        case errorMainLoopHelper0                 = 0x29
        case errorMainLoopHelper1                 = 0x2A
        case errorMainLoopHelper2                 = 0x2B
        case errorMainLoopHelper3                 = 0x2C
        case errorMainLoopHelper4                 = 0x2D
        case errorMainLoopHelper5                 = 0x2E
        case errorMainLoopHelper6                 = 0x2F
        case errorMainLoopHelper7                 = 0x30
        case deliveryScheduleFault                = 0x31
        case badValueStartupTest                  = 0x32
        case badDecrementTab1                     = 0x33
        case badStateInReset                      = 0x34
        case errorFlashInitialisiation            = 0x36
        case unexpectedValueByte358               = 0x38
        case problemWithLoad1and2                 = 0x39
        case aGreaterThan7inMessage               = 0x3A
        case failedTestSawReset                   = 0x3B
        case testInProgress                       = 0x3C
        case problemWithPumpAnchor                = 0x3D
        case errorFlashWrite                      = 0x3E
        case badInitialByte357and71State          = 0x40
        case badValueByte357                      = 0x42
        case badValueByte71                       = 0x43
        case checkVoltagePullup1                  = 0x44
        case checkVoltagePullup2                  = 0x45
        case problemWithLoad1and2type46           = 0x46
        case problemWithLoad1and2type47           = 0x47
        case badTimerCalibration                  = 0x48
        case badTimerRatios                       = 0x49
        case badTimerValues                       = 0x4A
        case trimICSTooCloseTo0x1FF               = 0x4B
        case problemFindingBestTrimValue          = 0x4C
        case badSetTPM1MultiCasesValue            = 0x4D
        case issueTXOKprocessInputBuffer          = 0x52
        case wrongValueWord_107                   = 0x53
        case packetFrameLengthTooLong             = 0x54
        case unexpectedIRQHighinTimerTick         = 0x55
        case unexpectedIRQLowinTimerTick          = 0x56
        case badArgToGetEntry                     = 0x57
        case badArgToUpdate37ATable               = 0x58
        case errorUpdating0x37ATable              = 0x59
        case deliveryErrorDuringPriming           = 0x5C
        case badValue0x109                        = 0x5D
        case checkVoltageFailure                  = 0x5F
        case problemBasalUpdateType80             = 0x80
        case problemBasalUpdateType81             = 0x81
        case problemTempBasalUpdateType82         = 0x82
        case problemTempBasalUpdateType83         = 0x83
        case problemBolusUpdateType84             = 0x84
        case problemBolusUpdateType85             = 0x85
        case faultEventSetupPodType86             = 0x86
        case faultEventSetupPodType87             = 0x87
        case faultEventSetupPodType88             = 0x88
        case faultEventSetupPodType89             = 0x89
        case faultEventSetupPodType8A             = 0x8A
        case corruptionOfTables                   = 0x8B
        case faultEventSetupPodType8D             = 0x8D
        case faultEventSetupPodType8E             = 0x8E
        case faultEventSetupPodType8F             = 0x8F
        case badValueForTables                    = 0x90
        case faultEventSetupPodType91             = 0x91
        case faultEventSetupPodType92             = 0x92
        case faultEventSetupPodType93             = 0x93
        case badValueField6in0x1A                 = 0x95
    }
    
    public var faultType: FaultEventType? {
        return FaultEventType(rawValue: rawValue)
    }
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public var description: String {
        let prefix = String(format: LocalizedString("Fault Event Code %1$02x:", comment:" Fault Event Code 0xXX"), rawValue)

        if let faultType = faultType {
            switch faultType {
            case .noFaults:
                return "\(prefix) No faults, system running normally"
            case .failedFlashErase:
                return "\(prefix) Flash erase failed in $4x00 page"
            case .failedFlashStore:
                return "\(prefix) Flash store failed in $4x00 page"
            case .tableCorruptionBasalExtraCommand:
                return "\(prefix) Tab13 or Tab15 table corruption ($13 subcommand tables for basal.)"
            case .corruptionByte720:
                return "\(prefix) Corruption in byte_720"
            case .errorInResetHelper6:
                return "\(prefix) Error in RESET_helper_6"
            case .rtcInterruptHandlerCalled:
                return "\(prefix) RTC interrupt handler called when byte_358 is not 1"
            case .valueGreaterThan8:
                return "\(prefix) Value > 8"
            case .bf0notEqualToBF1:
                return "\(prefix) byte_BF0 != ~byte_BF1"
            case .tableCorruptionTempBasalExtraCommand:
                return "\(prefix) Tab9 or Tab11 table corruption ($16 subcommand tables for temp basal.)"
            case .resetDueToCOP:
                return "\(prefix) Reset due to COP"
            case .resetDueToIllegalOpcode:
                return "\(prefix) Reset due to illegal opcode"
            case .resetDueToIllegalAddress:
                return "\(prefix) Reset due to illegal address"
            case .resetDueToSAWCOP:
                return "\(prefix) Reset due to SAWCOP"
            case .corruptionInByte_866:
                return "\(prefix) Corruption in byte_866"
            case .resetDueToLVD:
                return "\(prefix) Reset due to LVD"
            case .messageLengthGreaterThan0x108:
                return "\(prefix) Message length > $108"
            case .subF9AAStateIssuesWithTab10x19:
                return "\(prefix) sub_F9AA() state issues with Tab1[$19]"
            case .corruptionInWord129:
                return "\(prefix) Corruption in word_129[8][4] table, word_86A, dword_86E"
            case .corruptionInByte868:
                return "\(prefix) Corruption in byte_868"
            case .corruptionInTab1or3or5or19:
                return "\(prefix) Corruption in Tab1[], Tab3[], Tab5[], Tab19[] or $A7[] tables or bad $BED or bad $72"
            case .reservoirEmpty:
                return "\(prefix) Tab1[0] == 0 (reservoir empty)"
            case .unexpectedStateAfter80hours:
                return "\(prefix) Unexpected internal state after Pod running 80 hours"
            case .wrongValue0x4008:
                return "\(prefix) In sub_B10D if $4008 value wrong"
            case .table129SumWrong:
                return "\(prefix) Table 129 sum wrong"
            case .problemCalibrateTimer:
                return "\(prefix) Problem in calibrate_timer_case_3"
            case .rtcInterruptHandlerCalledByte358:
                return "\(prefix) RTC interrupt handler called when byte_358 is 1"
            case .missing2hourAlertToFillTank:
                return "\(prefix) Failed to set up 2 hour alert for tank fill operation"
            case .faultEventSetupPod:
                return "\(prefix) Bad arg to update_insulin_variables(), problem inside verify_and_start_pump, bad state in main_loop_control_pump()"
            case .errorMainLoopHelper0:
                return "\(prefix) Error in big routine used by main_loop_helper_2($29+i[0])"
            case .errorMainLoopHelper1:
                return "\(prefix) Error in big routine used by main_loop_helper_2($29+i[1])"
            case .errorMainLoopHelper2:
                return "\(prefix) Error in big routine used by main_loop_helper_2($29+i[2])"
            case .errorMainLoopHelper3:
                return "\(prefix) Error in big routine used by main_loop_helper_2($29+i[3])"
            case .errorMainLoopHelper4:
                return "\(prefix) Error in big routine used by main_loop_helper_2($29+i[4])"
            case .errorMainLoopHelper5:
                return "\(prefix) Error in big routine used by main_loop_helper_2($29+i[5])"
            case .errorMainLoopHelper6:
                return "\(prefix) Error in big routine used by main_loop_helper_2($29+i[6])"
            case .errorMainLoopHelper7:
                return "\(prefix) Error in big routine used by main_loop_helper_2($29+i[7])"
            case .deliveryScheduleFault:
                return "\(prefix) Delivery schedule unexpected progress"
            case .badValueStartupTest:
                return "\(prefix) Bad value during startup testing (402D is not 0)"
            case .badDecrementTab1:
                return "\(prefix) Tab1[$12] was unexpectedly 0 after decrementing"
            case .badStateInReset:
                return "\(prefix) Bad internal state in __RESET()"
            case .errorFlashInitialisiation:
                return "\(prefix) Flash initialization error, wrong bit set in $4008"
            case .unexpectedValueByte358:
                return "\(prefix) Unexpected byte_358 value"
            case .problemWithLoad1and2:
                return "\(prefix) Problem with LOAD1/LOAD2"
            case .aGreaterThan7inMessage:
                return "\(prefix) A > 7 in message processing"
            case .failedTestSawReset:
                return "\(prefix) Failed SAW reset testing failed"
            case .testInProgress:
                return "\(prefix) Test in progress (402D is 'Z')"
            case .problemWithPumpAnchor:
                return "\(prefix) Problem with pump anchor"
            case .errorFlashWrite:
                return "\(prefix) Flash write error, failed writing to $4000"
            case .badInitialByte357and71State:
                return "\(prefix) Bad initial byte_71 & byte_357 encoder state"
            case .badValueByte357:
                return "\(prefix) Bad byte_357 value"
            case .badValueByte71:
                return "\(prefix) Bad exit byte_71 value"
            case .checkVoltagePullup1:
                return "\(prefix) Check LOAD voltage, PRACMP Pullup 1 problem"
            case .checkVoltagePullup2:
                return "\(prefix) Check LOAD voltage, PRACMP Pullup 2 problem"
            case .problemWithLoad1and2type46:
                return "\(prefix) Problem with LOAD1/LOAD2 Type46"
            case .problemWithLoad1and2type47:
                return "\(prefix) Problem with LOAD1/LOAD2 Type47"
            case .badTimerCalibration:
                return "\(prefix) Bad timer calibration"
            case .badTimerRatios:
                return "\(prefix) Bad timer values: COP timer ratio bad"
            case .badTimerValues:
                return "\(prefix) Bad timer values"
            case .trimICSTooCloseTo0x1FF:
                return "\(prefix) ICS trim too close to 0x1FF"
            case .problemFindingBestTrimValue:
                return "\(prefix) Problem finding best trim value"
            case .badSetTPM1MultiCasesValue:
                return "\(prefix) Bad set_TPM1_multi_cases value"
            case .issueTXOKprocessInputBuffer:
                return "\(prefix) TXOK issue in process_input_buffer"
            case .wrongValueWord_107:
                return "\(prefix) Wrong word_107 value during input message processing"
            case .packetFrameLengthTooLong:
                return "\(prefix) Packet frame length too long"
            case .unexpectedIRQHighinTimerTick:
                return "\(prefix) Unexpected IRQ high in timer_tick()"
            case .unexpectedIRQLowinTimerTick:
                return "\(prefix) Unexpected IRQ low in timer_tick()"
            case .badArgToGetEntry:
                return "\(prefix) Bad argument to get_37A_entry() or sub_E245 or bad $4036 entry"
            case .badArgToUpdate37ATable:
                return "\(prefix) Bad argument to update_37A_table()"
            case .errorUpdating0x37ATable:
                return "\(prefix) Error updating $37A table"
            case .deliveryErrorDuringPriming:
                return "\(prefix) Delivery Error During Priming"
            case .badValue0x109:
                return "\(prefix) Bad value for $109"
            case .checkVoltageFailure:
                return "\(prefix) Failure in main_loop_control_pump(): check_LOAD_voltage()"
            case .problemBasalUpdateType80:
                return "\(prefix) Basal variable state problem #1 inside update_insulin_variables"
            case .problemBasalUpdateType81:
                return "\(prefix) Basal variable state problem #2 inside update_insulin_variables"
            case .problemTempBasalUpdateType82:
                return "\(prefix) Temp Basal variable state problem #1 inside update_insulin_variables"
            case .problemTempBasalUpdateType83:
                return "\(prefix) Temp Basal variable state problem #2 inside update_insulin_variables"
            case .problemBolusUpdateType84:
                return "\(prefix) Bolus variable state problem #1 inside update_insulin_variables"
            case .problemBolusUpdateType85:
                return "\(prefix) Bolus variable state problem #2 inside update_insulin_variables"
            case .faultEventSetupPodType86:
                return "\(prefix) Problem inside verify_and_start_pump"
            case .faultEventSetupPodType87:
                return "\(prefix) Problem inside verify_and_start_pump"
            case .faultEventSetupPodType88:
                return "\(prefix) Problem inside verify_and_start_pump"
            case .faultEventSetupPodType89:
                return "\(prefix) Bad value problem #1 to verify_and_start_pump"
            case .faultEventSetupPodType8A:
                return "\(prefix) Bad value problem #2 to verify_and_start_pump"
            case .corruptionOfTables:
                return "\(prefix) Corruption of $283, $2E3, $315 table"
            case .faultEventSetupPodType8D:
                return "\(prefix) Bad value problem #3 to verify_and_start_pump"
            case .faultEventSetupPodType8E:
                return "\(prefix) Problem inside verify_and_start_pump"
            case .faultEventSetupPodType8F:
                return "\(prefix) Bad value during verify_and_start_pump because of sub_ACE3 is stated as bad value"
            case .badValueForTables:
                return "\(prefix) Bad value for $283/$2E3/$315 table specification"
            case .faultEventSetupPodType91:
                return "\(prefix) Problem inside verify_and_start_pump"
            case .faultEventSetupPodType92:
                return "\(prefix) Problem inside verify_and_start_pump"
            case .faultEventSetupPodType93:
                return "\(prefix) Problem inside verify_and_start_pump"
            case .badValueField6in0x1A:
                return "\(prefix) Bad table specifier field6 in 1A command"
            }
        } else {
             return "\(prefix) Unknown Error Code"
        }
    }
}
