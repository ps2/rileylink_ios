//
//  Image.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 1/31/21.
//  Copyright © 2021 Pete Schwamb. All rights reserved.
//

import SwiftUI

private class FrameworkBundle {
    static let main = Bundle(for: FrameworkBundle.self)
}

extension Image {
    init(frameworkImage name: String, decorative: Bool = false) {
        if decorative {
            self.init(decorative: name, bundle: FrameworkBundle.main)
        } else {
            self.init(name, bundle: FrameworkBundle.main)
        }
    }
}
