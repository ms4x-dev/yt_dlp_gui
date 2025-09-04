//
//  LoginManager.swift
//  yt_dlp_gui
//
//  Keychain-only implementation for secure credential storage.
//
//  Supports multiple accounts (main_user, temp_user).
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
    ///   - account: The account identifier (e.g., "main_user", "temp_user").
    /// - Returns: True on success, false otherwise.
    @discardableResult
    func setCredentials(username: String, password: String, account: String) -> Bool {
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
        guard usernameStatus == errSecSuccess else { return false }

        // Save password (protected with .userPresence)
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account)_password"
        ]
        SecItemDelete(passwordQuery as CFDictionary)
        let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .userPresence, nil)
        let passwordAdd: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(account)_password",
            kSecValueData as String: passwordData,
            kSecAttrAccessControl as String: access as Any
        ]
        let passwordStatus = SecItemAdd(passwordAdd as CFDictionary, nil)
        return passwordStatus == errSecSuccess
    }

    /// Retrieve credentials (username and password) for a given account.
    /// - Parameters:
    ///   - account: The account identifier (e.g., "main_user", "temp_user").
    ///   - prompt: The prompt to display when authenticating for password.
    /// - Returns: (username, password) tuple if found, else nil.
    func getCredentials(account: String, prompt: String = "Authenticate to access your password") -> (username: String, password: String)? {
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
              let username = String(data: usernameData, encoding: .utf8) else { return nil }

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
              let password = String(data: passwordData, encoding: .utf8) else { return nil }

        return (username, password)
    }

    /// Delete credentials for a given account.
    /// - Parameter account: The account identifier (e.g., "main_user", "temp_user").
    /// - Returns: True on success, false otherwise.
    @discardableResult
    func deleteCredentials(account: String) -> Bool {
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
        if userStatus != errSecSuccess && userStatus != errSecItemNotFound { ok = false }
        if passStatus != errSecSuccess && passStatus != errSecItemNotFound { ok = false }
        return ok
    }
}

extension LoginManager {
    /// Ensure credentials exist; prompt if missing.
    func ensurePassword(account: String = "main_user", prompt: String = "Authenticate to access password") -> Bool {
        if getCredentials(account: account, prompt: prompt) != nil {
            return true
        }
        // Prompt logic could open a dialog in SwiftUI to ask user
        return false
    }

    /// Prompt user to enter password manually for given account
    func promptForPassword(account: String = "main_user") -> Bool {
        // This would show a SwiftUI modal or AppKit dialog to get new password
        // For now return false to compile; implement actual prompt later
        return false
    }
}
