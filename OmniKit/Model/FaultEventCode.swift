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
        case badPowerSwitchArrayValue1            = 0x19
        case badPowerSwitchArrayValue2            = 0x1A
        case badLoadCnthValue                     = 0x1B
        case exceededMaximumPodLife80Hrs          = 0x1C
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
        case badMType                             = 0x31
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
        case badCheckSdrhAndByte11FState          = 0x51
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
        case problemBigRoutine1Type60             = 0x60
        case problemBigRoutine1Type61             = 0x61
        case problemBigRoutine1Type62             = 0x62
        case problemBigRoutine1Type66             = 0x66
        case problemBigRoutine1Type67             = 0x67
        case problemBigRoutine1Type68             = 0x68
        case problemBigRoutine1Type69             = 0x69
        case problemBigRoutine1Type6A             = 0x6A
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
        case valuesDoNotMatchOrAreGreaterThen0x96 = 0x96
        case valuesDoNotMatchOrAreGreaterThen0x97 = 0x97
    }
    
    public var faultType: FaultEventType? {
        return FaultEventType(rawValue: rawValue)
    }
    
    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public var description: String {
        let faultDescription: String
        
        if let faultType = faultType {
            faultDescription = {
                switch faultType {
                case .noFaults:
                    return "No fault"
                case .failedFlashErase:
                    return "Flash erase failed in $4x00 page"
                case .failedFlashStore:
                    return "Flash store failed in $4x00 page"
                case .tableCorruptionBasalExtraCommand:
                    return "Tab13 or Tab15 table corruption ($13 subcommand tables for basal)"
                case .corruptionByte720:
                    return "Corruption in byte_720"
                case .errorInResetHelper6:
                    return "Error in RESET_helper_6"
                case .rtcInterruptHandlerCalled:
                    return "RTC interrupt handler called when byte_358 is not 1"
                case .valueGreaterThan8:
                    return "Value > 8"
                case .bf0notEqualToBF1:
                    return "byte_BF0 != ~byte_BF1"
                case .tableCorruptionTempBasalExtraCommand:
                    return "Tab9 or Tab11 table corruption ($16 subcommand tables for temp basal)"
                case .resetDueToCOP:
                    return "Reset due to COP"
                case .resetDueToIllegalOpcode:
                    return "Reset due to illegal opcode"
                case .resetDueToIllegalAddress:
                    return "Reset due to illegal address"
                case .resetDueToSAWCOP:
                    return "Reset due to SAWCOP"
                case .corruptionInByte_866:
                    return "Corruption in byte_866"
                case .resetDueToLVD:
                    return "Reset due to LVD"
                case .messageLengthGreaterThan0x108:
                    return "Message length > $108"
                case .subF9AAStateIssuesWithTab10x19:
                    return "sub_F9AA() state issues with Tab1[$19]"
                case .corruptionInWord129:
                    return "Corruption in word_129[8][4] table, word_86A, dword_86E"
                case .corruptionInByte868:
                    return "Corruption in byte_868"
                case .corruptionInTab1or3or5or19:
                    return "Corruption in Tab1[], Tab3[], Tab5[], Tab19[] or $A7[] tables or bad $BED or bad $72"
                case .reservoirEmpty:
                    return "Tab1[0] == 0 (reservoir empty) or Tab1[2] >= 0x10C4"
                case .badPowerSwitchArrayValue1:
                    return "Bad Power Switch Array Status and Control Register value 1 before starting pump"
                case .badPowerSwitchArrayValue2:
                    return "Bad Power Switch Array Status and Control Register value 2 before starting pump"
                case .badLoadCnthValue:
                    return "Bad LOADCNTH value when running pump"
                case .exceededMaximumPodLife80Hrs:
                    return "Exceeded maximum Pod life of 80 hours"
                case .wrongValue0x4008:
                    return "Unexpected internal state command_1A_schedule_parse_routine_wrapper"
                case .table129SumWrong:
                    return "Table 129 sum wrong"
                case .problemCalibrateTimer:
                    return "Problem in calibrate_timer_case_3"
                case .rtcInterruptHandlerCalledByte358:
                    return "RTC interrupt handler called when byte_358 is 1"
                case .missing2hourAlertToFillTank:
                    return "Failed to set up 2 hour alert for tank fill operation"
                case .faultEventSetupPod:
                    return "Bad arg or state in update_insulin_variables(), verify_and_start_pump() or main_loop_control_pump()"
                case .errorMainLoopHelper0:
                    return "Error in big routine used by main_loop_helper_2($29+i[0])"
                case .errorMainLoopHelper1:
                    return "Error in big routine used by main_loop_helper_2($29+i[1])"
                case .errorMainLoopHelper2:
                    return "Error in big routine used by main_loop_helper_2($29+i[2])"
                case .errorMainLoopHelper3:
                    return "Error in big routine used by main_loop_helper_2($29+i[3])"
                case .errorMainLoopHelper4:
                    return "Error in big routine used by main_loop_helper_2($29+i[4])"
                case .errorMainLoopHelper5:
                    return "Error in big routine used by main_loop_helper_2($29+i[5])"
                case .errorMainLoopHelper6:
                    return "Error in big routine used by main_loop_helper_2($29+i[6])"
                case .errorMainLoopHelper7:
                    return "Error in big routine used by main_loop_helper_2($29+i[7])"
                case .badMType:
                    return "Bad mtype"
                case .badValueStartupTest:
                    return "Bad value during startup testing (402D is not 0)"
                case .badDecrementTab1:
                    return "Tab1[$12] was unexpectedly 0 after decrementing"
                case .badStateInReset:
                    return "Bad internal state in __RESET()"
                case .errorFlashInitialisiation:
                    return "Flash initialization error, wrong bit set in $4008"
                case .unexpectedValueByte358:
                    return "Unexpected byte_358 value"
                case .problemWithLoad1and2:
                    return "Problem with LOAD1/LOAD2"
                case .aGreaterThan7inMessage:
                    return "A > 7 in message processing"
                case .failedTestSawReset:
                    return "SAW reset testing fail"
                case .testInProgress:
                    return "Test in progress (402D is 'Z')"
                case .problemWithPumpAnchor:
                    return "Problem with pump anchor"
                case .errorFlashWrite:
                    return "Flash write error, failed writing to $4000"
                case .badInitialByte357and71State:
                    return "Bad initial byte_71 & byte_357 state something_encoder_state()"
                case .badValueByte357:
                    return "Bad byte_357 value something_encoder_state()"
                case .badValueByte71:
                    return "Bad exit byte_71 value something_encoder_state()"
                case .checkVoltagePullup1:
                    return "Check LOAD voltage, PRACMP Pullup 1 problem"
                case .checkVoltagePullup2:
                    return "Check LOAD voltage, PRACMP Pullup 2 problem"
                case .problemWithLoad1and2type46:
                    return "Problem with LOAD1/LOAD2"
                case .problemWithLoad1and2type47:
                    return "Problem with LOAD1/LOAD2"
                case .badTimerCalibration:
                    return "Bad timer calibration"
                case .badTimerRatios:
                    return "Bad timer values: COP timer ratio bad"
                case .badTimerValues:
                    return "Bad timer values"
                case .trimICSTooCloseTo0x1FF:
                    return "ICS trim too close to 0x1FF"
                case .problemFindingBestTrimValue:
                    return "Problem finding best trim value"
                case .badSetTPM1MultiCasesValue:
                    return "Bad set_TPM1_multi_cases value"
                case .badCheckSdrhAndByte11FState:
                    return "Bad check_SDIRH and byte_11F state before starting pump"
                case .issueTXOKprocessInputBuffer:
                    return "TXOK issue in process_input_buffer"
                case .wrongValueWord_107:
                    return "Wrong word_107 value during input message processing"
                case .packetFrameLengthTooLong:
                    return "Packet frame length too long"
                case .unexpectedIRQHighinTimerTick:
                    return "Unexpected IRQ high in timer_tick()"
                case .unexpectedIRQLowinTimerTick:
                    return "Unexpected IRQ low in timer_tick()"
                case .badArgToGetEntry:
                    return "Bad argument to get_37A_entry() or sub_E245 or bad $4036 entry"
                case .badArgToUpdate37ATable:
                    return "Bad argument to update_37A_table()"
                case .errorUpdating0x37ATable:
                    return "Error updating $37A table"
                case .deliveryErrorDuringPriming:
                    return "Tab1[2] >= 0x34 in sub_D5AF"
                case .badValue0x109:
                    return "Bad value for $109"
                case .checkVoltageFailure:
                    return "Two check_LOAD_voltage failures before starting pump"
                case .problemBigRoutine1Type60:
                    return "Problem inside big_routine_1"
                case .problemBigRoutine1Type61:
                    return "Problem inside big_routine_1"
                case .problemBigRoutine1Type62:
                    return "Problem inside big_routine_1"
                case .problemBigRoutine1Type66:
                    return "Problem inside big_routine_1"
                case .problemBigRoutine1Type67:
                    return "Problem inside big_routine_1"
                case .problemBigRoutine1Type68:
                    return "Problem inside big_routine_1"
                case .problemBigRoutine1Type69:
                    return "Problem inside big_routine_1"
                case .problemBigRoutine1Type6A:
                    return "Problem inside big_routine_1"
                case .problemBasalUpdateType80:
                    return "Basal PPPP count too high when counter expired"
                case .problemBasalUpdateType81:
                    return "Basal PPPP count too low when counter expired"
                case .problemTempBasalUpdateType82:
                    return "Temp basal PPPP count too low when counter expired"
                case .problemTempBasalUpdateType83:
                    return "Temp basal PPPP count too high when counter expired"
                case .problemBolusUpdateType84:
                    return "Bolus PPPP count too high when counter expired"
                case .problemBolusUpdateType85:
                    return "Bolus PPPP count too low when counter expired"
                case .faultEventSetupPodType86:
                    return "Bolus PPPP count too low when about to pulse"
                case .faultEventSetupPodType87:
                    return "Temp basal PPPP count too low when about to pulse"
                case .faultEventSetupPodType88:
                    return "Pump request 3 with bolus IST index # not 0 or bolus PPPP count too low when about to pulse"
                case .faultEventSetupPodType89:
                    return "Pump request 4 and bolus IST index # is 0 about to pulse"
                case .faultEventSetupPodType8A:
                    return "Pump request 4 and bolus PPPP count too low when about to pulse"
                case .corruptionOfTables:
                    return "Corruption of $283, $2E3, $315 table"
                case .faultEventSetupPodType8D:
                    return "Bad input value to verify_and_start_pump"
                case .faultEventSetupPodType8E:
                    return "Pump req 5 with basal IST not set or temp basal IST set"
                case .faultEventSetupPodType8F:
                    return "Command $1A parse routine unexpected failed"
                case .badValueForTables:
                    return "Bad value for $283/$2E3/$315 table specification"
                case .faultEventSetupPodType91:
                    return "Pump request 1 with temp basal IST not set"
                case .faultEventSetupPodType92:
                    return "Pump request 2 with temp basal IST not set"
                case .faultEventSetupPodType93:
                    return "Pump request 3 and bolus IST not set when about to pulse"
                case .badValueField6in0x1A:
                    return "Bad table specifier field6 in 1A command"
                case .valuesDoNotMatchOrAreGreaterThen0x96:
                    return "Byte_35D != 4 or byte_33D >= 2 in sub_5DAF or sub_B148"
                case .valuesDoNotMatchOrAreGreaterThen0x97:
                    return " Byte_35D != 4 or byte_33D >= 2 in sub_5DAF"
                }
            }()
        } else {
            faultDescription = "Unknown Fault"
        }
        return String(format: "Fault Event Code 0x%02x: %@", rawValue, faultDescription)
    }
}
