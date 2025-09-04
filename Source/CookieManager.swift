//
// CookieManager.swift
// yt_dlp_gui
//
// Secure cookie storage: AES-GCM encryption using a symmetric key stored in Keychain.
// Key is protected with userPresence (Touch ID / Face ID or device password) so
// any attempt to read the key can be gated by biometric/pin prompt.
//

import Foundation
import CryptoKit
import Security
import LocalAuthentication

final class CookieManager {
    static let shared = CookieManager()
    private init() { try? createCookiesDirectory() }

    // Keychain identifiers
    private let service = "MyDownloaderApp"
    private let account = "cookie_encryption_key"

    // Cookie storage location: Application Support/yt_dlp_gui/yt-cookies/cookies.enc
    private var cookiesDirectory: URL {
        let fm = FileManager.default
        let appSupport = try! fm.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil,
                                     create: true)
        let dir = appSupport.appendingPathComponent("yt_dlp_gui/yt-cookies", isDirectory: true)
        return dir
    }

    private var cookiesFileURL: URL {
        return cookiesDirectory.appendingPathComponent("cookies.enc")
    }

    // MARK: - Key management

    /// Ensure a symmetric key exists in Keychain. Returns the key data.
    func ensureSymmetricKey(prompt: String = "Authenticate to access cookies") throws -> Data {
        if let existing = try loadKeyFromKeychain(prompt: prompt) {
            return existing
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = Data(key.withUnsafeBytes { Array($0) })
        try storeKeyInKeychain(keyData: keyData)
        return keyData
    }

    private func storeKeyInKeychain(keyData: Data) throws {
        // Create access control requiring user presence (Touch ID / password fallback)
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil,
                                                           kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                           .userPresence,
                                                           &error) else {
            throw error!.takeRetainedValue() as Error
        }

        // Remove any existing item for a clean add
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessControl as String: access
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
        }
    }

    private func loadKeyFromKeychain(prompt: String) throws -> Data? {
        let context = LAContext()
        context.localizedReason = prompt

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess {
            guard let data = item as? Data else { return nil }
            return data
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
        }
    }

    // MARK: - Encryption / Decryption

    private func encrypt(plaintext: Data, keyData: Data) throws -> Data {
        let key = SymmetricKey(data: keyData)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw NSError(domain: "CookieManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to seal data"])
        }
        return combined
    }

    private func decrypt(combined: Data, keyData: Data) throws -> Data {
        let key = SymmetricKey(data: keyData)
        let sealed = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealed, using: key)
    }

    // MARK: - File helpers

    private func createCookiesDirectory() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: cookiesDirectory.path) {
            try fm.createDirectory(at: cookiesDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
    }

    private func writeAtomic(data: Data, to url: URL) throws {
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        // Set restrictive permissions
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmp.path)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }

    // MARK: - Public API

    /// Save plaintext cookie data (encrypts and writes to disk).
    func saveCookiesPlaintext(_ plain: Data) throws {
        try createCookiesDirectory()
        let keyData = try ensureSymmetricKey()
        let cipher = try encrypt(plaintext: plain, keyData: keyData)
        try writeAtomic(data: cipher, to: cookiesFileURL)
    }

    /// Load and return decrypted cookie data. This will prompt for Keychain access when required.
    func loadCookiesPlaintext() throws -> Data? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cookiesFileURL.path) else { return nil }
        let cipher = try Data(contentsOf: cookiesFileURL)
        let keyData = try ensureSymmetricKey()
        let plain = try decrypt(combined: cipher, keyData: keyData)
        return plain
    }

    /// Delete cookies file permanently.
    @discardableResult
    func deleteCookies() throws -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: cookiesFileURL.path) {
            try fm.removeItem(at: cookiesFileURL)
            return true
        }
        return false
    }

    /// Reset cookies: delete existing cookie file. Does NOT fetch new cookies automatically.
    func resetCookies() throws {
        _ = try deleteCookies()
    }

    // Convenience: write decrypted cookie from a temp file (atomic move) and encrypt it
    func importPlaintextCookieFile(at tempURL: URL) throws {
        let data = try Data(contentsOf: tempURL)
        try saveCookiesPlaintext(data)
        try FileManager.default.removeItem(at: tempURL)
    }
}
