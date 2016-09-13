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
    
    // Filhåndtering
    var isFileOpen:Bool = false
    
    // UI komponenter
    @IBOutlet var consoleLogView:NSTextView!
    @IBOutlet var commandView:NSTextField!
    @IBOutlet var codeTextView:NSTextView!
    
    
    // MARK: OS X vinduer
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.runCode(_:)), name: "RunClicked", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.openFileClicked), name: "OpenClicked", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.saveFileClicked), name: "SaveClicked", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.saveAsFileClicked), name: "SaveAsClicked", object: nil)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Find GHCi sti eller bed brugeren om at finde den
        GHCIPath = tryFindGHCIPath()
        if GHCIPath == nil {
            showNoGHCIError()
            return
        }
        
        setupNewGHCITask(nil)
    }
    
    override var representedObject: AnyObject? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    
    // MARK: Knapper
    @IBAction func sendCommand(sender: AnyObject?) {
        if let d = (commandView.stringValue+"\n").dataUsingEncoding(NSUTF8StringEncoding) {
            commandView.stringValue = ""
            writeHandle?.writeData(d)
        }
    }
    
    @IBAction func runCode(sender: AnyObject?) {
        saveAndRunCode()
    }
    
    func openFileClicked() {
        if isFileOpen {
            showFileOpenWarning()
            return
        }
        
        
    }
    
    func saveFileClicked() {
        
    }
    
    func saveAsFileClicked() {
        
    }
    
    
    // MARK: Andet UI
    func showNoGHCIError() {
        let window = NSApplication.sharedApplication().windows[0]
        
        let alert = NSAlert()
        alert.messageText = "No CHGi found"
        alert.informativeText = "GHCi was not found. Would you like to locate the executable yourself?"
        alert.alertStyle = .CriticalAlertStyle
        alert.addButtonWithTitle("Yes")
        alert.addButtonWithTitle("No")
        
        alert.beginSheetModalForWindow(window) { (response) in
            if response == NSAlertFirstButtonReturn {
                self.userFindGGHCI()
            }
            else {
                self.disableUI()
            }
        }
    }
    
    func showFileOpenWarning() {
        let alert = NSAlert()
        alert.informativeText = "File open"
        alert.messageText = "A file is currently open. Are you sure you want to open a new one?"
        alert.addButtonWithTitle("Yes")
        alert.addButtonWithTitle("No")
        
        alert.beginSheetModalForWindow(NSApplication.sharedApplication().windows[0]) { (resp) in
            if resp == NSAlertFirstButtonReturn {
                self.userSelectOpenFile()
            }
        }
    }
    
    
    func userFindGGHCI() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canSelectHiddenExtension = true
        panel.title = "Locate and select GHCi executable"
        panel.prompt = "Use"
        
        panel.beginSheetModalForWindow(NSApplication.sharedApplication().windows[0]) { (response) in
            if let selectedURL = panel.URL {
                if self.testGHCIURL(selectedURL) { // HVis URL'en er korrekt, så gem og fortsæt
                    print("Gemmer sti: \(selectedURL)")
                    NSUserDefaults.standardUserDefaults().setValue(selectedURL.absoluteString, forKey: "GHCiPath")
                    NSUserDefaults.standardUserDefaults().synchronize()
                    
                    self.enableUI()
                }
                else { // Lad ham prøve igen..
                    self.showNoGHCIError()
                }
            }
        }
    }
    
    func disableUI() {
        commandView.enabled = false
        codeTextView.editable = false
    }
    
    func enableUI() {
        commandView.enabled = true
        codeTextView.editable = true
    }
    
    func resetUI() {
        killGHCI()
        
        codeTextView.clear()
        consoleLogView.clear()
        
        //commandView.stringValue = ""
    }
    
    
    // MARK: Filhåndtering
    func saveAndRunCode() {
        let cont = (codeTextView.textStorage as NSAttributedString!).string
        do {
            let path = NSTemporaryDirectory()+"tmp.hs"
            try cont.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding)
            consoleLogView.clear()
            
            runHaskellFile(NSURL(string: path)!)
            commandView.becomeFirstResponder()
        }
        catch { }
    }

    func userSelectOpenFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["hs", "lhs", "o", "so"]
        
        panel.beginSheetModalForWindow(NSApplication.sharedApplication().windows[0]) { (resp) in
            if let URL = panel.URL {
                do {
                    let cont = try String(contentsOfURL: URL, encoding: NSUTF8StringEncoding)
                    self.codeTextView.setText(cont)
                    self.consoleLogView.clear()
                    
                    // TODO: Opdater filvariabler
                }
                catch {
                    // TODO: Håndter fejl..
                }
            }
        }
    }
    
    // MARK: Task og pipes
    // Tester om det der er på en sti er GHCi
    func testGHCIURL(URL: NSURL) -> Bool {
        guard let path = URL.path else { return false }
        if !NSFileManager.defaultManager().fileExistsAtPath(path) {
            print("Ingen fil på valgt placering: \(path)")
            return false
        }
        
        // Kør app og se om det ser rigtigt ud
        let pipe = NSPipe()
        let file = pipe.fileHandleForReading
        
        let task = NSTask()
        task.launchPath = URL.path
        task.arguments = ["--version"]
        task.standardOutput = pipe
        
        task.launch()
        
        let data = file.readDataToEndOfFile()
        file.closeFile()
        
        if let string = String(data: data, encoding: NSUTF8StringEncoding) {
            // Meget naivt.. :P
            if string.containsString("Haskell") {
                return true
            }
        }
        
        
        return false
    }
    
    // Forsøger at finde GHCi ud fra kendte stier
    func tryFindGHCIPath() -> String? {
        // Har vi den gemt allerede?
        if let remembered = NSUserDefaults.standardUserDefaults().valueForKey("GHCiPath") as? String {
            if NSFileManager.defaultManager().fileExistsAtPath(remembered) {
                return remembered
            }
        }
        
        // Forsøg at finde stien
        let defaultLocations = ["/usr/local/bin/ghci", "/usr/bin/ghci", "~/Library/Haskell/bin/ghci"]
        var foundLoc:String?
        
        for loc in defaultLocations {
            if NSFileManager.defaultManager().fileExistsAtPath(loc) {
                print("Fundet GHCI ved: \(loc)")
                
                foundLoc = loc
                break
            }
        }
        
        // Gem lokalt hvis ikke gjort før
        if foundLoc != nil && NSUserDefaults.standardUserDefaults().valueForKey("GHCiPath") == nil {
            print("Gemmer sti!")
            NSUserDefaults.standardUserDefaults().setValue(foundLoc, forKey: "GHCiPath")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
        
        return foundLoc
    }
    
    // Laver ny, ren GHCi task
    func setupNewGHCITask(arguments: [String]?) {
        guard let path = GHCIPath else { return }
        
        proc = NSTask()
        proc?.launchPath = path
        proc?.arguments = arguments
        
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
    
    func runHaskellFile(file: NSURL) {
        guard let filePath = file.path else { return }
        setupNewGHCITask([filePath])
    }
    
    // Stopper nuværende task og pipes
    func killGHCI() {
        proc?.terminate()
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSFileHandleDataAvailableNotification, object: readHandle)
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
}

