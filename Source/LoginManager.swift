//
//  LoginManager.swift
//  yt_dlp_gui
//
//  Keychain-only implementation for secure credential storage.
//
//  Supports multiple accounts (youtube_account, youtube_account_temp).
//  Password is protected with .userPresence (biometric/password fallback).
//
import Foundation
import Security
import LocalAuthentication

class LoginManager {
    static let shared = LoginManager()
    private init() {}

    // Service identifier for Keychain
    private let service = "MyDownloaderApp"

    /// Store credentials (username and password) in Keychain for a given account.
    /// - Parameters:
    ///   - username: The username to store.
    ///   - password: The password to store.
    ///   - account: The account identifier (e.g., "youtube_account", "youtube_account_temp").
    /// - Returns: True on success, false otherwise.
    @discardableResult
    func setCredentials(username: String, password: String, account: String) -> Bool {
        DebugEngine.logInfo("Saving credentials for \(account) in service \(service)")
        guard let passwordData = password.data(using: .utf8),
              let usernameData = username.data(using: .utf8) else { return false }

        // Save username (not protected, but still in Keychain)
        let usernameQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account)_username"
        ]
        SecItemDelete(usernameQuery as CFDictionary)
        let usernameAdd: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account)_username",
            kSecValueData as String: usernameData
        ]
        let usernameStatus = SecItemAdd(usernameAdd as CFDictionary, nil)
        if usernameStatus == errSecSuccess {
            DebugEngine.logSuccess("Username saved successfully for \(account)")
        } else {
            DebugEngine.logError("Failed to save username for \(account), status: \(usernameStatus)")
            return false
        }

        // Save password (protected with .userPresence)
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account)_password"
        ]
        let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .userPresence, nil)

        // Try to update existing password
        let passwordUpdate: [String: Any] = [
            kSecValueData as String: passwordData,
            kSecAttrAccessControl as String: access as Any
        ]
        let updateStatus = SecItemUpdate(passwordQuery as CFDictionary, passwordUpdate as CFDictionary)
        if updateStatus == errSecSuccess {
            DebugEngine.logSuccess("Password updated successfully for \(account)")
            return true
        } else if updateStatus == errSecItemNotFound {
            // Item doesn't exist, add it
            var passwordAdd: [String: Any] = passwordQuery
            passwordAdd[kSecValueData as String] = passwordData
            passwordAdd[kSecAttrAccessControl as String] = access as Any
            let addStatus = SecItemAdd(passwordAdd as CFDictionary, nil)
            if addStatus == errSecSuccess {
                DebugEngine.logSuccess("Password added successfully for \(account)")
                return true
            } else {
                DebugEngine.logError("Failed to add password for \(account), status: \(addStatus)")
                return false
            }
        } else {
            DebugEngine.logError("Failed to update password for \(account), status: \(updateStatus)")
            return false
        }
    }

    /// Retrieve credentials (username and password) for a given account.
    /// - Parameters:
    ///   - account: The account identifier (e.g., "youtube_account", "youtube_account_temp").
    ///   - prompt: The prompt to display when authenticating for password.
    /// - Returns: (username, password) tuple if found, else nil.
    func getCredentials(account: String, prompt: String = "Authenticate to access your password") -> (username: String, password: String)? {
        DebugEngine.logInfo("Fetching credentials for \(account) in service \(service)")
        // Get username
        let usernameQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account)_username",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var usernameItem: CFTypeRef?
        let usernameStatus = SecItemCopyMatching(usernameQuery as CFDictionary, &usernameItem)
        guard usernameStatus == errSecSuccess,
              let usernameData = usernameItem as? Data,
              let username = String(data: usernameData, encoding: .utf8) else {
            DebugEngine.logError("Failed to retrieve username for \(account), status: \(usernameStatus)")
            return nil
        }

        // Get password (requires user presence)
        let context = LAContext()
        context.localizedReason = prompt
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account)_password",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        var passwordItem: CFTypeRef?
        let passwordStatus = SecItemCopyMatching(passwordQuery as CFDictionary, &passwordItem)
        guard passwordStatus == errSecSuccess,
              let passwordData = passwordItem as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            DebugEngine.logError("Failed to retrieve password for \(account), status: \(passwordStatus)")
            return nil
        }

        DebugEngine.logSuccess("Successfully retrieved credentials for \(account)")
        return (username, password)
    }

    /// Delete credentials for a given account.
    /// - Parameter account: The account identifier (e.g., "youtube_account", "youtube_account_temp").
    /// - Returns: True on success, false otherwise.
    @discardableResult
    func deleteCredentials(account: String) -> Bool {
        DebugEngine.logInfo("Deleting credentials for \(account) in service \(service)")
        var ok = true
        let usernameQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account)_username"
        ]
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account)_password"
        ]
        let userStatus = SecItemDelete(usernameQuery as CFDictionary)
        let passStatus = SecItemDelete(passwordQuery as CFDictionary)
        DebugEngine.logInfo("Delete username status: \(userStatus), Delete password status: \(passStatus)")
        if userStatus != errSecSuccess && userStatus != errSecItemNotFound { ok = false }
        if passStatus != errSecSuccess && passStatus != errSecItemNotFound { ok = false }
        return ok
    }
}

extension LoginManager {
    /// Ensure credentials exist; prompt if missing.
    func ensurePassword(account: String = "youtube_account", prompt: String = "Authenticate to access password") -> Bool {
        if getCredentials(account: account, prompt: prompt) != nil {
            DebugEngine.logInfo("ensurePassword: Found existing credentials for \(account)")
            return true
        }
        DebugEngine.logInfo("ensurePassword: No credentials found, prompting user…")
        if promptForPassword(account: account) {
            DebugEngine.logInfo("ensurePassword: User entered credentials, saved to Keychain")
            return true
        }
        DebugEngine.logInfo("ensurePassword: User canceled or failed to enter credentials")
        return false
    }

    /// Prompt user to enter password manually for given account
    func promptForPassword(account: String = "youtube_account") -> Bool {
        // This would show a SwiftUI modal or AppKit dialog to get new password
        // For now return false to compile; implement actual prompt later
        return false
    }
}
