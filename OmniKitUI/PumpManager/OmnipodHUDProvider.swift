//
//  OmnipodHUDProvider.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 11/26/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import OmniKit

internal class OmnipodHUDProvider: NSObject, HUDProvider, PodStateObserver {
    var managerIdentifier: String {
        return OmnipodPumpManager.managerIdentifier
    }
    
    private var podState: PodState? {
        didSet {
            guard visible else {
                return
            }

            guard oldValue != podState else {
                return
            }

            if oldValue?.lastInsulinMeasurements != podState?.lastInsulinMeasurements {
                updateReservoirView()
            }
            
            if oldValue?.fault != podState?.fault {
                updateFaultDisplay()
            }
            
            if oldValue != nil && podState == nil {
                updateReservoirView()
                updateFaultDisplay()
            }

            if (oldValue == nil || podState == nil) && (oldValue != nil || podState != nil) {
                updatePodLifeView()
            }
        }
    }
    
    private let pumpManager: OmnipodPumpManager
    
    private var reservoirView: OmnipodReservoirView?
    
    private var podLifeView: PodLifeHUDView?

    var visible: Bool = false {
        didSet {
            if oldValue != visible && visible {
                hudDidAppear()
            }
        }
    }
    
    public init(pumpManager: OmnipodPumpManager) {
        self.pumpManager = pumpManager
        self.podState = pumpManager.state.podState
        super.init()
        self.pumpManager.addPodStateObserver(self, queue: .main)
    }
    
    private func updateReservoirView() {
        if let lastInsulinMeasurements = podState?.lastInsulinMeasurements,
            let reservoirView = reservoirView,
            let podState = podState
        {
            let reservoirVolume = lastInsulinMeasurements.reservoirVolume

            let reservoirLevel = reservoirVolume?.asReservoirPercentage()

            var reservoirAlertState: ReservoirAlertState = .ok
            for (_, alert) in podState.activeAlerts {
                if case .lowReservoirAlarm = alert {
                    reservoirAlertState = .lowReservoir
                    break
                }
            }

            reservoirView.update(volume: reservoirVolume, at: lastInsulinMeasurements.validTime, level: reservoirLevel, reservoirAlertState: reservoirAlertState)
        }
    }
    
    private func updateFaultDisplay() {
        if let podLifeView = podLifeView {
            if podState?.fault != nil {
                podLifeView.alertState = .fault
            } else {
                podLifeView.alertState = .none
            }
        }
    }
    
    private func updatePodLifeView() {
        guard let podLifeView = podLifeView else {
            return
        }
        if let activatedAt = podState?.activatedAt, let expiresAt = podState?.expiresAt  {
            let lifetime = expiresAt.timeIntervalSince(activatedAt)
            podLifeView.setPodLifeCycle(startTime: activatedAt, lifetime: lifetime)
        } else {
            podLifeView.setPodLifeCycle(startTime: Date(), lifetime: 0)
        }
    }
    
    public func createHUDViews() -> [BaseHUDView] {
        self.reservoirView = OmnipodReservoirView.instantiate()
        self.updateReservoirView()

        podLifeView = PodLifeHUDView.instantiate()

        if visible {
            updatePodLifeView()
            updateFaultDisplay()
        }

        return [reservoirView, podLifeView].compactMap { $0 }
    }
    
    public func didTapOnHUDView(_ view: BaseHUDView) -> HUDTapAction? {
        if podState?.fault != nil {
            return HUDTapAction.presentViewController(PodReplacementNavigationController.instantiatePodReplacementFlow(pumpManager))
        } else {
            return HUDTapAction.presentViewController(pumpManager.settingsViewController())
        }
    }
    
    func hudDidAppear() {
        updatePodLifeView()
        updateReservoirView()
        updateFaultDisplay()
        pumpManager.refreshStatus()
    }

    func hudDidDisappear(_ animated: Bool) {
        if let podLifeView = podLifeView {
            podLifeView.pauseUpdates()
        }
    }
    
    public var hudViewsRawState: HUDProvider.HUDViewsRawState {
        var rawValue: HUDProvider.HUDViewsRawState = [:]
        
        if let podState = podState {
            rawValue["podActivatedAt"] = podState.activatedAt
            let lifetime: TimeInterval
            if let expiresAt = podState.expiresAt, let activatedAt = podState.activatedAt {
                lifetime = expiresAt.timeIntervalSince(activatedAt)
            } else {
                lifetime = 0
            }
            rawValue["lifetime"] = lifetime
            rawValue["alerts"] = podState.activeAlerts.values.map { $0.rawValue }
        }
        
        if let lastInsulinMeasurements = podState?.lastInsulinMeasurements, lastInsulinMeasurements.reservoirVolume != nil {
            rawValue["reservoirVolume"] = lastInsulinMeasurements.reservoirVolume
            rawValue["validTime"] = lastInsulinMeasurements.validTime
        }
        
        return rawValue
    }
    
    public static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView] {
        guard let podActivatedAt = rawValue["podActivatedAt"] as? Date,
            let lifetime = rawValue["lifetime"] as? Double,
            let rawAlerts = rawValue["alerts"] as? [PodAlert.RawValue] else
        {
            return []
        }
        
        let reservoirView: OmnipodReservoirView?
        
        let alerts = rawAlerts.compactMap { PodAlert.init(rawValue: $0) }
        let reservoirVolume = rawValue["reservoirVolume"] as? Double
        let validTime = rawValue["validTime"] as? Date
        
        if let validTime = validTime
        {
            reservoirView = OmnipodReservoirView.instantiate()
            let reservoirLevel = reservoirVolume?.asReservoirPercentage()
            var reservoirAlertState: ReservoirAlertState = .ok
            for alert in alerts {
                if case .lowReservoirAlarm = alert {
                    reservoirAlertState = .lowReservoir
                }
            }
            reservoirView!.update(volume: reservoirVolume, at: validTime, level: reservoirLevel, reservoirAlertState: reservoirAlertState)
        } else {
            reservoirView = nil
        }
        
        let podLifeHUDView = PodLifeHUDView.instantiate()
        podLifeHUDView.setPodLifeCycle(startTime: podActivatedAt, lifetime: lifetime)
        
        return [reservoirView, podLifeHUDView].compactMap({ $0 })
    }
    
    func podStateDidUpdate(_ podState: PodState?) {
        self.podState = podState
    }
}

extension Double {
    func asReservoirPercentage() -> Double {
        return min(1, max(0, self / Pod.reservoirCapacity))
    }
}
