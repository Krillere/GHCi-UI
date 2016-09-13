//
//  ViewController.swift
//  GHCIWrapper
//
//  Created by Christian Lundtofte on 13/09/2016.
//  Copyright © 2016 Christian Lundtofte. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    // GHCI variabler
    var GHCIPath:String?
    var proc:NSTask?
    
    var outputPipe:NSPipe?
    var readHandle:NSFileHandle?
    
    var inputPipe:NSPipe?
    var writeHandle:NSFileHandle?
    
    // UI
    @IBOutlet var consoleLogView:NSTextView!
    @IBOutlet var commandView:NSTextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        GHCIPath = tryFindGHCIPath()
        setupNewGHCITask()
        // Do any additional setup after loading the view.
    }
    
    override var representedObject: AnyObject? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    // MARK: UI
    @IBAction func sendCommand(sender: AnyObject?) {
        if let d = (commandView.stringValue+"\n").dataUsingEncoding(NSUTF8StringEncoding) {
            commandView.stringValue = ""
            writeHandle?.writeData(d)
        }
    }

    
    // MARK: Task og pipes
    func tryFindGHCIPath() -> String? {
        let defaultLocations = ["/usr/local/bin/ghci", "/usr/bin/ghci", "~/Library/Haskell/bin/ghci"]
        var foundLoc:String?
        
        for loc in defaultLocations {
            if NSFileManager.defaultManager().fileExistsAtPath(loc) {
                print("Fundet GHCI ved: \(loc)")
                
                foundLoc = loc
                break
            }
        }
        
        return foundLoc
    }
    
    func setupNewGHCITask() {
        guard let path = GHCIPath else { return }
        
        proc = NSTask()
        proc?.launchPath = path
        
        // Output pipe (Det vi modtager fra ghci)
        outputPipe = NSPipe()
        proc?.standardOutput = outputPipe
        proc?.standardError = outputPipe
        
        readHandle = outputPipe?.fileHandleForReading
        readHandle?.waitForDataInBackgroundAndNotify()
        
        // Input (Det vi skriver)
        inputPipe = NSPipe()
        proc?.standardInput = inputPipe
        
        writeHandle = inputPipe?.fileHandleForWriting
        
        // Så vi får notifkation ved output
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.receivedData(_:)), name: NSFileHandleDataAvailableNotification, object: readHandle)
        
        proc?.launch()
    }
    
    // Kaldes når der modtages data i vores handle (Dvs. app'en outputter noget)
    func receivedData(notif: NSNotification) {
        guard let fh = notif.object as? NSFileHandle else { print("Fuck"); return }
        
        let data = fh.availableData
        if data.length > 0 {
            readHandle?.waitForDataInBackgroundAndNotify()
            fh.waitForDataInBackgroundAndNotify()
            
            if let str = String(data: data, encoding: NSUTF8StringEncoding) {
                consoleLogView.append(str)
            }
        }
        else {
            print("Noget gik galt..")
        }
    }


    // ghci --version
}

