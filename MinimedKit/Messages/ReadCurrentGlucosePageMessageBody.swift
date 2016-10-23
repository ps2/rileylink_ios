//
//  ReadCurrentGlucosePageMessageBody.swift
//  RileyLink
//
//  Created by Timothy Mecklem on 10/19/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public class ReadCurrentGlucosePageMessageBody: CarelinkLongMessageBody {
    
    public let pageNum: UInt32
    public let glucose: Int
    public let isig: Int
    
    public required init?(rxData: Data) {
        guard rxData.count == type(of: self).length else {
            return nil
        }
        
        self.pageNum = rxData.subdata(in: 1..<5).withUnsafeBytes({ (bytes: UnsafePointer<UInt32>) -> UInt32 in
            return UInt32(bigEndian: bytes.pointee)
        })
        self.glucose = Int(rxData[6] as UInt8)
        self.isig = Int(rxData[8] as UInt8)
        
        super.init(rxData: rxData)
    }
}
