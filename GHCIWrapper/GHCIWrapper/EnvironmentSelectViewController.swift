//
//  EnvironmentSelectViewController.swift
//  REPLWrapper
//
//  Created by Christian Lundtofte on 29/09/2016.
//  Copyright © 2016 Christian Lundtofte. All rights reserved.
//

import Cocoa

class EnvironmentSelectViewController: NSViewController {

    @IBOutlet var knownEnvironmentPopup:NSPopUpButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.knownEnvironmentPopup.removeAllItems()
        knownEnvironmentPopup.addItems(withTitles: EnvironmentHandler.shared.environmentNames)
    }
    
    @IBAction func saveEnvironment(sender: AnyObject?) {
        guard let selected = knownEnvironmentPopup.selectedItem?.title else { return }
        
        if !EnvironmentHandler.shared.environmentNames.contains(selected) {
            return
        }
        
        EnvironmentHandler.shared.saveEnvironment(env: selected)
        self.dismissViewController(self)
    }
}
