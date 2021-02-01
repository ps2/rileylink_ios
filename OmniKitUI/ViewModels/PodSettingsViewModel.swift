//
//  PodSettingsViewModel.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 1/31/21.
//  Copyright © 2021 Pete Schwamb. All rights reserved.
//

import SwiftUI
import OmniKit
import LoopKit
import HealthKit

struct BasalDeliveryRate {
    var absoluteRate: Double
    var netPercent: Double
}

enum PodSettingsViewAlert {
    case suspendError(Error)
    case resumeError(Error)
}

public protocol PodVersionProtocol {
    var lot: UInt32 { get }
    var tid: UInt32 { get }
    var piVersion: String { get }
    var pmVersion: String { get }
}

extension PodState: PodVersionProtocol {
}

class PodSettingsViewModel: ObservableObject {
    
    @Published var lifeState: PodLifeState
    
    @Published var activatedAt: Date?
    
    @Published var basalDeliveryState: PumpManagerStatus.BasalDeliveryState?

    @Published var basalDeliveryRate: Double?

    @Published var activeAlert: PodSettingsViewAlert? = nil {
        didSet {
            if activeAlert != nil {
                alertIsPresented = true
            }
        }
    }

    @Published var alertIsPresented: Bool = false {
        didSet {
            if !alertIsPresented {
                activeAlert = nil
            }
        }
    }
    
    @Published var reservoirLevel: ReservoirLevel?
    
    var timeZone: TimeZone {
        return pumpManager.status.timeZone
    }
    
    var podVersion: PodVersionProtocol? {
        return pumpManager.state.podState
    }
    
    var viewTitle: String {
        return pumpManager.localizedTitle
    }
    
    let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .medium
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter
    }()
    
    let timeFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .none
        return dateFormatter
    }()

    let basalRateFormatter: NumberFormatter = {
        let unit = HKUnit.internationalUnit()
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 1
        numberFormatter.minimumIntegerDigits = 1
        return numberFormatter
    }()
    
    let reservoirVolumeFormatter = QuantityFormatter(for: .internationalUnit())
    
    var didFinish: (() -> Void)?
    
    private let pumpManager: OmnipodPumpManager
    
    init(pumpManager: OmnipodPumpManager) {
        self.pumpManager = pumpManager
        
        lifeState = pumpManager.lifeState
        activatedAt = pumpManager.state.podState?.activatedAt
        basalDeliveryState = pumpManager.status.basalDeliveryState
        basalDeliveryRate = pumpManager.basalDeliveryRate
        
        if let reservoirLevel = pumpManager.state.podState?.lastInsulinMeasurements?.reservoirLevel {
            self.reservoirLevel = .valid(reservoirLevel)
        } else {
            reservoirLevel = .aboveThreshold
        }
        
        pumpManager.addPodStateObserver(self, queue: DispatchQueue.main)
    }
    
    func changeTimeZoneTapped() {
        pumpManager.setTime { (error) in
            // TODO: handle error
            self.lifeState = self.pumpManager.lifeState
        }
    }
    
    func doneTapped() {
        self.didFinish?()
    }
    
    func stopUsingOmnipodTapped() {
        self.pumpManager.notifyDelegateOfDeactivation {
            DispatchQueue.main.async {
                self.didFinish?()
            }
        }
    }
    
    func suspendDelivery(duration: TimeInterval) {
//        guard let reminder = try? StopProgramReminder(value: duration) else {
//            assertionFailure("Invalid StopProgramReminder duration of \(duration)")
//            return
//        }

//        pumpManager.suspendDelivery(withReminder: reminder) { (error) in
        pumpManager.suspendDelivery { (error) in
            if let error = error {
                self.activeAlert = .suspendError(error)
            }
        }
    }
    
    func resumeDelivery() {
        pumpManager.resumeDelivery { (error) in
            if let error = error {
                self.activeAlert = .resumeError(error)
            }
        }
    }
    
    var podOk: Bool {
        guard basalDeliveryState != nil else { return false }
        
        switch lifeState {
        case .noPod, .podFault, .podActivating, .podDeactivating:
            return false
        default:
            return true
        }
    }
    
    func reservoirText(for level: ReservoirLevel) -> String {
        switch level {
        case .aboveThreshold:
            let quantity = HKQuantity(unit: .internationalUnit(), doubleValue: Pod.maximumReservoirReading)
            let thresholdString = reservoirVolumeFormatter.string(from: quantity, for: .internationalUnit(), includeUnit: false) ?? ""
            let unitString = reservoirVolumeFormatter.string(from: .internationalUnit(), forValue: Pod.maximumReservoirReading)
            return String(format: LocalizedString("%1$@+ %2$@", comment: "Format string for reservoir level above max measurable threshold. (1: measurable reservoir threshold) (2: units)"),
                          thresholdString, unitString)
        case .valid(let value):
            let quantity = HKQuantity(unit: .internationalUnit(), doubleValue: value)
            return reservoirVolumeFormatter.string(from: quantity, for: .internationalUnit()) ?? ""
        }
    }
}

