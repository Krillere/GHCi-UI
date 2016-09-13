//
//  NSTextViewExtension.swift
//  GHCIWrapper
//
//  Created by Christian Lundtofte on 13/09/2016.
//  Copyright © 2016 Christian Lundtofte. All rights reserved.
//

import Foundation
import Cocoa

extension NSTextView {
    func append(string: String) {
        self.textStorage?.appendAttributedString(NSAttributedString(string: string))
        self.scrollToEndOfDocument(nil)
    }
    func clear() {
        self.textStorage?.setAttributedString(NSAttributedString(string: ""))
    }
}