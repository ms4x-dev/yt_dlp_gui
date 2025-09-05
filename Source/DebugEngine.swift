//
//  DebugEngine.swift
//  yt_dlp_gui
//
//  Created by Richard on 5/9/2025.
//

import SwiftUI

struct DebugEngine {
    static func logInfo(_ message: String, guiBinding: Binding<String>? = nil) {
        let logMessage = "INFO: \(message)"
        print(logMessage)
        if let guiBinding = guiBinding {
            guiBinding.wrappedValue += logMessage + "\n"
        }
    }

    static func logSuccess(_ message: String, guiBinding: Binding<String>? = nil) {
        let logMessage = "SUCCESS: \(message)"
        print(logMessage)
        if let guiBinding = guiBinding {
            guiBinding.wrappedValue += logMessage + "\n"
        }
    }

    static func logError(_ message: String, guiBinding: Binding<String>? = nil) {
        let logMessage = "ERROR: \(message)"
        print(logMessage)
        if let guiBinding = guiBinding {
            guiBinding.wrappedValue += logMessage + "\n"
        }
    }
}
