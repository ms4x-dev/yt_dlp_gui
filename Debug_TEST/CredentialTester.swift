//
//  CredentialTester.swift
//  yt_dlp_gui
//
//  Created by Richard on 5/9/2025.
//

#if DEBUG
import Foundation

struct CredentialTester {
    static func runDummyTest(username: String, password: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Library/Frameworks/Python.framework/Versions/3.13/bin/yt-dlp")
        process.arguments = [
            "--username", username,
            "--password", password,
            "--simulate",
            "https://www.youtube.com/watch?v=-EaiP31qWf0"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to launch yt-dlp process:", error)
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        print("YT-DLP dummy test output:\n\(output)")

        return process.terminationStatus == 0
    }
}
#endif
