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
                    // Automatic login
                    if let credentials = LoginManager.shared.getCredentials(account: "yt_dlp_gui", prompt: "Please enter your credentials") {
                        username = credentials.username
                        password = credentials.password
                        print("Automatically logging in with stored password: \(password ?? "")")
                        // TODO: call your service login here
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Update Login Info") {
                    if let credentials = LoginManager.shared.getCredentials(account: "yt_dlp_gui", prompt: "Enter new credentials") {
                        let success = LoginManager.shared.setCredentials(username: credentials.username, password: credentials.password, account: "yt_dlp_gui")
                        if success {
                            print("Password updated")
                        }
                    }
                }
            }
        }
    }
}
