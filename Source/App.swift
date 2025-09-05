//
//  yt_dlp_guiApp.swift
//  yt_dlp_gui
//
//  Created by Richard on 4/9/2025.
//

import SwiftUI

@main
struct MyApp: App {
    
    @State private var password: String?
    @State private var username: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    
                  #if DEBUG
                  TestEnvironment.reset()
                 #endif
                    // Automatic login
                    
                    if LoginManager.shared.ensurePassword(account: "youtube_account", prompt: "Please enter your credentials") {
                        if let credentials = LoginManager.shared.getCredentials(account: "youtube_account", prompt: "Please enter your credentials") {
                            username = credentials.username
                            password = credentials.password
                            print("Automatically logging in with stored username: \(username ?? "")")
                            // TODO: call your service login here
                        }
                    } else {
                        print("No credentials available — user cancelled login.")
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Update Login Info") {
                    if let credentials = LoginManager.shared.getCredentials(account: "youtube_account", prompt: "Enter new credentials") {
                        let success = LoginManager.shared.setCredentials(username: credentials.username, password: credentials.password, account: "youtube_account")
                        if success {
                            print("Password updated")
                        }
                    }
                }
            }
        }
    }
}
