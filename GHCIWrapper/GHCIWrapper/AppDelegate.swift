//
//  AppDelegate.swift
//  GHCIWrapper
//
//  Created by Christian Lundtofte on 13/09/2016.
//  Copyright © 2016 Christian Lundtofte. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application

    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
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

