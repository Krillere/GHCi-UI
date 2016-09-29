//
//  ViewController.swift
//  REPLWrapper
//
//  Created by Christian Lundtofte on 13/09/2016.
//  Copyright © 2016 Christian Lundtofte. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    // REPL variabler
    var REPLPath:String?
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
    
    // UI komponenter
    @IBOutlet var consoleLogView:NSTextView!
    @IBOutlet var commandView:CommandTextField!
    @IBOutlet var codeTextView:NSTextView!
    
    
    // MARK: OS X vinduer
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let f = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: 0)
        codeTextView.textStorage?.font = f
        codeTextView.typingAttributes = [NSFontAttributeName : f]
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.runCode(_:)),
                                               name: NSNotification.Name(rawValue: "RunClicked"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.openFileClicked),
                                               name: NSNotification.Name(rawValue: "OpenClicked"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.saveFileClicked),
                                               name: NSNotification.Name(rawValue: "SaveClicked"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.saveAsFileClicked),
                                               name: NSNotification.Name(rawValue: "SaveAsClicked"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.upPushed),
                                               name: NSNotification.Name(rawValue: "UpPushed"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.downPushed),
                                               name: NSNotification.Name(rawValue: "DownPushed"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.newEnvironment),
                                               name: NSNotification.Name(rawValue: "NewEnvironmentLoaded"), object: nil)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Har vi sat environment?
        if !EnvironmentHandler.shared.hasEnvironment() {
            self.showSelectEnvironmentWindow()
            return
        }
        
        // Find sti eller bed brugeren om at finde den
        REPLPath = tryFindREPLPath()
        if REPLPath == nil {
            showNoExecutableError()
            return
        }
        
        setupNewREPLTask([])
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
        panel.allowedFileTypes = EnvironmentHandler.shared.selectedEnvironmentFileTypes
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
    func showNoExecutableError() {
        guard let env = EnvironmentHandler.shared.selectedEnvironment else { return }
        let window = NSApplication.shared().windows[0]
        
        let alert = NSAlert()
        alert.messageText = "No executable found"
        alert.informativeText = "An executable for the environment \(env) was not found. Would you like to locate the executable yourself?"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        
        alert.beginSheetModal(for: window, completionHandler: { (response) in
            if response == NSAlertFirstButtonReturn {
                self.userFindExecutable()
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
    
    func showSelectEnvironmentWindow() {
        self.performSegue(withIdentifier: "SelectEnvironment", sender: self)
    }
    
    // Lad brugeren finde REPL selv
    func userFindExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canSelectHiddenExtension = true
        panel.title = "Locate and select executable"
        panel.prompt = "Use"
        
        panel.beginSheetModal(for: NSApplication.shared().windows[0]) { (response) in
            if let selectedURL = panel.url {
                if self.testREPLURL(selectedURL) { // HVis URL'en er korrekt, så gem og fortsæt
                    print("Gemmer sti: \(selectedURL)")
                    UserDefaults.standard.setValue(selectedURL.absoluteString, forKey: "REPLPath")
                    UserDefaults.standard.synchronize()
                    
                    self.enableUI()
                }
                else { // Lad ham prøve igen..
                    self.showNoExecutableError()
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
        killREPL()
        //previousCommands.removeAll()
        
        REPLPath = tryFindREPLPath()
        if REPLPath == nil {
            showNoExecutableError()
            return
        }
        
        codeTextView.clear()
        consoleLogView.clear()
    }
    
    func setWindowTitle() {
        var add = ""
        if let env = EnvironmentHandler.shared.selectedEnvironment {
            add = " (\(env))"
        }
        if isFileOpen && currentFileOpen != nil {
            self.view.window?.title = "REPL UI\(add) - "+currentFileOpen!
        }
        else {
            self.view.window?.title = "REPL UI\(add)"
        }
    }
    
    
    // MARK: Filhåndtering
    func saveAndRunCode() {
        let cont = (codeTextView.textStorage as NSAttributedString!).string
        do {
            let path = NSTemporaryDirectory()+"tmp"
            try cont.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
            consoleLogView.clear()
            
            runWithFile(URL(string: path)!)
            commandView.becomeFirstResponder()
        }
        catch { }
    }

    func userSelectOpenFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = EnvironmentHandler.shared.selectedEnvironmentFileTypes
        
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
    func newEnvironment() {
        resetUI()
        
        setupNewREPLTask([])
    }
    
    // Tester om det der er på en sti er rigtigt
    func testREPLURL(_ URL: Foundation.URL) -> Bool {
        let path = URL.path
        
        if !FileManager.default.fileExists(atPath: path) {
            print("Ingen fil på valgt placering: \(path)")
            return false
        }
        
        return true
    }
    
    // Forsøger at finde REPL ud fra kendte stier
    func tryFindREPLPath() -> String? {
        // Har vi den gemt allerede?
        if let remembered = UserDefaults.standard.value(forKey: "CustomREPLPath") as? String {
            if FileManager.default.fileExists(atPath: remembered) {
                return remembered
            }
        }
        
        if !EnvironmentHandler.shared.hasEnvironment() {
            return nil
        }
        
        // Forsøg at finde stien
        let defaultLocations = EnvironmentHandler.shared.defaultPaths
        print("Mine default paths: \(defaultLocations)")
        var foundLoc:String?
        
        for loc in defaultLocations {
            if FileManager.default.fileExists(atPath: loc) {
                print("Fundet REPL ved: \(loc)")
                
                foundLoc = loc
                break
            }
        }
        
        
        // Gem lokalt hvis ikke gjort før
        /*if foundLoc != nil && UserDefaults.standard.value(forKey: "CustomREPLPath") == nil {
            print("Gemmer sti!")
            UserDefaults.standard.setValue(foundLoc, forKey: "CustomREPLPath")
            UserDefaults.standard.synchronize()
        }*/
        
        return foundLoc
    }
    
    // Laver ny, ren REPL task
    func setupNewREPLTask(_ arguments: [String]) {
        guard let path = REPLPath else { return }
        
        print("Starter: \(REPLPath)")
        proc = Process()
        proc?.launchPath = path
        proc?.arguments = arguments
        
        // Output pipe (Det vi modtager)
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
    
    func runWithFile(_ file: URL) {
        if let loadArg = EnvironmentHandler.shared.selectedEnvironmentLoadingArgument {
            let filePath = file.path
            
            setupNewREPLTask([loadArg, filePath])
        }
    }
    
    // Stopper nuværende task og pipes
    func killREPL() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSFileHandleDataAvailable, object: readHandle)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSFileHandleDataAvailable, object: errorHandle)
        
        proc?.terminate()
        proc?.waitUntilExit()
        
        proc = nil
        outputPipe = nil
        errorPipe = nil
        readHandle = nil
        errorHandle = nil
        
        inputPipe = nil
        writeHandle = nil
        print("Dræbt process!")
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

