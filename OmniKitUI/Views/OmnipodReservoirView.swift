//
//  OmnipodReservoirView.swift
//  OmniKit
//
//  Created by Pete Schwamb on 10/22/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import UIKit
import LoopKitUI
import OmniKit

public final class OmnipodReservoirView: LevelHUDView, NibLoadable {

    @IBOutlet private weak var volumeLabel: UILabel!
    
    public class func instantiate() -> OmnipodReservoirView {
        return nib().instantiate(withOwner: nil, options: nil)[0] as! OmnipodReservoirView
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        self.alpha = 0.0
        self.isHidden = true
        volumeLabel.isHidden = true
    }

    public var reservoirLevel: Double? {
        didSet {
            if oldValue == nil && reservoirLevel != nil {
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 1, animations: {
                        self.alpha = 1.0
                        self.isHidden = false
                    })
                }
            }
            level = reservoirLevel

            switch reservoirLevel {
            case .none:
                volumeLabel.isHidden = true
            case let x? where x > 0.25:
                volumeLabel.isHidden = true
            case let x? where x > 0.10:
                volumeLabel.textColor = tintColor
                volumeLabel.isHidden = false
            default:
                volumeLabel.textColor = tintColor
                volumeLabel.isHidden = false
            }
        }
    }

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        return formatter
    }()

    private lazy var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        return formatter
    }()

    public func setReservoirVolume(volume: Double, at date: Date) {
        if let units = numberFormatter.string(from: volume) {
            volumeLabel.text = String(format: LocalizedString("%@U", comment: "Format string for reservoir volume. (1: The localized volume)"), units)
            let time = timeFormatter.string(from: date)
            caption?.text = time

            accessibilityValue = String(format: LocalizedString("%1$@ units remaining at %2$@", comment: "Accessibility format string for (1: localized volume)(2: time)"), units, time)
        }
    }
}

extension OmnipodReservoirView: ReservoirVolumeObserver {
    public func reservoirVolumeDidChange(_ units: Double, at validTime: Date, level: Double?) {
        DispatchQueue.main.async {
            self.reservoirLevel = level
            self.setReservoirVolume(volume: units, at: validTime)
        }
    }
}

