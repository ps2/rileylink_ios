//
//  AppDelegate.swift
//  RileyLink
//
//  Created by Nathan Racklyeft on 4/22/16.
//  Copyright © 2016 Pete Schwamb. All rights reserved.
//

import UIKit
import CoreData
import RileyLinkKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let logFileURL = applicationDocumentsDirectory().appendingPathComponent("logfile.txt")
        
        do {
            try FileManager.default.removeItem(at: logFileURL)
        } catch let error {
            NSLog("Could not remove file at path: \(logFileURL): \(error)")
        }
        
        // Just instantiate the DeviceDataManager
        let delayTime = DispatchTime.now() + .seconds(1)
        DispatchQueue.main.asyncAfter(deadline: delayTime) {
            _ = DeviceDataManager.sharedManager
        }
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        NSLog(#function)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        NSLog(#function)
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        NSLog(#function)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        NSLog(#function)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        NSLog(#function)
    }
    
    // MARK: - Notifications
    
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        
    }
    
    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, withResponseInfo responseInfo: [AnyHashable: Any], completionHandler: @escaping () -> Void) {
        
        completionHandler()
    }
    
    // MARK: - 3D Touch
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(false)
    }
    
    // MARK: - Core Data
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        guard let managedObjectModel = { () -> NSManagedObjectModel? in
            let modelURL = Bundle.main.url(forResource: "RileyLink", withExtension: "momd")!
            return NSManagedObjectModel(contentsOf: modelURL)
            }() else {
                return nil
        }
        
        guard let coordinator = { () -> NSPersistentStoreCoordinator? in
            let storeURL = applicationDocumentsDirectory().appendingPathComponent("RileyLink.sqlite")
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            
            try! coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
            
            return coordinator
            }() else {
                return nil
        }
        
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }()
}


private func applicationDocumentsDirectory() -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
}

