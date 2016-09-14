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
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        let logFileURL = applicationDocumentsDirectory().URLByAppendingPathComponent("logfile.txt")
        
        do {
            try NSFileManager.defaultManager().removeItemAtURL(logFileURL!)
        } catch let error {
            NSLog("Could not remove file at path: \(logFileURL): \(error)")
        }
        
        // Just instantiate the DeviceDataManager
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            DeviceDataManager.sharedManager
        }
        
        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        NSLog(#function)
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        NSLog(#function)
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        NSLog(#function)
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        NSLog(#function)
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        NSLog(#function)
    }
    
    // MARK: - Notifications
    
    func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        
    }
    
    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, withResponseInfo responseInfo: [NSObject : AnyObject], completionHandler: () -> Void) {
        
        completionHandler()
    }
    
    // MARK: - 3D Touch
    
    func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
        completionHandler(false)
    }
    
    // MARK: - Core Data
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        guard let managedObjectModel = { () -> NSManagedObjectModel? in
            let modelURL = NSBundle.mainBundle().URLForResource("RileyLink", withExtension: "momd")!
            return NSManagedObjectModel(contentsOfURL: modelURL)
            }() else {
                return nil
        }
        
        guard let coordinator = { () -> NSPersistentStoreCoordinator? in
            let storeURL = applicationDocumentsDirectory().URLByAppendingPathComponent("RileyLink.sqlite")
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            
            try! coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: nil)
            
            return coordinator
            }() else {
                return nil
        }
        
        let context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }()
}


private func applicationDocumentsDirectory() -> NSURL {
    return NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).last!
}

