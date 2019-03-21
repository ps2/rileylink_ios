//
//  MinimedDoseProgressEstimator.swift
//  MinimedKit
//
//  Created by Pete Schwamb on 3/14/19.
//  Copyright © 2019 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

class MinimedDoseProgressEstimator: DoseProgressEstimator {

    public let dose: DoseEntry

    public let pumpModel: PumpModel

    private var observers = WeakSet<DoseProgressObserver>()

    private var lock = os_unfair_lock()

    private var timer: Timer?

    var progress: DoseProgress {
        let elapsed = -dose.startDate.timeIntervalSinceNow
        let duration = dose.endDate.timeIntervalSince(dose.startDate)
        let timeProgress = min(elapsed / duration, 1)

        let updateResolution: Double
        let unroundedVolume: Double

        if pumpModel.variableDeliveryRate {
            if dose.units < 1 {
                updateResolution = 40 // Resolution = 0.025
                unroundedVolume = timeProgress * dose.units
            } else {
                var remainingUnits = dose.units
                var baseDuration: TimeInterval = 0
                var overlay1Duration: TimeInterval = 0
                var overlay2Duration: TimeInterval = 0
                let baseDeliveryRate = 1.5 / TimeInterval(minutes: 1)

                baseDuration = min(duration, remainingUnits / baseDeliveryRate)
                remainingUnits -= baseDuration * baseDeliveryRate

                overlay1Duration = min(duration, remainingUnits / baseDeliveryRate)
                remainingUnits -= overlay1Duration * baseDeliveryRate

                overlay2Duration = min(duration, remainingUnits / baseDeliveryRate)
                remainingUnits -= overlay2Duration * baseDeliveryRate

                unroundedVolume = (min(elapsed, baseDuration) + min(elapsed, overlay1Duration) + min(elapsed, overlay2Duration)) * baseDeliveryRate

                if overlay1Duration > elapsed {
                    updateResolution = 10 // Resolution = 0.1
                } else {
                    updateResolution = 20 // Resolution = 0.05
                }
            }

        } else {
            updateResolution = 20 // Resolution = 0.05
            unroundedVolume = timeProgress * dose.units
        }
        let roundedVolume = round(unroundedVolume * updateResolution) / updateResolution
        return DoseProgress(deliveredUnits: roundedVolume, percentComplete: roundedVolume / dose.units)
    }

    init(dose: DoseEntry, pumpModel: PumpModel) {
        self.dose = dose
        self.pumpModel = pumpModel
    }

    func addObserver(_ observer: DoseProgressObserver) {
        os_unfair_lock_lock(&lock)
        defer {
            os_unfair_lock_unlock(&lock)
        }
        let firstObserver = observers.isEmpty
        observers.insert(observer)
        if firstObserver {
            start(on: RunLoop.main)
        }
    }

    func removeObserver(_ observer: DoseProgressObserver) {
        os_unfair_lock_lock(&lock)
        defer {
            os_unfair_lock_unlock(&lock)
        }
        observers.remove(observer)
        if observers.isEmpty {
            stop()
        }
    }

    private func notify() {
        os_unfair_lock_lock(&lock)
        defer {
            os_unfair_lock_unlock(&lock)
        }
        for observer in self.observers {
            observer.doseProgressEstimatorHasNewEstimate(self)
        }
    }

    private func start(on runLoop: RunLoop) {
        let timeSinceStart = dose.startDate.timeIntervalSinceNow
        let duration = dose.endDate.timeIntervalSince(dose.startDate)
        let timeBetweenPulses = duration / (Double(pumpModel.pulsesPerUnit) * dose.units)

        let delayUntilNextPulse = timeBetweenPulses - timeSinceStart.remainder(dividingBy: timeBetweenPulses)
        let timer = Timer(fire: Date() + delayUntilNextPulse, interval: timeBetweenPulses, repeats: true) { [weak self] _  in
            if let self = self {
                self.notify()
            }
        }
        runLoop.add(timer, forMode: .default)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
    }
}
