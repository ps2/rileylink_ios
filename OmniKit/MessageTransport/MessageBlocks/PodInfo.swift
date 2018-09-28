//
//  PodInfoResponseSubType.swift
//  OmniKit
//
//  Created by Eelke Jager on 15/09/2018.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public protocol PodInfo {
    init(encodedData: Data) throws
    var podInfoType: PodInfoResponseSubType { get }
    var data: Data { get }
    
}

public enum PodInfoResponseSubType: UInt8 {
    case normal                      = 0x00
    case configuredAlerts            = 0x01
    case faultEvents                 = 0x02
    case dataLog                     = 0x03
    case fault                       = 0x05
    case hardcodedTestValues         = 0x06
    case flashVariables              = 0x46 // including state, initialization time, any faults
    case flashLogFirst50Entries      = 0x50
    case flashLogNext50Entries       = 0x51
    // https://github.com/openaps/openomni/wiki/Command-0E-Status-Request
    
    public var podInfoType: PodInfo.Type {
        switch self {
        case .normal:
            return StatusResponse.self as! PodInfo.Type
        case .configuredAlerts:
            return PodInfoConfiguredAlerts.self
        case .faultEvents:
            return PodInfoFaultEvent.self
        case .dataLog:
            return PodInfoDataLog.self
        case .fault:
            return PodInfoFault.self
        case .hardcodedTestValues:
            return PodInfoTester.self
        case .flashVariables:
            return PodInfoFlashVariables.self
        case .flashLogFirst50Entries:
            return PodInfoFlashLog.self
        case .flashLogNext50Entries:
            return PodInfoFlashLog.self
        }
    }
    
    public enum FaultEventType: UInt8, CustomStringConvertible {
        case noFaults                             = 0x00
        case failedFlashErase                     = 0x01
        case failedFlashStore                     = 0x02
        case tableCorruptionBasalExtraCommand     = 0x03
        case unKnownError04                       = 0x04
        case corruptionByte720                    = 0x05
        case errorInResetHelper6                  = 0x06
        case rtcInterruptHandlerCalled            = 0x07
        case valueGreaterThan8                    = 0x08
        case unKnownError09                       = 0x09
        case bf0notEqualToBF1                     = 0x0A
        case tableCorruptionTempBasalExtraCommand = 0x0B
        case unKnownError0C                       = 0x0C
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
        case unKnownError19                       = 0x19
        case unKnownError1A                       = 0x1A
        case unKnownError1B                       = 0x1B
        case unexpectedStateAfter80hours          = 0x1C
        case wrongValue0x4008                     = 0x1D
        case unKnownError1E                       = 0x1E
        case table129SumWrong                     = 0x1F
        case unKnownError20                       = 0x20
        case unKnownError21                       = 0x21
        case unKnownError22                       = 0x22
        case problemCalibrateTimer                = 0x23
        case unKnownError24                       = 0x24
        case unKnownError25                       = 0x25
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
        case unKnownError35                       = 0x35
        case errorFlashInitialisiation            = 0x36
        case unKnownError37                       = 0x37
        case unexpectedValueByte358               = 0x38
        case problemWithLoad1and2                 = 0x39
        case aGreaterThan7inMessage               = 0x3A
        case failedTestSawReset                   = 0x3B
        case testInProgress                       = 0x3C
        case problemWithPumpAnchor                = 0x3D
        case errorFlashWrite                      = 0x3E
        case unKnownError3F                       = 0x3F
        case badInitialByte357and71State          = 0x40
        case unKnownError41                       = 0x41
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
        case unKnownError4E                       = 0x4E
        case unKnownError4F                       = 0x4F
        case unKnownError50                       = 0x50
        case unKnownError51                       = 0x51
        case issueTXOKprocessInputBuffer          = 0x52
        case wrongValueWord_107                   = 0x53
        case packetFrameLengthTooLong             = 0x54
        case unexpectedIRQHighinTimerTick         = 0x55
        case unexpectedIRQLowinTimerTick          = 0x56
        case badArgToGetEntry                     = 0x57
        case badArgToUpdate37ATable               = 0x58
        case errorUpdating0x37ATable              = 0x59
        case unKnownError5A                       = 0x5A
        case unKnownError5B                       = 0x5B
        case deliveryErrorDuringPriming           = 0x5C
        case badValue0x109                        = 0x5D
        case unKnownError5E                       = 0x5E
        case checkVoltageFailure                  = 0x5F
        case unKnownError60                       = 0x60
        case unKnownError61                       = 0x61
        // skipped 62-7f for now
        case unKnownError6a                       = 0x6a
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
        case unKnownError8C                       = 0x8C
        case faultEventSetupPodType8D             = 0x8D
        case faultEventSetupPodType8E             = 0x8E
        case faultEventSetupPodType8F             = 0x8F
        case badValueForTables                    = 0x90
        case faultEventSetupPodType91             = 0x91
        case faultEventSetupPodType92             = 0x92
        case faultEventSetupPodType93             = 0x93
        case unKnownError94                       = 0x94
        case badValueField6in0x1A                 = 0x95
        case unKnownError96                       = 0x96
        case unKnownError97                       = 0x97
        
