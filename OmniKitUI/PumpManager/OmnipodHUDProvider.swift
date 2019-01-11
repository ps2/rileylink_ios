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
    
    public weak var delegate: HUDProviderDelegate?
    
    private var podState: PodState? {
        didSet {
            if reservoirView == nil && podState?.lastInsulinMeasurements?.reservoirVolume != nil {
                reservoirView = OmnipodReservoirView.instantiate()
                delegate?.hudProvider(self, didAddHudViews: [reservoirView!])
            }
            
            if podLifeView == nil && podState != nil {
                podLifeView = PodLifeHUDView.instantiate()
                updatePodLifeView()
                delegate?.hudProvider(self, didAddHudViews: [podLifeView!])
            }
            
            if oldValue?.lastInsulinMeasurements != podState?.lastInsulinMeasurements {
                updateReservoirView()
            }
            
            if oldValue?.fault != podState?.fault {
                updateFaultDisplay()
            }
            
            if oldValue != nil && podState == nil {
                delegate?.hudProvider(self, didRemoveHudViews: [reservoirView, podLifeView].compactMap { $0 })
                podLifeView = nil
                reservoirView = nil
            }            
        }
    }
    
    private let pumpManager: OmnipodPumpManager
    
    private var reservoirView: OmnipodReservoirView?
    
    private var podLifeView: PodLifeHUDView?
    
    public init(pumpManager: OmnipodPumpManager) {
        self.pumpManager = pumpManager
        self.podState = pumpManager.state.podState
        super.init()
        self.pumpManager.addPodStateObserver(self)
    }
    
    private func updateReservoirView() {
        if let lastInsulinMeasurements = podState?.lastInsulinMeasurements,
            let reservoirVolume = lastInsulinMeasurements.reservoirVolume,
            let reservoirView = reservoirView,
            let podState = podState
        {
            let reservoirLevel = min(1, max(0, reservoirVolume / pumpManager.pumpReservoirCapacity))
            reservoirView.reservoirLevel = reservoirLevel
            let reservoirAlertState: ReservoirAlertState = podState.alarms.contains(.lowReservoir) ? .lowReservoir : .ok
            
            reservoirView.updateReservoir(volume: reservoirVolume, at: lastInsulinMeasurements.validTime, level: reservoirLevel, reservoirAlertState: reservoirAlertState)
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
        if let podLifeView = podLifeView, let podState = podState {
            let lifetime = podState.expiresAt.timeIntervalSince(podState.activatedAt)
            podLifeView.setPodLifeCycle(startTime: podState.activatedAt, lifetime: lifetime)
        }
    }
    
    public func createHUDViews() -> [BaseHUDView] {
        if podState?.lastInsulinMeasurements?.reservoirVolume != nil {
            self.reservoirView = OmnipodReservoirView.instantiate()
            self.updateReservoirView()
        }
        
        if podState != nil {
            podLifeView = PodLifeHUDView.instantiate()
        }
        updatePodLifeView()
        updateFaultDisplay()
        
        return [reservoirView, podLifeView].compactMap { $0 }
    }
    
    public func didTapOnHudView(_ view: BaseHUDView) -> HUDTapAction? {
        if let _ = view as? PodLifeHUDView {
            if podState?.fault != nil {
                return HUDTapAction.presentViewController(PodReplacementNavigationController.instantiatePodReplacementFlow(pumpManager))
            } else {
                return HUDTapAction.showViewController(pumpManager.settingsViewController())
            }

        }
        return nil
    }
    
    func hudDidAppear() {
        pumpManager.refreshStatus()
    }
    
    public var hudViewsRawState: HUDProvider.HUDViewsRawState {
        var rawValue: HUDProvider.HUDViewsRawState = [
            "pumpReservoirCapacity": pumpManager.pumpReservoirCapacity,
        ]
        
        if let podState = podState {
            rawValue["podActivatedAt"] = podState.activatedAt
            rawValue["lifetime"] = podState.expiresAt.timeIntervalSince(podState.activatedAt)
            rawValue["alarms"] = podState.alarms.rawValue
        }
        
        if let lastInsulinMeasurements = podState?.lastInsulinMeasurements, lastInsulinMeasurements.reservoirVolume != nil {
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
        
        let reservoirView: OmnipodReservoirView?
        
        let alarms = PodAlarmState(rawValue: rawAlarms)
        let reservoirVolume = rawValue["reservoirVolume"] as? Double
        let reservoirVolumeValidTime = rawValue["reservoirVolumeValidTime"] as? Date
        
        if let reservoirVolume = reservoirVolume,
            let reservoirVolumeValidTime = reservoirVolumeValidTime
        {
            reservoirView = OmnipodReservoirView.instantiate()
            let reservoirLevel = min(1, max(0, reservoirVolume / pumpReservoirCapacity))
            reservoirView!.reservoirLevel = reservoirLevel
            let reservoirAlertState: ReservoirAlertState = alarms.contains(.lowReservoir) ? .lowReservoir : .ok
            reservoirView!.updateReservoir(volume: reservoirVolume, at: reservoirVolumeValidTime, level: reservoirLevel, reservoirAlertState: reservoirAlertState)
        } else {
            reservoirView = nil
        }
        
        let podLifeHUDView = PodLifeHUDView.instantiate()
        podLifeHUDView.setPodLifeCycle(startTime: podActivatedAt, lifetime: lifetime)
        
        return [reservoirView, podLifeHUDView].compactMap({ $0 })
    }
    
    func podStateDidUpdate(_ podState: PodState?) {
        DispatchQueue.main.async {
            self.podState = podState
        }
    }
}
