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
    var proc:Process?
    
    var outputPipe:Pipe?
    var errorPipe:Pipe?
    var readHandle:FileHandle?
    var errorHandle:FileHandle?
    
    var inputPipe:Pipe?
    var writeHandle:FileHandle?
    
    var previousCommands:Array<String> = []
    var prevIndex:Int = 0
    
    // Filhåndtering
    var isFileOpen:Bool = false
    var currentFileOpen:String?
    let haskellFileTypes:Array<String> = ["hs", "lhs", "o", "so"]
    
    // UI komponenter
    @IBOutlet var consoleLogView:NSTextView!
    @IBOutlet var commandView:CommandTextField!
    @IBOutlet var codeTextView:NSTextView!
    
    
    // MARK: OS X vinduer
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.runCode(_:)), name: NSNotification.Name(rawValue: "RunClicked"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.openFileClicked), name: NSNotification.Name(rawValue: "OpenClicked"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.saveFileClicked), name: NSNotification.Name(rawValue: "SaveClicked"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.saveAsFileClicked), name: NSNotification.Name(rawValue: "SaveAsClicked"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.upPushed), name: NSNotification.Name(rawValue: "UpPushed"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.downPushed), name: NSNotification.Name(rawValue: "DownPushed"), object: nil)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Find GHCi sti eller bed brugeren om at finde den
        GHCIPath = tryFindGHCIPath()
        if GHCIPath == nil {
            showNoGHCIError()
            return
        }
        
        setupNewGHCITask([])
    }

    
    // MARK: Knapper
    @IBAction func sendCommand(_ sender: AnyObject?) {
        let str = commandView.stringValue
        
        if let d = (str+"\n").data(using: String.Encoding.utf8) {
            consoleLogView.append(str+"\n")
            previousCommands.append(str)
            
            prevIndex = -1
            
            commandView.stringValue = ""
            writeHandle?.write(d)
        }
    }
    
    @IBAction func runCode(_ sender: AnyObject?) {
        saveAndRunCode()
    }
    
    // Filhåndteringsknapper
    func writeCodeToFile(file: String) {
        // Find indhold og skriv til disk
        let cont = (codeTextView.textStorage as NSAttributedString!).string
        do {
            try cont.write(toFile: file, atomically: true, encoding: String.Encoding.utf8)
        }
        catch { }
    }
    
    func openFileClicked() {
        if isFileOpen {
            showFileOpenWarning()
            return
        }
        
        userSelectOpenFile()
    }
    
    func saveFileClicked() {
        // Hvis ingen fil åben, så bed bruger om at lave ny
        if !isFileOpen {
            saveAsFileClicked()
            return
        }
        
        guard let file = currentFileOpen else { return }
        self.writeCodeToFile(file: file)
    }
    
    func saveAsFileClicked() {
        let panel = NSSavePanel()
        panel.allowedFileTypes = haskellFileTypes
        if currentFileOpen != nil {
            panel.nameFieldStringValue = currentFileOpen!
        }
        
        panel.beginSheetModal(for: NSApplication.shared().windows[0]) { (res) in
            if res == 1 {
                guard let URL = panel.url else { return }
                
                self.currentFileOpen = URL.path
                self.isFileOpen = true
                
                self.setWindowTitle()
                self.writeCodeToFile(file: URL.path)
            }
        }
    }
    
    // Up og ned knapper til kommandoer
    func upPushed() {
        if previousCommands.count == 0 {
            return
        }
        
        prevIndex += 1
        
        // Find index og sæt kommando
        let index = (previousCommands.count-1)-prevIndex
        if index <= previousCommands.count-1 && index >= 0 {
            let cmd = previousCommands[index]
            commandView.stringValue = cmd
        }
        else {
            prevIndex -= 1
        }
    }
    
    func downPushed() {
        if previousCommands.count == 0 {
            return
        }
        if prevIndex == -1 {
            return
        }
        
        prevIndex -= 1
        
        if prevIndex == -1 {
            commandView.stringValue = ""
            return
        }
        
        let index = (previousCommands.count-1)-prevIndex
        if index <= previousCommands.count-1 && index >= 0 {
            let cmd = previousCommands[index]
            commandView.stringValue = cmd
        }
        else {
            prevIndex += 1
        }
    }
    
    
    // MARK: Andet UI
    func showNoGHCIError() {
        let window = NSApplication.shared().windows[0]
        
        let alert = NSAlert()
        alert.messageText = "No CHGi found"
        alert.informativeText = "GHCi was not found. Would you like to locate the executable yourself?"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        
        alert.beginSheetModal(for: window, completionHandler: { (response) in
            if response == NSAlertFirstButtonReturn {
                self.userFindGGHCI()
            }
            else {
                self.disableUI()
            }
        }) 
    }
    
    func showFileOpenWarning() {
        let alert = NSAlert()
        alert.messageText = "File open"
        alert.informativeText = "A file is currently open. Are you sure you want to open a new one?"
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        
        alert.beginSheetModal(for: NSApplication.shared().windows[0], completionHandler: { (resp) in
            if resp == NSAlertFirstButtonReturn {
                self.userSelectOpenFile()
            }
        }) 
    }
    
    // Lad brugeren finde GHCi selv
    func userFindGGHCI() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canSelectHiddenExtension = true
        panel.title = "Locate and select GHCi executable"
        panel.prompt = "Use"
        
        panel.beginSheetModal(for: NSApplication.shared().windows[0]) { (response) in
            if let selectedURL = panel.url {
                if self.testGHCIURL(selectedURL) { // HVis URL'en er korrekt, så gem og fortsæt
                    print("Gemmer sti: \(selectedURL)")
                    UserDefaults.standard.setValue(selectedURL.absoluteString, forKey: "GHCiPath")
                    UserDefaults.standard.synchronize()
                    
                    self.enableUI()
                }
                else { // Lad ham prøve igen..
                    self.showNoGHCIError()
                }
            }
        }
    }
    
    func disableUI() {
        commandView.isEnabled = false
        codeTextView.isEditable = false
    }
    
    func enableUI() {
        commandView.isEnabled = true
        codeTextView.isEditable = true
    }
    
    func resetUI() {
        killGHCI()
        //previousCommands.removeAll()
        
        codeTextView.clear()
        consoleLogView.clear()
        
        //commandView.stringValue = ""
    }
    
    func setWindowTitle() {
        if isFileOpen && currentFileOpen != nil {
            self.view.window?.title = "GHCi UI - "+currentFileOpen!
        }
        else {
            self.view.window?.title = "GHCi UI"
        }
    }
    
    
    // MARK: Filhåndtering
    func saveAndRunCode() {
        let cont = (codeTextView.textStorage as NSAttributedString!).string
        do {
            let path = NSTemporaryDirectory()+"tmp.hs"
            try cont.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
            consoleLogView.clear()
            
            runHaskellFile(URL(string: path)!)
            commandView.becomeFirstResponder()
        }
        catch { }
    }

    func userSelectOpenFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = haskellFileTypes
        
        panel.beginSheetModal(for: NSApplication.shared().windows[0]) { (resp) in
            if resp == 1 {
                if let URL = panel.url {
                    do {
                        let cont = try String(contentsOf: URL, encoding: String.Encoding.utf8)
                        self.codeTextView.setText(cont)
                        self.consoleLogView.clear()
                        
                        self.currentFileOpen = URL.path
                        self.isFileOpen = true
                        self.setWindowTitle()
                    }
                    catch {
                        // TODO: Håndter fejl..
                    }
                }
            }
        }
    }
    
    
    // MARK: Task og pipes
    // Tester om det der er på en sti er GHCi
    func testGHCIURL(_ URL: Foundation.URL) -> Bool {
        let path = URL.path
        if !FileManager.default.fileExists(atPath: path) {
            print("Ingen fil på valgt placering: \(path)")
            return false
        }
        
        // Kør app og se om det ser rigtigt ud
        let pipe = Pipe()
        let file = pipe.fileHandleForReading
        
        let task = Process()
        task.launchPath = URL.path
        task.arguments = ["--version"]
        task.standardOutput = pipe
        
        task.launch()
        
        let data = file.readDataToEndOfFile()
        file.closeFile()
        
        if let string = String(data: data, encoding: String.Encoding.utf8) {
            // Meget naivt.. :P
            if string.contains("Haskell") {
                return true
            }
        }
        
        
        return false
    }
    
    // Forsøger at finde GHCi ud fra kendte stier
    func tryFindGHCIPath() -> String? {
        // Har vi den gemt allerede?
        if let remembered = UserDefaults.standard.value(forKey: "GHCiPath") as? String {
            if FileManager.default.fileExists(atPath: remembered) {
                return remembered
            }
        }
        
        // Forsøg at finde stien
        let defaultLocations = ["/usr/local/bin/ghci", "/usr/bin/ghci", "~/Library/Haskell/bin/ghci"]
        var foundLoc:String?
        
        for loc in defaultLocations {
            if FileManager.default.fileExists(atPath: loc) {
                print("Fundet GHCI ved: \(loc)")
                
                foundLoc = loc
                break
            }
        }
        
        // Gem lokalt hvis ikke gjort før
        if foundLoc != nil && UserDefaults.standard.value(forKey: "GHCiPath") == nil {
            print("Gemmer sti!")
            UserDefaults.standard.setValue(foundLoc, forKey: "GHCiPath")
            UserDefaults.standard.synchronize()
        }
        
        return foundLoc
    }
    
    // Laver ny, ren GHCi task
    func setupNewGHCITask(_ arguments: [String]) {
        guard let path = GHCIPath else { return }
        
        proc = Process()
        proc?.launchPath = path
        proc?.arguments = arguments
        
        // Output pipe (Det vi modtager fra ghci)
        outputPipe = Pipe()
        errorPipe = Pipe()
        proc?.standardOutput = outputPipe
        proc?.standardError = errorPipe
        
        readHandle = outputPipe?.fileHandleForReading
        readHandle?.waitForDataInBackgroundAndNotify()
        
        errorHandle = errorPipe?.fileHandleForReading
        errorHandle?.waitForDataInBackgroundAndNotify()
        
        // Input (Det vi skriver)
        inputPipe = Pipe()
        proc?.standardInput = inputPipe
        
        writeHandle = inputPipe?.fileHandleForWriting
        
        // Så vi får notifkation ved output
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.receivedData(_:)), name: NSNotification.Name.NSFileHandleDataAvailable, object: readHandle)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.receivedErrorData(_:)), name: NSNotification.Name.NSFileHandleDataAvailable, object: errorHandle)
        
        proc?.launch()
        commandView.becomeFirstResponder()
    }
    
    func runHaskellFile(_ file: URL) {
        let filePath = file.path
        setupNewGHCITask([filePath])
    }
    
    // Stopper nuværende task og pipes
    func killGHCI() {
        proc?.terminate()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSFileHandleDataAvailable, object: readHandle)
    }
    
    
    // Kaldes når der modtages data i vores handle (Dvs. app'en outputter noget)
    func receivedData(_ notif: Notification) {
        guard let fh = notif.object as? FileHandle else { print("Fuck"); return }
        
        let data = fh.availableData
        if data.count > 0 {
            readHandle?.waitForDataInBackgroundAndNotify()
            fh.waitForDataInBackgroundAndNotify()
            
            if let str = String(data: data, encoding: String.Encoding.utf8) {
                consoleLogView.append(str)
            }
        }
    }
    
    // Kaldes når der modtages en error i vores handle
    func receivedErrorData(_ notif: Notification) {
        guard let fh = notif.object as? FileHandle else { print("Fuck"); return }
        
        let data = fh.availableData
        if data.count > 0 {
            errorHandle?.waitForDataInBackgroundAndNotify()
            fh.waitForDataInBackgroundAndNotify()
            
            if let str = String(data: data, encoding: String.Encoding.utf8) {
                consoleLogView.appendError(str)
            }
        }
    }
}

