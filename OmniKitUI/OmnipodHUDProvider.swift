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

internal class OmnipodHUDProvider: HUDProvider, PodStateObserver {
    var managerIdentifier: String {
        return OmnipodPumpManager.managerIdentifier
    }
    
    public weak var delegate: HUDProviderDelegate?
    
    private var podState: PodState {
        didSet {
            if oldValue.lastInsulinMeasurements?.reservoirVolume == nil && podState.lastInsulinMeasurements?.reservoirVolume != nil {
                reservoirView = OmnipodReservoirView.instantiate()
                delegate?.newHUDViewsAvailable([reservoirView!])
            }
            
            if oldValue.lastInsulinMeasurements != podState.lastInsulinMeasurements {
                updateReservoirView()
            }
        }
    }
    
    private let pumpManager: OmnipodPumpManager
    
    private var reservoirView: OmnipodReservoirView?
    
    private var podLifeView: PodLifeHUDView?
    
    public init(pumpManager: OmnipodPumpManager) {
        self.pumpManager = pumpManager
        self.podState = pumpManager.state.podState
        self.pumpManager.podStateObserver = self
    }
    
    private func updateReservoirView() {
        if let lastInsulinMeasurements = podState.lastInsulinMeasurements,
            let reservoirVolume = lastInsulinMeasurements.reservoirVolume,
            let reservoirView = reservoirView
        {
            let reservoirLevel = min(1, max(0, reservoirVolume / pumpManager.pumpReservoirCapacity))
            reservoirView.reservoirLevel = reservoirLevel
            let reservoirAlertState: ReservoirAlertState = podState.alarms.contains(.lowReservoir) ? .lowReservoir : .ok
            
            reservoirView.updateReservoir(volume: reservoirVolume, at: lastInsulinMeasurements.validTime, level: reservoirLevel, reservoirAlertState: reservoirAlertState)
        }
    }
    
    private func updatePodLifeView() {
        if let podLifeView = podLifeView {
            let lifetime = podState.expiresAt.timeIntervalSince(podState.activatedAt)
            podLifeView.setPodLifeCycle(startTime: podState.activatedAt, lifetime: lifetime)
        }
    }
    
    public func createHUDViews() -> [BaseHUDView] {
        if podState.lastInsulinMeasurements?.reservoirVolume != nil {
            self.reservoirView = OmnipodReservoirView.instantiate()
            self.updateReservoirView()
            self.delegate?.newHUDViewsAvailable([self.reservoirView!])
        }
        
        podLifeView = PodLifeHUDView.instantiate()
        updatePodLifeView()
        
        return [reservoirView, podLifeView].compactMap { $0 }
    }
    
    public func didTapOnHudView(_ view: BaseHUDView) -> HUDTapAction? {
        if let _ = view as? PodLifeHUDView {
            return HUDTapAction.showViewController(pumpManager.settingsViewController())
        }
        return nil
    }
    
    public var hudViewsRawState: HUDProvider.HUDViewsRawState {
        var rawValue: HUDProvider.HUDViewsRawState = [
            "pumpReservoirCapacity": pumpManager.pumpReservoirCapacity,
            "podActivatedAt": podState.activatedAt,
            "lifetime": podState.expiresAt.timeIntervalSince(podState.activatedAt),
            "alarms": podState.alarms.rawValue
        ]
        
        if let lastInsulinMeasurements = podState.lastInsulinMeasurements {
            rawValue["reservoirVolume"] = lastInsulinMeasurements.reservoirVolume
            rawValue["reservoirVolumeValidTime"] = lastInsulinMeasurements.validTime
        }
        
        return rawValue
    }
    
    public static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView] {
        guard let pumpReservoirCapacity = rawValue["pumpReservoirCapacity"] as? Double,
            let podActivatedAt = rawValue["podActivatedAt"] as? Date,
            let lifetime = rawValue["lifetime"] as? Double,
            let rawAlarms = rawValue["alarms"] as? UInt8 else
        {
            return []
        }
        
        let alarms = PodAlarmState(rawValue: rawAlarms)
        let reservoirVolume = rawValue["reservoirVolume"] as? Double
        let reservoirVolumeValidTime = rawValue["reservoirVolumeValidTime"] as? Date
        
        
        let reservoirView = OmnipodReservoirView.instantiate()
        if let reservoirVolume = reservoirVolume,
            let reservoirVolumeValidTime = reservoirVolumeValidTime
        {
            let reservoirLevel = min(1, max(0, reservoirVolume / pumpReservoirCapacity))
            reservoirView.reservoirLevel = reservoirLevel
            let reservoirAlertState: ReservoirAlertState = alarms.contains(.lowReservoir) ? .lowReservoir : .ok
            reservoirView.updateReservoir(volume: reservoirVolume, at: reservoirVolumeValidTime, level: reservoirLevel, reservoirAlertState: reservoirAlertState)
        }
        
        let podLifeHUDView = PodLifeHUDView.instantiate()
        podLifeHUDView.setPodLifeCycle(startTime: podActivatedAt, lifetime: lifetime)
        
        return [reservoirView, podLifeHUDView]
    }
    
    func didUpdatePodState(_ podState: PodState) {
        DispatchQueue.main.async {
            self.podState = podState
        }
    }
}
