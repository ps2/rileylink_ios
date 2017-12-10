//
//  CRC16Tests.swift
//  RileyLink
//
//  Created by Pete Schwamb on 2/27/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import XCTest
@testable import MinimedKit


class CRC16Tests: XCTestCase {
    
    func testComputeCRC16() {
        let input = Data(hexadecimalString: "5be409a20a1510325000784b502800a400002400a8965c0b404fc038cbd008d5d0010080008000240009a24a15107b0500800c1510180a000ade19a32c15105bde2ba30c1510325000b44b5024006c0000200070965c0b4c78c03482c040c8c001007000700020002ba34c15100a0c22932d75903f2122938d7510c527ad5b0006900f15101a5000b44b500000380000000038965c0e70a1c04c19d03423d04069d00100380038000c0006904f15107b060080101510200e005b0034ab1015100d5000784b500000280000000028965c113858c070f8c04c70d0347ad040c0d00100280028001c0034ab5015100ab005863175903f360586117510c527ad5bb01486111510005100784b50940000000038005c965c14281fc0386fc0700fd04c87d03491d040d7d001005c005c00380014865115105b002291121510285000784b500000840000000084965c145c48c02866c038b6c07056d04cced034d8d0010084008400480022915215107b0700801315102610002100038414151003000000360785341510064a097e009e54b5100c4a03a11415107b0704a11415102610007b0704a11415102610007b0710a1141510261000030003000306a11415100ae937a23475103f1d37a2347510c527ad5be91ea3141510165000784b502c00480000140060965c0e848cc05cd2c028f0c03840d001006000600014001ea35415107b0800801515102a13000a5621ba3515905b5623ba151510005100b455505800000000340024965c116053c084dfc05c25d02843d03893d0010024002400340023ba5515105b00188c161510005000b455500000000000000000965c142411c06061c084edc05c33d02851d038a1d00100180018004c00188c56151000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")!
        XCTAssertTrue(0x803a == computeCRC16(input))
    }
}
