//
//  ContentView.swift
//  yt_dlp_gui
//
//  Created by Richard on 4/9/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var urlString: String = ""
    @State private var progressText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Enter YouTube URL", text: $urlString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            ScrollView {
                Text(progressText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 300)
            .border(Color.gray)

            HStack {
                Button("Download") {
                    runDownload()
                }
                .padding(.leading)
            }
        }
        .padding()
    }

    func runDownload() {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }

        guard let scriptPath = Bundle.main.path(forResource: "yt_download", ofType: "py") else {
            progressText += "Python script not found.\n"
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptPath, trimmedURL]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            if let line = String(data: handle.availableData, encoding: .utf8) {
                DispatchQueue.main.async {
                    progressText += line
                }
            }
        }

        do {
            try process.run()
        } catch {
            progressText += "Failed to run script: \(error)\n"
        }
    }
}
