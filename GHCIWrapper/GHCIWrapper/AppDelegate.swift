//
//  AppDelegate.swift
//  REPLWrapper
//
//  Created by Christian Lundtofte on 13/09/2016.
//  Copyright © 2016 Christian Lundtofte. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var environmentMenuItem:NSMenuItem!
    @IBOutlet var environmentMenu:NSMenu!
    var defaultSelectedEnvironment:String?

    // MARK: OS X App Delegate
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        let _ = EnvironmentHandler.shared
        for itemName in EnvironmentHandler.shared.environmentNames {
            let item = NSMenuItem(title: itemName, action: #selector(AppDelegate.selectedEnvironment(sender:)), keyEquivalent: "")
            
            if EnvironmentHandler.shared.hasEnvironment() && itemName == EnvironmentHandler.shared.selectedEnvironment! {
                item.state = NSOnState
                self.defaultSelectedEnvironment = itemName
            }
            
            environmentMenu.addItem(item)
        }
        print("Items: \(environmentMenu.items), antal: \(environmentMenu.numberOfItems)")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    
    // MARK: Environments
    func selectedEnvironment(sender: AnyObject?) {
        guard let item = sender as? NSMenuItem else { return }
        let title = item.title
        if title == defaultSelectedEnvironment {
            return
        }
        
        for item2 in environmentMenu.items {
            item2.state = NSOffState
        }
        
        item.state = NSOnState
        
        EnvironmentHandler.shared.selectedEnvironment = title
        EnvironmentHandler.shared.loadEnvironment()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "NewEnvironmentLoaded"), object: self, userInfo: nil)
    }
    
    
    

    // MARK: Menubar
    @IBAction func runClicked(_ sender: AnyObject?) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RunClicked"), object: nil)
    }
    
    @IBAction func openClicked(_ sender: AnyObject?) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "OpenClicked"), object: nil)
    }
    
    @IBAction func saveClicked(_ sender: AnyObject?) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "SaveClicked"), object: nil)
    }
    
    @IBAction func saveAsClicked(_ sender: AnyObject?) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "SaveAsClicked"), object: nil)
    }
}

