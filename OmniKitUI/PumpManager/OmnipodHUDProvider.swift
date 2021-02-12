//
//  OmnipodHUDProvider.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 11/26/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import UIKit
import SwiftUI
import LoopKit
import LoopKitUI
import OmniKit

internal class OmnipodHUDProvider: NSObject, HUDProvider, PodStateObserver {
    var managerIdentifier: String {
        return pumpManager.managerIdentifier
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
            
            if oldValue != nil && podState == nil {
                updateReservoirView()
            }
        }
    }
    
    private let pumpManager: OmnipodPumpManager
    
    private var reservoirView: OmnipodReservoirView?
    
    var visible: Bool = false {
        didSet {
            if oldValue != visible && visible {
                hudDidAppear()
            }
        }
    }
    
    private let colorPalette: LoopUIColorPalette
    
    public init(pumpManager: OmnipodPumpManager, colorPalette: LoopUIColorPalette) {
        self.pumpManager = pumpManager
        self.podState = pumpManager.state.podState
        self.colorPalette = colorPalette
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
        
    public func createHUDView() -> LevelHUDView? {
        self.reservoirView = OmnipodReservoirView.instantiate()
        self.updateReservoirView()

        return reservoirView
    }
    
    public func didTapOnHUDView(_ view: BaseHUDView) -> HUDTapAction? {
        if podState?.fault != nil {
            return HUDTapAction.presentViewController(PodReplacementNavigationController.instantiatePodReplacementFlow(pumpManager))
        } else {
            return HUDTapAction.presentViewController(pumpManager.settingsViewController(colorPalette: colorPalette))
        }
    }
    
    func hudDidAppear() {
        updateReservoirView()
        pumpManager.refreshStatus()
    }

    public var hudViewRawState: HUDProvider.HUDViewRawState {
        var rawValue: HUDProvider.HUDViewRawState = [:]
        
        if let podState = podState {
            rawValue["alerts"] = podState.activeAlerts.values.map { $0.rawValue }
        }
        
        if let lastInsulinMeasurements = podState?.lastInsulinMeasurements {
            rawValue["reservoirVolume"] = lastInsulinMeasurements.reservoirVolume
            rawValue["validTime"] = lastInsulinMeasurements.validTime
        }
        
        return rawValue
    }
    
    public static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> LevelHUDView? {
        guard let rawAlerts = rawValue["alerts"] as? [PodAlert.RawValue] else {
            return nil
        }
        
        let alerts = rawAlerts.compactMap { PodAlert.init(rawValue: $0) }
        let reservoirVolume = rawValue["reservoirVolume"] as? Double
        let validTime = rawValue["validTime"] as? Date
        
        let reservoirView = OmnipodReservoirView.instantiate()
        if let validTime = validTime
        {
            let reservoirLevel = reservoirVolume?.asReservoirPercentage()
            var reservoirAlertState: ReservoirAlertState = .ok
            for alert in alerts {
                if case .lowReservoirAlarm = alert {
                    reservoirAlertState = .lowReservoir
                }
            }
            reservoirView.update(volume: reservoirVolume, at: validTime, level: reservoirLevel, reservoirAlertState: reservoirAlertState)
        }
                
        return reservoirView
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
