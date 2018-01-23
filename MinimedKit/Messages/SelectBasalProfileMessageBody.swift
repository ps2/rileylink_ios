//
//  SelectBasalProfileMessageBody.swift
//  MinimedKit
//
//  Copyright © 2017 Pete Schwamb. All rights reserved.
//

import Foundation

public class SelectBasalProfileMessageBody: CarelinkLongMessageBody {
    public convenience init(newProfile: BasalProfile) {
        self.init(rxData: Data(bytes: [1, newProfile.rawValue]))!
    }
}
