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



    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application

    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


    // MARK: Menubar
    @IBAction func runClicked(sender: AnyObject?) {
        NSNotificationCenter.defaultCenter().postNotificationName("RunClicked", object: nil)
    }
    
    @IBAction func openClicked(sender: AnyObject?) {
        NSNotificationCenter.defaultCenter().postNotificationName("OpenClicked", object: nil)
    }
    
    @IBAction func saveClicked(sender: AnyObject?) {
        NSNotificationCenter.defaultCenter().postNotificationName("SaveClicked", object: nil)
    }
    
    @IBAction func saveAsClicked(sender: AnyObject?) {
        NSNotificationCenter.defaultCenter().postNotificationName("SaveAsClicked", object: nil)
    }
}

