//
//  Either.swift
//  RileyLink
//
//  Created by Pete Schwamb on 3/19/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import Foundation

public enum Either<T1, T2> {
    case success(T1)
    case failure(T2)
}
