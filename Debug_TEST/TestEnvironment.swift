//
//  TestEnvironment.swift
//  yt_dlp_gui
//
//  Created by Richard on 4/9/2025.
//

#if DEBUG
import Foundation

struct TestEnvironment {
    static func reset() {
        let manager = LoginManager.shared
        manager.deleteCredentials(account: "main_user")
        manager.deleteCredentials(account: "temp_user")

        do {
            _ = try CookieManager.shared.deleteCookies()
            print("Test cookies deleted.")
        } catch {
            print("Error deleting test cookies: \(error)")
        }

        print("Test environment reset complete.")
    }
}
#endif

