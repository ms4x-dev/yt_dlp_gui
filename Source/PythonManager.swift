//
//  PythonManager.swift
//  yt_dlp_gui
//
//  Created by Richard on 4/9/2025.
//

import Foundation    // Needed for Bundle, Process, Pipe, DispatchQueue

class PythonManager {
    static let shared = PythonManager()

    func runScript(url: String, progressCallback: @escaping (String) -> Void) {
        guard let pythonPath = Bundle.main.path(
            forResource: "Python",
            ofType: nil,
            inDirectory: "Resources/Python.xcframework/macos-arm64/Python.framework/Versions/3.13"
        ), let scriptPath = Bundle.main.path(
            forResource: "yt_download",
            ofType: "py",
            inDirectory: "Resources"
        ) else {
            progressCallback("Python binary or script not found.")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath, url]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            if let line = String(data: handle.availableData, encoding: .utf8), !line.isEmpty {
                DispatchQueue.main.async {
                    progressCallback(line)
                }
            }
        }

        do {
            try process.run()
        } catch {
            progressCallback("Failed to run Python: \(error)")
        }
    }
}
