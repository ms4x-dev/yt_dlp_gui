//
//  PythonManager.swift
//  yt_dlp_gui
//
//  Created by Richard on 4/9/2025.
//

import Foundation    // Needed for Bundle, Process, Pipe, DispatchQueue
import SwiftUI

class PythonManager {
    static let shared = PythonManager()

    func runScript(url: String, guiBinding: Binding<String>, progressCallback: @escaping (String) -> Void) {
        DebugEngine.logInfo("Attempting to locate Python binary and script...")

        guard let pythonPath = Bundle.main.path(
            forResource: "Python",
            ofType: nil,
            inDirectory: "Resources/Python.xcframework/macos-arm64/Python.framework/Versions/3.13"
        ), let scriptPath = Bundle.main.path(
            forResource: "yt_download",
            ofType: "py",
            inDirectory: "Resources"
        ) else {
            DebugEngine.logError("Python binary or script not found.")
            progressCallback("Python binary or script not found.")
            return
        }

        DebugEngine.logSuccess("Found Python binary and script.")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        // Wrap URL in quotes to prevent shell interpretation errors
        process.arguments = [scriptPath, "\"\(url)\""]

        DebugEngine.logInfo("Launching Python subprocess with arguments: \(process.arguments?.joined(separator: " ") ?? "")")

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0, let line = String(data: data, encoding: .utf8), !line.isEmpty {
                DispatchQueue.main.async {
                    progressCallback("[Python] \(line)")
                    guiBinding.wrappedValue.append("[Python] \(line)")
                    DebugEngine.logInfo("Python output: \(line)")
                }
            }
        }

        do {
            try process.run()
            DebugEngine.logSuccess("Python subprocess started successfully.")
        } catch {
            DebugEngine.logError("Failed to run Python: \(error)")
            progressCallback("Failed to run Python: \(error)")
        }
    }
}
