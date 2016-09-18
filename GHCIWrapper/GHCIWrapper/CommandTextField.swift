//
//  URLTextField.swift
//  JSON Viewer
//
//  Created by Christian on 15/01/2016.
//  Copyright © 2016 Christian Lundtofte Sørensen. All rights reserved.
//

import Cocoa

class CommandTextField: NSTextField {
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Drawing code here.
    }
    
    func handleCommandEvent(_ theEvent: NSEvent) -> Bool {
        
        let responder = self.window?.firstResponder
        let textView = responder as! NSTextView
        let range = textView.selectedRange
        let bHasSelectedTexts = (range.length > 0)
        
        let keyCode = theEvent.keyCode
        var bHandled = false
        
        //6 Z, 7 X, 8 C, 9 V, A 0
        if keyCode == 6 {
            if theEvent.modifierFlags.contains(NSEventModifierFlags.shift) {
                if ((textView.undoManager?.canRedo) != nil) {
                    textView.undoManager?.redo()
                    bHandled = true
                }
            }
            else {
                if ((textView.undoManager?.canUndo) != nil) {
                    textView.undoManager?.undo()
                    bHandled = true
                }
            }
        }
        else if keyCode == 7 && bHasSelectedTexts {
            textView.cut(self)
            bHandled = true
        }
        else if keyCode == 8 && bHasSelectedTexts {
            textView.copy(self)
            bHandled = true
        }
        else if keyCode == 9 {
            textView.paste(self)
            bHandled = true
        }
        else if keyCode == 0 {
            textView.selectAll(self)
            bHandled = true
        }
        
        return bHandled
    }
    
    override func performKeyEquivalent(with theEvent: NSEvent) -> Bool {
        
        // Command (c/p, select og undo/redo)
        if theEvent.type == .keyDown && theEvent.modifierFlags.contains(NSEventModifierFlags.command) {
            let responder = self.window?.firstResponder
            
            if responder != nil && responder is NSTextView {
                
                let bHandled = handleCommandEvent(theEvent)
                
                if bHandled {
                    return true
                }
            }
        }
        else if theEvent.type == .keyDown { // Anden tast
            if theEvent.keyCode == 126 {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "UpPushed"), object: self)
            }
            else if theEvent.keyCode == 125 {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "DownPushed"), object: self)
            }
        }
        
        
        return false
    }
    
}
