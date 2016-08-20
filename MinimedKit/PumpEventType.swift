//
//  PumpEventType.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/7/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//


public enum PumpEventType: UInt8 {
    case BolusNormal = 0x01
    case Prime = 0x03
    case AlarmPump = 0x06
    case ResultDailyTotal = 0x07
    case ChangeBasalProfilePattern = 0x08
    case ChangeBasalProfile = 0x09
    case CalBGForPH = 0x0a
    case AlarmSensor = 0x0b
    case ClearAlarm = 0x0c
    case SelectBasalProfile = 0x14
    case TempBasalDuration = 0x16
    case ChangeTime = 0x17
    case JournalEntryPumpLowBattery = 0x19
    case Battery = 0x1a
    case Suspend = 0x1e
    case Resume = 0x1f
    case Rewind = 0x21
    case ChangeChildBlockEnable = 0x23
    case ChangeMaxBolus = 0x24
    case EnableDisableRemote = 0x26
    case ChangeMaxBasal = 0x2c
    case EnableBolusWizard = 0x2d
    case ChangeBGReminderOffset = 0x31
    case ChangeAlarmClockTime = 0x32
    case TempBasal = 0x33
    case JournalEntryPumpLowReservoir = 0x34
    case AlarmClockReminder = 0x35
    case Questionable3b = 0x3b
    case ChangeParadigmLinkID = 0x3c
    case BGReceived = 0x3f
    case JournalEntryMealMarker = 0x40
    case JournalEntryExerciseMarker = 0x41
    case JournalEntryInsulinMarker = 0x42
    case JournalEntryOtherMarker = 0x43
    case ChangeSensorSetup2 = 0x50
    case ChangeSensorRateOfChangeAlertSetup = 0x56
    case ChangeBolusScrollStepSize = 0x57
    case ChangeBolusWizardSetup = 0x5a
    case BolusWizardBolusEstimate = 0x5b
    case UnabsorbedInsulin = 0x5c
    case ChangeVariableBolus = 0x5e
    case ChangeAudioBolus = 0x5f
    case ChangeBGReminderEnable = 0x60
    case ChangeAlarmClockEnable = 0x61
    case ChangeTempBasalType = 0x62
    case ChangeAlarmNotifyMode = 0x63
    case ChangeTimeFormat = 0x64
    case ChangeReservoirWarningTime = 0x65
    case ChangeBolusReminderEnable = 0x66
    case ChangeBolusReminderTime = 0x67
    case DeleteBolusReminderTime = 0x68
    case DeleteAlarmClockTime = 0x6a
    case Model522ResultTotals = 0x6d
    case Sara6E = 0x6e
    case ChangeCarbUnits = 0x6f
    case BasalProfileStart = 0x7b
    case ChangeWatchdogEnable = 0x7c
    case ChangeOtherDeviceID = 0x7d
    case ChangeWatchdogMarriageProfile = 0x81
    case DeleteOtherDeviceID = 0x82
    case ChangeCaptureEventEnable = 0x83
    
