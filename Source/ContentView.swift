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
    @State private var showingUpdateLogin = false
    @State private var isTestingCredentials = false
    @State private var loginMessage: String = ""
    @State private var newUsername: String = ""
    @State private var newPassword: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Enter YouTube URL", text: $urlString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Menu {
                    Button("Update Login Info") {
                        showingUpdateLogin = true
                        loginMessage = ""
                        newUsername = ""
                        newPassword = ""
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .padding(.leading)
                }
                .disabled(isTestingCredentials)
            }
            .padding(.horizontal)

            TextEditor(text: $progressText)
                .frame(height: 300)
                .border(Color.gray)
                .disabled(true)

            HStack {
                Button("Download") {
                    runDownload()
                }
                .padding(.leading)
                .disabled(isTestingCredentials)
                
                if isTestingCredentials {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.leading)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingUpdateLogin) {
            VStack(spacing: 16) {
                Text("Update Login Info")
                    .font(.headline)
                TextField("Username", text: $newUsername)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                SecureField("Password", text: $newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                if !loginMessage.isEmpty {
                    Text(loginMessage)
                        .foregroundColor(loginMessage.contains("success") ? .green : .red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Button("Save Credentials Only") {
                    LoginManager.shared.setCredentials(username: newUsername, password: newPassword, account: "youtube_account")
                    loginMessage = "Credentials saved (not tested)."
                    showingUpdateLogin = false // dismiss modal
                }

                Button("Test & Save") {
                    testAndSaveCredentials()
                }
                .disabled(newUsername.isEmpty || newPassword.isEmpty || isTestingCredentials)
                
                HStack {
                    Button("Cancel") {
                        showingUpdateLogin = false
                    }
                    Spacer()
                }
            }
            .padding()
        }
    }

    func runDownload() {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }

        guard let scriptPath = Bundle.main.path(forResource: "yt_download", ofType: "py") else {
            DebugEngine.logError("Python script not found.", guiBinding: $progressText)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        // Pass URL as separate argument to avoid zsh parsing errors
        process.arguments = [scriptPath, trimmedURL]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                if let line = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        DebugEngine.logInfo("[Python] " + line, guiBinding: $progressText)
                        print("[Python] " + line) // Ensure logs appear in Xcode console
                    }
                }
            }
        }

        do {
            try process.run()
            DebugEngine.logInfo("Python subprocess started for URL: \(trimmedURL)", guiBinding: $progressText)
            print("Python subprocess started for URL: \(trimmedURL)")
        } catch {
            DebugEngine.logError("Failed to run script: \(error)", guiBinding: $progressText)
            print("Failed to run script: \(error)")
        }
    }
    
    func testAndSaveCredentials() {
        isTestingCredentials = true
        DebugEngine.logInfo("Testing credentials...", guiBinding: $progressText)
        print("Testing credentials...")

        // Save current credentials to allow rollback
        let currentCredentials = LoginManager.shared.getCredentials(account: "youtube_account", prompt: "Authenticate to access credentials")
        let currentUsername = currentCredentials?.username
        let currentPassword = currentCredentials?.password
        
        // Set temporary new credentials
        LoginManager.shared.setCredentials(username: newUsername, password: newPassword, account: "youtube_account_temp")
        
        // Run minimal credential test by invoking yt_download.py with a minimal test URL
        guard let scriptPath = Bundle.main.path(forResource: "yt_download", ofType: "py") else {
            DebugEngine.logError("Python script not found.", guiBinding: $progressText)
            rollbackCredentials(username: currentUsername, password: currentPassword)
            isTestingCredentials = false
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        // Provide a minimal test URL that requires login, e.g. a private video URL or a test URL
        // For demonstration, use a placeholder URL "https://www.youtube.com/watch?v=private_test"
        process.arguments = [scriptPath, "https://www.youtube.com/watch?v=-EaiP31qWf0"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        var outputString = ""

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                if let line = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        DebugEngine.logInfo(line, guiBinding: $progressText)
                        print(line) // Ensure logs appear in Xcode console
                        outputString += line
                    }
                }
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()
                
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 && outputString.contains("login successful") {
                        DebugEngine.logSuccess("Credentials updated successfully.", guiBinding: $progressText)
                        print("Credentials updated successfully.")
                        // Promote temporary credentials to primary
                        if let tempCreds = LoginManager.shared.getCredentials(account: "youtube_account_temp") {
                            LoginManager.shared.setCredentials(username: tempCreds.username, password: tempCreds.password, account: "youtube_account")
                        }
                    } else {
                        DebugEngine.logError("Credential test failed. Rolling back.", guiBinding: $progressText)
                        print("Credential test failed. Rolling back.")
                        rollbackCredentials(username: currentUsername, password: currentPassword)
                    }
                    isTestingCredentials = false
                }
            } catch {
                DispatchQueue.main.async {
                    DebugEngine.logError("Failed to run test script: \(error.localizedDescription). Rolling back.", guiBinding: $progressText)
                    print("Failed to run test script: \(error.localizedDescription). Rolling back.")
                    rollbackCredentials(username: currentUsername, password: currentPassword)
                    isTestingCredentials = false
                }
            }
        }
    }
    
    func rollbackCredentials(username: String?, password: String?) {
        // Only set credentials if both username and password are non-nil
        guard let username = username, let password = password else { return }
        LoginManager.shared.setCredentials(username: username, password: password, account: "youtube_account")
    }
}
