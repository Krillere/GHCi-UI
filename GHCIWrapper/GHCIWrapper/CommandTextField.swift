//
//  URLTextField.swift
//  JSON Viewer
//
//  Created by Christian on 15/01/2016.
//  Copyright © 2016 Christian Lundtofte Sørensen. All rights reserved.
//

import Cocoa

class CommandTextField: NSTextField {
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        
        // Drawing code here.
    }
    
    func handleCommandEvent(theEvent: NSEvent) -> Bool {
        
        let responder = self.window?.firstResponder
        let textView = responder as! NSTextView
        let range = textView.selectedRange
        let bHasSelectedTexts = (range.length > 0)
        
        let keyCode = theEvent.keyCode
        var bHandled = false
        
        //6 Z, 7 X, 8 C, 9 V, A 0
        if keyCode == 6 {
            if theEvent.modifierFlags.contains(NSEventModifierFlags.ShiftKeyMask) {
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
    
    override func performKeyEquivalent(theEvent: NSEvent) -> Bool {
        
        // Command (c/p, select og undo/redo)
        if theEvent.type == .KeyDown && theEvent.modifierFlags.contains(NSEventModifierFlags.CommandKeyMask) {
            let responder = self.window?.firstResponder
            
            if responder != nil && responder is NSTextView {
                
                let bHandled = handleCommandEvent(theEvent)
                
                if bHandled {
                    return true
                }
            }
        }
        else if theEvent.type == .KeyDown { // Anden tast
            if theEvent.keyCode == 126 {
                NSNotificationCenter.defaultCenter().postNotificationName("UpPushed", object: self)
            }
        }
        
        
        return false
    }
    
}