extension PodSettingsViewModel: PodStateObserver {
    func podStateDidUpdate(_ state: PodState?) {
        lifeState = self.pumpManager.lifeState
        basalDeliveryState = self.pumpManager.status.basalDeliveryState
        basalDeliveryRate = self.pumpManager.basalDeliveryRate
        if let reservoirLevel = state?.lastInsulinMeasurements?.reservoirLevel {
            self.reservoirLevel = .valid(reservoirLevel)
        } else {
            self.reservoirLevel = .aboveThreshold
        }
    }
}

extension OmnipodPumpManager {
    var lifeState: PodLifeState {
        guard let podState = state.podState else {
            return .noPod
        }
        
        if let fault = podState.fault {
            return .podFault(fault.faultEventCode)
        }
        
        if podState.setupProgress != .completed {
            return .podActivating
        }
        
        if let activationTime = podState.activatedAt {
            let timeActive = Date().timeIntervalSince(activationTime)
            if timeActive < Pod.nominalPodLife {
                return .timeRemaining(Pod.nominalPodLife - timeActive)
            } else {
                return .expiredFor(timeActive - Pod.nominalPodLife)
            }
        }
        return .podDeactivating
    }
    
    var basalDeliveryRate: Double? {
        guard let _ = state.podState else {
            return nil
        }
        
        switch self.status.basalDeliveryState {
        case .tempBasal(let dose):
            return dose.unitsPerHour
        case .suspended:
            return 0
        default:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = state.timeZone
            return state.basalSchedule.currentRate(using: calendar, at: Date())
        }
    }
}

extension PumpManagerStatus.BasalDeliveryState {
    var headerText: String {
        switch self {
        case .active, .suspending:
             return LocalizedString("Scheduled Basal", comment: "Header text for basal delivery view when scheduled basal active")
        case .tempBasal:
             return LocalizedString("Temporary Basal", comment: "Header text for basal delivery view when temporary basal running")
        case .suspended, .resuming:
            return LocalizedString("Basal Suspended", comment: "Header text for basal delivery view when basal is suspended")
        default:
            return ""
        }
    }
    
    var suspendResumeActionText: String {
        switch self {
        case .active, .tempBasal, .cancelingTempBasal, .initiatingTempBasal:
            return LocalizedString("Suspend Insulin Delivery", comment: "Text for suspend resume button when insulin delivery active")
        case .suspending:
            return LocalizedString("Suspending insulin delivery...", comment: "Text for suspend resume button when insulin delivery is suspending")
        case .suspended:
            return LocalizedString("Tap to Resume Insulin Delivery", comment: "Text for suspend resume button when insulin delivery is suspended")
        case .resuming:
            return LocalizedString("Resuming insulin delivery...", comment: "Text for suspend resume button when insulin delivery is resuming")
        }
    }
    
    var transitioning: Bool {
        switch self {
        case .suspending, .resuming:
            return true
        default:
            return false
        }
    }
    
    var suspendResumeActionColor: Color {
        switch self {
        case .suspending, .resuming:
            return Color.secondary
        default:
            return Color.accentColor
        }
    }
}

extension BasalSchedule {

    // Only valid for fixed offset timezones
    public func currentRate(using calendar: Calendar, at date: Date = Date()) -> Double {
        let midnight = calendar.startOfDay(for: date)
        return rateAt(offset: date.timeIntervalSince(midnight))
    }
}

