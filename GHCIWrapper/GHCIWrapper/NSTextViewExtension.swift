//
//  NSTextViewExtension.swift
//  REPLWrapper
//
//  Created by Christian Lundtofte on 13/09/2016.
//  Copyright © 2016 Christian Lundtofte. All rights reserved.
//

import Foundation
import Cocoa

extension NSTextView {
    func append(_ string: String) {
        self.textStorage?.append(NSAttributedString(string: string))
        self.scrollToEndOfDocument(nil)
    }
    func appendError(_ string: String) {
        let str = NSAttributedString(string: string, attributes: [NSForegroundColorAttributeName:NSColor.red])
        self.textStorage?.append(str)
        self.scrollToEndOfDocument(nil)
    }
    func clear() {
        self.textStorage?.setAttributedString(NSAttributedString(string: ""))
    }
    func setText(_ text: String) {
        self.textStorage?.setAttributedString(NSAttributedString(string: text))
        
        let f = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: 0)
        self.textStorage?.font = f
        self.typingAttributes = [NSFontAttributeName : f]
    }
}
