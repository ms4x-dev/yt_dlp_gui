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
                HStack {
                    Button("Cancel") {
                        showingUpdateLogin = false
                    }
                    Spacer()
                    Button("Test & Save") {
                        testAndSaveCredentials()
                    }
                    .disabled(newUsername.isEmpty || newPassword.isEmpty || isTestingCredentials)
                }
            }
            .padding()
        }
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
    
    func testAndSaveCredentials() {
        isTestingCredentials = true
        loginMessage = "Testing credentials..."
        
        // Save current credentials to allow rollback
        let currentCredentials = LoginManager.shared.getCredentials(account: "yt_dlp_account", prompt: "Authenticate to access credentials")
        let currentUsername = currentCredentials?.username
        let currentPassword = currentCredentials?.password
        
        // Set temporary new credentials
        LoginManager.shared.setCredentials(username: newUsername, password: newPassword, account: "yt_dlp_account")
        
        // Run minimal credential test by invoking yt_download.py with a minimal test URL
        guard let scriptPath = Bundle.main.path(forResource: "yt_download", ofType: "py") else {
            loginMessage = "Python script not found."
            rollbackCredentials(username: currentUsername, password: currentPassword)
            isTestingCredentials = false
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        // Provide a minimal test URL that requires login, e.g. a private video URL or a test URL
        // For demonstration, use a placeholder URL "https://www.youtube.com/watch?v=private_test"
        process.arguments = [scriptPath, "https://www.youtube.com/watch?v=private_test"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        var outputData = Data()
        
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.count > 0 {
                outputData.append(data)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputString = String(data: outputData, encoding: .utf8) ?? ""
                
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 && outputString.contains("login successful") {
                        loginMessage = "Credentials updated successfully."
                        // Credentials already set in LoginManager, nothing more to do
                    } else {
                        loginMessage = "Credential test failed. Rolling back."
                        rollbackCredentials(username: currentUsername, password: currentPassword)
                    }
                    isTestingCredentials = false
                }
            } catch {
                DispatchQueue.main.async {
                    loginMessage = "Failed to run test script: \(error.localizedDescription). Rolling back."
                    rollbackCredentials(username: currentUsername, password: currentPassword)
                    isTestingCredentials = false
                }
            }
        }
    }
    
    func rollbackCredentials(username: String?, password: String?) {
        // Only set credentials if both username and password are non-nil
        guard let username = username, let password = password else { return }
        LoginManager.shared.setCredentials(username: username, password: password, account: "yt_dlp_account")
    }
}
