//
//  PodLifeHUDView.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 10/22/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import UIKit
import LoopKitUI

public class PodLifeHUDView: BaseHUDView, NibLoadable {
    
    @IBOutlet private weak var timeLabel: UILabel!
    @IBOutlet private weak var progressRing: RingProgressView!
    
    @IBOutlet private weak var alertLabel: UILabel! {
        didSet {
            alertLabel.alpha = 0
            alertLabel.textColor = UIColor.white
            alertLabel.layer.cornerRadius = 9
            alertLabel.clipsToBounds = true
        }
    }

    private var startTime: Date?
    private var lifetime: TimeInterval?
    private var timer: Timer?
    
    public class func instantiate() -> PodLifeHUDView {
        return nib().instantiate(withOwner: nil, options: nil)[0] as! PodLifeHUDView
    }
    
    public func setPodLifeCycle(startTime: Date, lifetime: TimeInterval) {
        self.startTime = startTime
        self.lifetime = lifetime
        
        update()
    }
    
    override open func stateColorsDidUpdate() {
        super.stateColorsDidUpdate()
        update()
    }
    
    private var endColor: UIColor? {
        didSet {
            let primaryColor = endColor ?? UIColor(red: 198 / 255, green: 199 / 255, blue: 201 / 255, alpha: 1)
            self.progressRing.endColor = primaryColor
            self.progressRing.startColor = primaryColor
        }
    }
    
    private lazy var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        
        formatter.allowedUnits = [.hour, .minute]
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = .abbreviated
        
        return formatter
    }()

    
    private func update() {
        if let startTime = startTime, let lifetime = lifetime {
            let age = -startTime.timeIntervalSinceNow
            let progress = Double(age / lifetime)
            progressRing.progress = progress
            
            if progress < 0.75 {
                self.endColor = stateColors?.normal
                progressRing.shadowOpacity = 0
            } else if progress < 1.0 {
                self.endColor = stateColors?.warning
                progressRing.shadowOpacity = 1
            } else {
                self.endColor = stateColors?.error
                progressRing.shadowOpacity = 1
            }
            
            let remaining = (lifetime - age)
            //let remaining = TimeInterval(days: 3) * (1-progress)

            if remaining > .hours(24) {
                timeLabel.isHidden = true
                caption.text = LocalizedString("Pod Age", comment: "Label describing pod age view")
            } else if remaining > 0 {
                if let timeString = timeFormatter.string(from: remaining) {
                    timeLabel.isHidden = false
                    timeLabel.text = timeString
                }
                caption.text = LocalizedString("Remaining", comment: "Label describing time remaining view")
            } else {
                timeLabel.isHidden = true
                caption.text = LocalizedString("Replace Pod", comment: "Label indicating pod replacement necessary")
            }
        }
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        
        timer = Timer.scheduledTimer(withTimeInterval: .seconds(10), repeats: true) { [weak self] _ in
            self?.update()
        }
    }
}