    public var eventType: PumpEvent.Type {
        switch self {
        case .BolusNormal:
            return BolusNormalPumpEvent.self
        case .Prime:
            return PrimePumpEvent.self
        case .AlarmPump:
            return PumpAlarmPumpEvent.self
        case .ResultDailyTotal:
            return ResultDailyTotalPumpEvent.self
        case .ChangeBasalProfilePattern:
            return ChangeBasalProfilePatternPumpEvent.self
        case .ChangeBasalProfile:
            return ChangeBasalProfilePumpEvent.self
        case .CalBGForPH:
            return CalBGForPHPumpEvent.self
        case .AlarmSensor:
            return AlarmSensorPumpEvent.self
        case .ClearAlarm:
            return ClearAlarmPumpEvent.self
        case TempBasalDuration:
            return TempBasalDurationPumpEvent.self
        case .ChangeTime:
            return ChangeTimePumpEvent.self
        case .JournalEntryPumpLowBattery:
            return JournalEntryPumpLowBatteryPumpEvent.self
        case .Battery:
            return BatteryPumpEvent.self
        case .Suspend:
            return SuspendPumpEvent.self
        case .Resume:
            return ResumePumpEvent.self
        case .Rewind:
            return RewindPumpEvent.self
        case .ChangeChildBlockEnable:
            return ChangeChildBlockEnablePumpEvent.self
        case .ChangeMaxBolus:
            return ChangeMaxBolusPumpEvent.self
        case .EnableDisableRemote:
            return EnableDisableRemotePumpEvent.self
        case .ChangeMaxBasal:
            return ChangeMaxBasalPumpEvent.self
        case .EnableBolusWizard:
            return EnableBolusWizardPumpEvent.self
        case .ChangeBGReminderOffset:
            return ChangeBGReminderOffsetPumpEvent.self
        case .ChangeAlarmClockTime:
            return ChangeAlarmClockTimePumpEvent.self
        case .TempBasal:
            return TempBasalPumpEvent.self
        case .JournalEntryPumpLowReservoir:
            return JournalEntryPumpLowReservoirPumpEvent.self
        case .AlarmClockReminder:
            return AlarmClockReminderPumpEvent.self
        case .ChangeParadigmLinkID:
            return ChangeParadigmLinkIDPumpEvent.self
        case .BGReceived:
            return BGReceivedPumpEvent.self
        case .JournalEntryExerciseMarker:
            return JournalEntryExerciseMarkerPumpEvent.self
        case .JournalEntryInsulinMarker:
            return JournalEntryInsulinMarkerPumpEvent.self
        case .JournalEntryMealMarker:
            return JournalEntryMealMarkerPumpEvent.self
        case .ChangeSensorSetup2:
            return ChangeSensorSetup2PumpEvent.self
        case .ChangeSensorRateOfChangeAlertSetup:
            return ChangeSensorRateOfChangeAlertSetupPumpEvent.self
        case .ChangeBolusScrollStepSize:
            return ChangeBolusScrollStepSizePumpEvent.self
        case .ChangeBolusWizardSetup:
            return ChangeBolusWizardSetupPumpEvent.self
        case .BolusWizardBolusEstimate:
            return BolusWizardEstimatePumpEvent.self
        case .UnabsorbedInsulin:
            return UnabsorbedInsulinPumpEvent.self
        case .ChangeVariableBolus:
            return ChangeVariableBolusPumpEvent.self
        case .ChangeAudioBolus:
            return ChangeAudioBolusPumpEvent.self
        case .ChangeBGReminderEnable:
            return ChangeBGReminderEnablePumpEvent.self
        case .ChangeAlarmClockEnable:
            return ChangeAlarmClockEnablePumpEvent.self
        case .ChangeTempBasalType:
            return ChangeTempBasalTypePumpEvent.self
        case .ChangeAlarmNotifyMode:
            return ChangeAlarmNotifyModePumpEvent.self
        case .ChangeTimeFormat:
            return ChangeTimeFormatPumpEvent.self
        case .ChangeReservoirWarningTime:
            return ChangeReservoirWarningTimePumpEvent.self
        case .ChangeBolusReminderEnable:
            return ChangeBolusReminderEnablePumpEvent.self
        case .ChangeBolusReminderTime:
            return ChangeBolusReminderTimePumpEvent.self
        case .DeleteBolusReminderTime:
            return DeleteBolusReminderTimePumpEvent.self
        case .DeleteAlarmClockTime:
            return DeleteAlarmClockTimePumpEvent.self
        case .Model522ResultTotals:
            return Model522ResultTotalsPumpEvent.self
        case .Sara6E:
            return Sara6EPumpEvent.self
        case .ChangeCarbUnits:
            return ChangeCarbUnitsPumpEvent.self
        case .BasalProfileStart:
            return BasalProfileStartPumpEvent.self
        case .ChangeWatchdogEnable:
            return ChangeWatchdogEnablePumpEvent.self
        case .ChangeOtherDeviceID:
            return ChangeOtherDeviceIDPumpEvent.self
        case .ChangeWatchdogMarriageProfile:
            return ChangeWatchdogMarriageProfilePumpEvent.self
        case .DeleteOtherDeviceID:
            return DeleteOtherDeviceIDPumpEvent.self
        case .ChangeCaptureEventEnable:
            return ChangeCaptureEventEnablePumpEvent.self
        case .SelectBasalProfile:
            return SelectBasalProfilePumpEvent.self
        default:
            return PlaceholderPumpEvent.self
        }
    }
}

