//
//  KeychainManager+Loop.swift
//
//  Created by Nate Racklyeft on 6/26/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


private let NightscoutAccount = "NightscoutAPI"


extension KeychainManager {
    
    func setNightscoutURL(URL: NSURL?, secret: String?) {
        do {
            let credentials: InternetCredentials?

            if let URL = URL, secret = secret {
                credentials = InternetCredentials(username: NightscoutAccount, password: secret, URL: URL)
            } else {
                credentials = nil
            }

            try replaceInternetCredentials(credentials, forAccount: NightscoutAccount)
        } catch {
        }
    }

    func getNightscoutCredentials() -> (URL: NSURL, secret: String)? {
        do {
            let credentials = try getInternetCredentials(account: NightscoutAccount)

            return (URL: credentials.URL, secret: credentials.password)
        } catch {
            return nil
        }
    }
}