        public var description: String {
            switch self {
            case .noFaults:
                return LocalizedString("Fault Event Type 0x00: No faults, system running normally.", comment: "Fault Event Type 0x00: No faults, system running normally.")
            case .failedFlashErase:
                return LocalizedString("Fault Event Type 0x01: Flash erase failed in $4x00 page.", comment: "Fault Event Type 0x01: Flash erase failed in $4x00 page.")
            case .failedFlashStore:
                return LocalizedString("Fault Event Type 0x02: Flash store failed in $4x00 page.", comment: "Fault Event Type 0x02: Flash store failed in $4x00 page.")
            case .tableCorruptionBasalExtraCommand:
                return LocalizedString("Fault Event Type 0x03: Tab13 or Tab15 table corruption ($13 subcommand tables for basal.)", comment: "Fault Event Type 0x03: Tab13 or Tab15 table corruption ($13 subcommand tables for basal.")
            case .unKnownError04:
                return LocalizedString("Fault Event Type 0x04: Unknown", comment: "Fault Event Type 0x04: Unknown.")
            case .corruptionByte720:
                return LocalizedString("Fault Event Type 0x05: Corruption in byte_720", comment: "Fault Event Type 0x05: Corruption in byte_720")
            case .errorInResetHelper6:
                return LocalizedString("Fault Event Type 0x06: Error in RESET_helper_6", comment: "Fault Event Type 0x06: Error in RESET_helper_6")
            case .rtcInterruptHandlerCalled:
                return LocalizedString("Fault Event Type 0x07: RTC interrupt handler called when byte_358 is not 1.", comment: "Fault Event Type 0x07: RTC interrupt handler called when byte_358 is not 1.")
            case .valueGreaterThan8:
                return LocalizedString("Fault Event Type 0x08: Value > 8", comment: "Fault Event Type 0x08: Value > 8")
            case .unKnownError09:
                return LocalizedString("Fault Event Type 0x09: Unknown Error.", comment: "Fault Event Type 0x09: Unknown Error.")
            case .bf0notEqualToBF1:
                return LocalizedString("Fault Event Type 0x09: byte_BF0 != ~byte_BF1", comment: "Fault Event Type 0x09: byte_BF0 != ~byte_BF1")
            case .tableCorruptionTempBasalExtraCommand:
                return LocalizedString("Fault Event Type 0x0B: Tab9 or Tab11 table corruption ($16 subcommand tables for temp basal.)", comment: "Fault Event Type 0x0B: Tab9 or Tab11 table corruption ($16 subcommand tables for temp basal.")
            case .unKnownError0C:
                return LocalizedString("Fault Event Type 0x0C: Unknown Error.", comment: "Fault Event Type 0x0C: Unknown Error.")
            case .resetDueToCOP:
                return LocalizedString("Fault Event Type 0x0D: Reset due to COP.", comment: "Fault Event Type 0x0D: Reset due to COP.")
            case .resetDueToIllegalOpcode:
                return LocalizedString("Fault Event Type 0x0E: Reset due to illegal opcode.", comment: "Fault Event Type 0x0E: Reset due to illegal opcode.")
            case .resetDueToIllegalAddress:
                return LocalizedString("Fault Event Type 0x0F: Reset due to illegal address.", comment: "Fault Event Type 0x0F: Reset due to illegal address.")
            case .resetDueToSAWCOP:
                return LocalizedString("Fault Event Type 0x10: Reset due to SAWCOP.", comment: "Fault Event Type 0x10: Reset due to SAWCOP.")
            case .corruptionInByte_866:
                return LocalizedString("Fault Event Type 0x11: Corruption in byte_866.", comment: "Fault Event Type 0x11: Corruption in byte_866.")
            case .resetDueToLVD:
                return LocalizedString("Fault Event Type 0x12: Reset due to LVD.", comment: "Fault Event Type 0x12: Corruption in byte_866.")
            case .messageLengthGreaterThan0x108:
                return LocalizedString("Fault Event Type 0x13: Message length > $108.", comment: "Fault Event Type 0x13: Message length > $108.")
            case .subF9AAStateIssuesWithTab10x19:
                return LocalizedString("Fault Event Type 0x14: sub_F9AA() state issues with Tab1[$19].", comment: "Fault Event Type 0x14: sub_F9AA() state issues with Tab1[$19].")
            case .corruptionInWord129:
                return LocalizedString("Fault Event Type 0x15: Corruption in word_129[8][4] table, word_86A, dword_86E.", comment: "Fault Event Type 0x15: Corruption in word_129[8][4] table, word_86A, dword_86E.")
            case .corruptionInByte868:
                return LocalizedString("Fault Event Type 0x16: Corruption in byte_868.", comment: "Fault Event Type 0x16: Corruption in byte_868.")
            case .corruptionInTab1or3or5or19:
                return LocalizedString("Fault Event Type 0x17: Corruption in Tab1[], Tab3[], Tab5[], Tab19[] or $A7[] tables or bad $BED or bad $72.", comment: "Fault Event Type 0x15: Corruption in Tab1[], Tab3[], Tab5[], Tab19[] or $A7[] tables or bad $BED or bad $72.")
            case .reservoirEmpty:
                return LocalizedString("Fault Event Type 0x18: Tab1[0] == 0 (reservoir empty).", comment: "Fault Event Type 0x18: Tab1[0] == 0 (reservoir empty).")
            case .unKnownError19:
                return LocalizedString("Fault Event Type 0x19: Unknown Error.", comment: "Fault Event Type 0x19: Unknown Error.")
            case .unKnownError1A:
                return LocalizedString("Fault Event Type 0x1A: Unknown Error.", comment: "Fault Event Type 0x1A: Unknown Error.")
            case .unKnownError1B:
                return LocalizedString("Fault Event Type 0x1B: Unknown Error.", comment: "Fault Event Type 0x1B: Unknown Error.")
            case .unexpectedStateAfter80hours:
                return LocalizedString("Fault Event Type 0x1C: Unexpected internal state after Pod running 80 hours.", comment: "Fault Event Type 0x1C: Unexpected internal state after Pod running 80 hours.")
            case .wrongValue0x4008:
                return LocalizedString("Fault Event Type 0x1D: In sub_B10D if $4008 value wrong.", comment: "Fault Event Type 0x1D: In sub_B10D if $4008 value wrong.")
            case .unKnownError1E:
                return LocalizedString("Fault Event Type 0x1E: Unknown Error.", comment: "Fault Event Type 0x1E: Unknown Error.")
            case .table129SumWrong:
                return LocalizedString("Fault Event Type 0x1F: Table 129 sum wrong.", comment: "Fault Event Type 0x1F: Table 129 sum wrong.")
            case .unKnownError20:
                return LocalizedString("Fault Event Type 0x20: Unknown Error.", comment: "Fault Event Type 0x20: Unknown Error.")
            case .unKnownError21:
                return LocalizedString("Fault Event Type 0x21: Unknown Error.", comment: "Fault Event Type 0x21: Unknown Error.")
            case .unKnownError22:
                return LocalizedString("Fault Event Type 0x22: Unknown Error.", comment: "Fault Event Type 0x22: Unknown Error.")
            case .problemCalibrateTimer:
                return LocalizedString("Fault Event Type 0x23: Problem in calibrate_timer_case_3.", comment: "Fault Event Type 0x23: Problem in calibrate_timer_case_3.")
            case .unKnownError24:
                return LocalizedString("Fault Event Type 0x24: Unknown Error.", comment: "Fault Event Type 0x24: Unknown Error.")
            case .unKnownError25:
                return LocalizedString("Fault Event Type 0x25: Unknown Error.", comment: "Fault Event Type 0x25: Unknown Error.")
            case .rtcInterruptHandlerCalledByte358:
                return LocalizedString("Fault Event Type 0x26: RTC interrupt handler called when byte_358 is 1r.", comment: "Fault Event Type 0x26: RTC interrupt handler called when byte_358 is 1.")
            case .missing2hourAlertToFillTank:
                return LocalizedString("Fault Event Type 0x27: Failed to set up 2 hour alert for tank fill operation.", comment: "Fault Event Type 0x27: Failed to set up 2 hour alert for tank fill operation.")
            case .faultEventSetupPod:
                return LocalizedString("Fault Event Type 0x28: Bad arg to update_insulin_variables(), problem inside verify_and_start_pump, bad state in main_loop_control_pump().", comment: "Fault Event Type 0x28: Bad arg to update_insulin_variables(), problem inside verify_and_start_pump, bad state in main_loop_control_pump().")
            case .errorMainLoopHelper0:
                return LocalizedString("Fault Event Type 0x29: Error in big routine used by main_loop_helper_2($29+i[0]).", comment: "Fault Event Type 0x29: Error in big routine used by main_loop_helper_2($29+i[0]).")
            case .errorMainLoopHelper1:
                return LocalizedString("Fault Event Type 0x2A: Error in big routine used by main_loop_helper_2($29+i[1]).", comment: "Fault Event Type 0x2A: Error in big routine used by main_loop_helper_2($29+i[1]).")
            case .errorMainLoopHelper2:
                return LocalizedString("Fault Event Type 0x2B: Error in big routine used by main_loop_helper_2($29+i[2]).", comment: "Fault Event Type 0x2B: Error in big routine used by main_loop_helper_2($29+i[2]).")
            case .errorMainLoopHelper3:
                return LocalizedString("Fault Event Type 0x2C: Error in big routine used by main_loop_helper_2($29+i[3]).", comment: "Fault Event Type 0x2C: Error in big routine used by main_loop_helper_2($29+i[3]).")
            case .errorMainLoopHelper4:
                return LocalizedString("Fault Event Type 0x2D: Error in big routine used by main_loop_helper_2($29+i[4]).", comment: "Fault Event Type 0x2D: Error in big routine used by main_loop_helper_2($29+i[4]).")
            case .errorMainLoopHelper5:
                return LocalizedString("Fault Event Type 0x2E: Error in big routine used by main_loop_helper_2($29+i[5]).", comment: "Fault Event Type 0x2E: Error in big routine used by main_loop_helper_2($29+i[5]).")
            case .errorMainLoopHelper6:
                return LocalizedString("Fault Event Type 0x2F: Error in big routine used by main_loop_helper_2($29+i[6]).", comment: "Fault Event Type 0x2F: Error in big routine used by main_loop_helper_2($29+i[6]).")
            case .errorMainLoopHelper7:
                return LocalizedString("Fault Event Type 0x30: Error in big routine used by main_loop_helper_2($29+i[7]).", comment: "Fault Event Type 0x30: Error in big routine used by main_loop_helper_2($29+i[7]).")
            case .badMType:
                return LocalizedString("Fault Event Type 0x31: Bad MType.", comment: "Fault Event Type 0x31: Bad MType.")
            case .badValueStartupTest:
                return LocalizedString("Fault Event Type 0x32: Bad value during startup testing (402D is not 0).", comment: "Fault Event Type 0x32: Bad value during startup testing (402D is not 0).")
            case .badDecrementTab1:
                return LocalizedString("Fault Event Type 0x33: Tab1[$12] was unexpectedly 0 after decrementing.", comment: "Fault Event Type 0x33: Tab1[$12] was unexpectedly 0 after decrementing.")
            case .badStateInReset:
                return LocalizedString("Fault Event Type 0x34: Bad internal state in __RESET().", comment: "Fault Event Type 0x34: Bad internal state in __RESET().")
            case .unKnownError35:
                return LocalizedString("Fault Event Type 0x35: Unknown Error.", comment: "Fault Event Type 0x35: Unknown Error.")
            case .errorFlashInitialisiation:
                return LocalizedString("Fault Event Type 0x36: Flash initialization error, wrong bit set in $4008.", comment: "Fault Event Type 0x36: Flash initialization error, wrong bit set in $4008.")
            case .unKnownError37:
                return LocalizedString("Fault Event Type 0x37: Unknown Error.", comment: "Fault Event Type 0x37: Unknown Error.")
            case .unexpectedValueByte358:
                return LocalizedString("Fault Event Type 0x38: Unexpected byte_358 value.", comment: "Fault Event Type 0x38: Unexpected byte_358 value.")
            case .problemWithLoad1and2:
                return LocalizedString("Fault Event Type 0x39: Problem with LOAD1/LOAD2.", comment: "Fault Event Type 0x39: Problem with LOAD1/LOAD2.")
            case .aGreaterThan7inMessage:
                return LocalizedString("Fault Event Type 0x3A: A > 7 in message processing.", comment: "Fault Event Type 0x3A: A > 7 in message processing.")
            case .failedTestSawReset:
                return LocalizedString("Fault Event Type 0x3B: Failed SAW reset testing failed.", comment: "Fault Event Type 0x3B: Failed SAW reset testing failed.")
            case .testInProgress:
                return LocalizedString("Fault Event Type 0x3C: Test in progress (402D is 'Z').", comment: "Fault Event Type 0x3C: Test in progress (402D is 'Z').")
            case .problemWithPumpAnchor:
                return LocalizedString("Fault Event Type 0x3D: Problem with pump anchor.", comment: "Fault Event Type 0x3D: Problem with pump anchor.")
            case .errorFlashWrite:
                return LocalizedString("Fault Event Type 0x3E: Flash write error, failed writing to $4000.", comment: "Fault Event Type 0x3E: Flash write error, failed writing to $4000.")
            case .unKnownError3F:
                return LocalizedString("Fault Event Type 0x3F: Unknown Error.", comment: "Fault Event Type 0x3F: Unknown Error.")
            case .badInitialByte357and71State:
                return LocalizedString("Fault Event Type 0x40: Bad initial byte_71 & byte_357 encoder state.", comment: "Fault Event Type 0x40: Bad initial byte_71 & byte_357 encoder state.")
            case .unKnownError41:
                return LocalizedString("Fault Event Type 0x41: Unknown Error.", comment: "Fault Event Type 0x41: Unknown Error.")
            case .badValueByte357:
                return LocalizedString("Fault Event Type 0x42: Bad byte_357 value.", comment: "Fault Event Type 0x42: Bad byte_357 value.")
            case .badValueByte71:
                return LocalizedString("Fault Event Type 0x43: Bad exit byte_71 value.", comment: "Fault Event Type 0x43: Bad exit byte_71 value.")
            case .checkVoltagePullup1:
                return LocalizedString("Fault Event Type 0x44: Check LOAD voltage, PRACMP Pullup 1 problem.", comment: "Fault Event Type 0x44: Check LOAD voltage, PRACMP Pullup 1 problem.")
            case .checkVoltagePullup2:
                return LocalizedString("Fault Event Type 0x45: Check LOAD voltage, PRACMP Pullup 2 problem.", comment: "Fault Event Type 0x45: Check LOAD voltage, PRACMP Pullup 2 problem.")
            case .problemWithLoad1and2type46:
                return LocalizedString("Fault Event Type 0x46: Problem with LOAD1/LOAD2 Type46.", comment: "Fault Event Type 0x46: Problem with LOAD1/LOAD2 Type46.")
            case .problemWithLoad1and2type47:
                return LocalizedString("Fault Event Type 0x47: Problem with LOAD1/LOAD2 Type47.", comment: "Fault Event Type 0x47: Problem with LOAD1/LOAD2 Type47.")
            case .badTimerCalibration:
                return LocalizedString("Fault Event Type 0x48: Bad timer calibration.", comment: "Fault Event Type 0x48: Bad timer calibration.")
            case .badTimerRatios:
                return LocalizedString("Fault Event Type 0x49: Bad timer values: COP timer ratio bad.", comment: "Fault Event Type 0x49: Bad timer values: COP timer ratio bad.")
            case .badTimerValues:
                return LocalizedString("Fault Event Type 0x4A: Bad timer values", comment: "Fault Event Type 0x4A: Bad timer values")
            case .trimICSTooCloseTo0x1FF:
                return LocalizedString("Fault Event Type 0x4B: ICS trim too close to 0x1FF.", comment: "Fault Event Type 0x4B: ICS trim too close to 0x1FF.")
            case .problemFindingBestTrimValue:
                return LocalizedString("Fault Event Type 0x4C: Problem finding best trim value.", comment: "Fault Event Type 0x4C: Problem finding best trim value.")
            case .badSetTPM1MultiCasesValue:
                return LocalizedString("Fault Event Type 0x4D: Bad set_TPM1_multi_cases value.", comment: "Fault Event Type 0x4C: Bad set_TPM1_multi_cases value.")
            case .unKnownError4E:
                return LocalizedString("Fault Event Type 0x4E: Unknown Error.", comment: "Fault Event Type 0x4E: Unknown Error.")
            case .unKnownError4F:
                return LocalizedString("Fault Event Type 0x4F: Unknown Error.", comment: "Fault Event Type 0x4F: Unknown Error.")
            case .unKnownError50:
                return LocalizedString("Fault Event Type 0x50: Unknown Error.", comment: "Fault Event Type 0x50: Unknown Error.")
            case .unKnownError51:
                return LocalizedString("Fault Event Type 0x51: Unknown Error.", comment: "Fault Event Type 0x51: Unknown Error.")
            case .issueTXOKprocessInputBuffer:
                return LocalizedString("Fault Event Type 0x52: TXOK issue in process_input_buffer.", comment: "Fault Event Type 0x52: TXOK issue in process_input_buffer.")
            case .wrongValueWord_107:
                return LocalizedString("Fault Event Type 0x53: Wrong word_107 value during input message processing.", comment: "Fault Event Type 0x53: Wrong word_107 value during input message processing.")
            case .packetFrameLengthTooLong:
                return LocalizedString("Fault Event Type 0x54: Packet frame length too long.", comment: "Fault Event Type 0x54: Packet frame length too long.")
            case .unexpectedIRQHighinTimerTick:
                return LocalizedString("Fault Event Type 0x55: Unexpected IRQ high in timer_tick().", comment: "Fault Event Type 0x55: Unexpected IRQ high in timer_tick()")
            case .unexpectedIRQLowinTimerTick:
                return LocalizedString("Fault Event Type 0x56: Unexpected IRQ low in timer_tick().", comment: "Fault Event Type 0x56: Unexpected IRQ low in timer_tick()")
            case .badArgToGetEntry:
                return LocalizedString("Fault Event Type 0x57: Bad argument to get_37A_entry() or sub_E245 or bad $4036 entry.", comment: "Fault Event Type 0x57: Bad argument to get_37A_entry() or sub_E245 or bad $4036 entry.")
            case .badArgToUpdate37ATable:
                return LocalizedString("Fault Event Type 0x58: Bad argument to update_37A_table().", comment: "Fault Event Type 0x58: Bad argument to update_37A_table().")
            case .errorUpdating0x37ATable:
                return LocalizedString("Fault Event Type 0x59: Error updating $37A table.", comment: "Fault Event Type 0x59: Error updating $37A table.")
            case .unKnownError5A:
                return LocalizedString("Fault Event Type 0x5A: Unknown Error.", comment: "Fault Event Type 0x5A: Unknown Error.")
            case .unKnownError5B:
                return LocalizedString("Fault Event Type 0x5B: Unknown Error.", comment: "Fault Event Type 0x5B: Unknown Error.")
            case .deliveryErrorDuringPriming:
                return LocalizedString("Fault Event Type 0x5C: Delivery Error During Priming.", comment: "Fault Event Type 0x5C: Delivery Error During Priming.")
            case .badValue0x109:
                return LocalizedString("Fault Event Type 0x5D: Bad value for $109.", comment: "Fault Event Type 0x5D: Bad value for $109.")
            case .unKnownError5E:
                return LocalizedString("Fault Event Type 0x5E: Unknown Error.", comment: "Fault Event Type 0x5E: Unknown Error.")
            case .checkVoltageFailure:
                return LocalizedString("Fault Event Type 0x5F: Failure in main_loop_control_pump(): check_LOAD_voltage().", comment: "Failure in main_loop_control_pump(): check_LOAD_voltage().")
            case .unKnownError60:
                return LocalizedString("Fault Event Type 0x60: Unknown Error.", comment: "Fault Event Type 0x60: Unknown Error.")
            case .unKnownError61:
                return LocalizedString("Fault Event Type 0x61: Unknown Error.", comment: "Fault Event Type 0x61: Unknown Error.")
            case .unKnownError6a:
                return LocalizedString("Fault Event Type 0x6a: Unknown Error.", comment: "Fault Event Type 0x6a: Unknown Error.")
            case .problemBasalUpdateType80:
                return LocalizedString("Fault Event Type 0x80: Basal variable state problem #1 inside update_insulin_variables.", comment: "Fault Event Type 0x80: Basal variable state problem #1 inside update_insulin_variables.")
            case .problemBasalUpdateType81:
                return LocalizedString("Fault Event Type 0x81: Basal variable state problem #2 inside update_insulin_variables.", comment: "Fault Event Type 0x81: Basal variable state problem #2 inside update_insulin_variables.")
            case .problemTempBasalUpdateType82:
                return LocalizedString("Fault Event Type 0x82: Temp Basal variable state problem #1 inside update_insulin_variables.", comment: "Fault Event Type 0x82: Temp Basal variable state problem #1 inside update_insulin_variables.")
            case .problemTempBasalUpdateType83:
                return LocalizedString("Fault Event Type 0x83: Temp Basal variable state problem #2 inside update_insulin_variables.", comment: "Fault Event Type 0x83: Temp Basal variable state problem #2 inside update_insulin_variables.")
            case .problemBolusUpdateType84:
                return LocalizedString("Fault Event Type 0x84: Bolus variable state problem #1 inside update_insulin_variables.", comment: "Fault Event Type 0x84: Bolus variable state problem #1 inside update_insulin_variables.")
            case .problemBolusUpdateType85:
                return LocalizedString("Fault Event Type 0x84: Bolus variable state problem #2 inside update_insulin_variables.", comment: "Fault Event Type 0x84: Bolus variable state problem #2 inside update_insulin_variables.")
            case .faultEventSetupPodType86:
                return LocalizedString("Fault Event Type 0x86: Problem inside verify_and_start_pump.", comment: "Fault Event Type 0x86: Problem inside verify_and_start_pump.")
            case .faultEventSetupPodType87:
                return LocalizedString("Fault Event Type 0x87: Problem inside verify_and_start_pump.", comment: "Fault Event Type 0x87: Problem inside verify_and_start_pump.")
            case .faultEventSetupPodType88:
                return LocalizedString("Fault Event Type 0x88: Problem inside verify_and_start_pump.", comment: "Fault Event Type 0x88: Problem inside verify_and_start_pump.")
            case .faultEventSetupPodType89:
                return LocalizedString("Fault Event Type 0x89: Bad value problem #1 to verify_and_start_pump.", comment: "Fault Event Type 0x89: Bad value problem #1 to verify_and_start_pump.")
            case .faultEventSetupPodType8A:
                return LocalizedString("Fault Event Type 0x8A: Bad value problem #2 to verify_and_start_pump.", comment: "Fault Event Type 0x8A: Bad value problem #2 to verify_and_start_pump.")
            case .corruptionOfTables:
                return LocalizedString("Fault Event Type 0x8B: Corruption of $283, $2E3, $315 table.", comment: "Fault Event Type 0x8B: Corruption of $283, $2E3, $315 table.")
            case .unKnownError8C:
                return LocalizedString("Fault Event Type 0x8C: Unknown Error.", comment: "Fault Event Type 0x8C: Unknown Error.")
            case .faultEventSetupPodType8D:
                return LocalizedString("Fault Event Type 0x8D: Bad value problem #3 to verify_and_start_pump.", comment: "Fault Event Type 0x8D: Bad value problem #3 to verify_and_start_pump.")
            case .faultEventSetupPodType8E:
                return LocalizedString("Fault Event Type 0x8E: Problem inside verify_and_start_pump.", comment: "Fault Event Type 0x8E: Problem inside verify_and_start_pump.")
            case .faultEventSetupPodType8F:
                return LocalizedString("Fault Event Type 0x8F: Bad value during verify_and_start_pump because of sub_ACE3 is stated as bad value.", comment: "Fault Event Type 0x8F: Bad value during verify_and_start_pump because of sub_ACE3 is stated as bad value.")
            case .badValueForTables:
                return LocalizedString("Fault Event Type 0x90: Bad value for $283/$2E3/$315 table specification.", comment: "Fault Event Type 0x90: Bad value for $283/$2E3/$315 table specification.")
            case .faultEventSetupPodType91:
                return LocalizedString("Fault Event Type 0x91: Problem inside verify_and_start_pump.", comment: "Fault Event Type 0x91: Problem inside verify_and_start_pump.")
            case .faultEventSetupPodType92:
                return LocalizedString("Fault Event Type 0x92: Problem inside verify_and_start_pump.", comment: "Fault Event Type 0x92: Problem inside verify_and_start_pump.")
            case .faultEventSetupPodType93:
                return LocalizedString("Fault Event Type 0x93: Problem inside verify_and_start_pump.", comment: "Fault Event Type 0x93: Problem inside verify_and_start_pump.")
            case .unKnownError94:
                return LocalizedString("Fault Event Type 0x94: Unknown Error.", comment: "Fault Event Type 0x94: Unknown Error.")
            case .badValueField6in0x1A:
                return LocalizedString("Fault Event Type 0x95: Bad table specifier field6 in 1A command.", comment: "Fault Event Type 0x95: Bad table specifier field6 in 1A command.")
            case .unKnownError96:
                return LocalizedString("Fault Event Type 0x96: Unknown Error.", comment: "Fault Event Type 0x96: Unknown Error.")
            case .unKnownError97:
                return LocalizedString("Fault Event Type 0x97: Unknown Error.", comment: "Fault Event Type 0x97: Unknown Error.")
            }
        }
    }

}
