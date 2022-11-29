//
//  MinimedPumpSettingsViewModel.swift
//  MinimedKitUI
//
//  Created by Pete Schwamb on 11/29/22.
//  Copyright © 2022 Pete Schwamb. All rights reserved.
//

import Foundation
import MinimedKit

class MinimedPumpSettingsViewModel: ObservableObject {

    var pumpManager: MinimedPumpManager

    init(pumpManager: MinimedPumpManager) {
        self.pumpManager = pumpManager
    }

    var pumpImage: UIImage {
        return pumpManager.state.largePumpImage
    }

    func deletePump() {
        
    }

    func didFinish() {
        
    }
}

