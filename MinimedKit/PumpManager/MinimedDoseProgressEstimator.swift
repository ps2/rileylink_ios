//
//  MinimedDoseProgressEstimator.swift
//  MinimedKit
//
//  Created by Pete Schwamb on 3/14/19.
//  Copyright © 2019 Pete Schwamb. All rights reserved.
//

import Foundation
import LoopKit

class MinimedDoseProgressEstimator: DoseProgressTimerEstimator {

    let dose: DoseEntry

    public let pumpModel: PumpModel

    override var progress: DoseProgress {
        let elapsed = -dose.startDate.timeIntervalSinceNow
        let duration = dose.endDate.timeIntervalSince(dose.startDate)
        let timeProgress = min(elapsed / duration, 1)

        let updateResolution: Double
        let unroundedVolume: Double

        if pumpModel.isDeliveryRateVariable {
            if dose.programmedUnits < 1 {
                updateResolution = 40 // Resolution = 0.025
                unroundedVolume = timeProgress * dose.programmedUnits
            } else {
                var remainingUnits = dose.programmedUnits
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
            unroundedVolume = timeProgress * dose.programmedUnits
        }
        let roundedVolume = round(unroundedVolume * updateResolution) / updateResolution
        return DoseProgress(deliveredUnits: roundedVolume, percentComplete: roundedVolume / dose.programmedUnits)
    }

    init(dose: DoseEntry, pumpModel: PumpModel, reportingQueue: DispatchQueue) {
        self.dose = dose
        self.pumpModel = pumpModel
        super.init(reportingQueue: reportingQueue)
    }

    override func timerParameters() -> (delay: TimeInterval, repeating: TimeInterval) {
        let timeSinceStart = -dose.startDate.timeIntervalSinceNow
        let duration = dose.endDate.timeIntervalSince(dose.startDate)
        let timeBetweenPulses = duration / (Double(pumpModel.pulsesPerUnit) * dose.programmedUnits)

        let delayUntilNextPulse = timeBetweenPulses - timeSinceStart.remainder(dividingBy: timeBetweenPulses)
        
        return (delay: delayUntilNextPulse, repeating: timeBetweenPulses)
    }
}
