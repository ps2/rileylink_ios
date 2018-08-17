//
//  RileyLinkVisualDesign.swift
//  RileyLinkKitUI
//
//  Created by Pete Schwamb on 8/13/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public class VisualDesign {
    public class func rileyLinkImage(compatibleWith traitCollection: UITraitCollection) -> UIImage? {
        let bundle = Bundle(for: self)
        return UIImage(named: "RileyLink", in: bundle, compatibleWith: traitCollection)
    }
    
    public class func rileyLinkTint(compatibleWith traitCollection: UITraitCollection) -> UIColor? {
        let bundle = Bundle(for: self)
        return UIColor(named: "RileyLink Tint", in: bundle, compatibleWith: traitCollection)
    }

}

