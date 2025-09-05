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
    private init() {
        do {
            try createCookiesDirectory()
        } catch {
            DebugEngine.logError("Failed to create cookies directory on initialization: \(error)")
        }
    }

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
        DebugEngine.logInfo("Ensuring symmetric key in Keychain...")
        if let existing = try loadKeyFromKeychain(prompt: prompt) {
            DebugEngine.logSuccess("Existing key loaded from Keychain.")
            return existing
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = Data(key.withUnsafeBytes { Array($0) })
        do {
            try storeKeyInKeychain(keyData: keyData)
            DebugEngine.logSuccess("New symmetric key created and stored in Keychain.")
        } catch {
            DebugEngine.logError("Failed to store new symmetric key in Keychain: \(error)")
            throw error
        }
        return keyData
    }

    private func storeKeyInKeychain(keyData: Data) throws {
        // Create access control requiring user presence (Touch ID / password fallback)
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil,
                                                           kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                           .userPresence,
                                                           &error) else {
            DebugEngine.logError("Failed to create SecAccessControl for Keychain: \(String(describing: error?.takeRetainedValue()))")
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
        if status == errSecSuccess {
            DebugEngine.logSuccess("Symmetric key stored in Keychain successfully.")
        } else {
            DebugEngine.logError("Failed to store symmetric key in Keychain: OSStatus \(status)")
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
            guard let data = item as? Data else {
                DebugEngine.logError("Keychain returned data in unexpected format.")
                return nil
            }
            DebugEngine.logSuccess("Symmetric key loaded from Keychain.")
            return data
        } else if status == errSecItemNotFound {
            DebugEngine.logInfo("No symmetric key found in Keychain.")
            return nil
        } else {
            DebugEngine.logError("Failed to load symmetric key from Keychain: OSStatus \(status)")
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
        }
    }

    // MARK: - Encryption / Decryption

    private func encrypt(plaintext: Data, keyData: Data) throws -> Data {
        do {
            let key = SymmetricKey(data: keyData)
            let sealed = try AES.GCM.seal(plaintext, using: key)
            guard let combined = sealed.combined else {
                DebugEngine.logError("Failed to seal data (no combined output).")
                throw NSError(domain: "CookieManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to seal data"])
            }
            DebugEngine.logSuccess("Encryption succeeded.")
            return combined
        } catch {
            DebugEngine.logError("Encryption failed: \(error)")
            throw error
        }
    }

    private func decrypt(combined: Data, keyData: Data) throws -> Data {
        do {
            let key = SymmetricKey(data: keyData)
            let sealed = try AES.GCM.SealedBox(combined: combined)
            let plain = try AES.GCM.open(sealed, using: key)
            DebugEngine.logSuccess("Decryption succeeded.")
            return plain
        } catch {
            DebugEngine.logError("Decryption failed: \(error)")
            throw error
        }
    }

    // MARK: - File helpers

    private func createCookiesDirectory() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: cookiesDirectory.path) {
            do {
                try fm.createDirectory(at: cookiesDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                DebugEngine.logSuccess("Cookies directory created at \(cookiesDirectory.path)")
            } catch {
                DebugEngine.logError("Failed to create cookies directory: \(error)")
                throw error
            }
        } else {
            DebugEngine.logInfo("Cookies directory already exists at \(cookiesDirectory.path)")
        }
    }

    private func writeAtomic(data: Data, to url: URL) throws {
        let tmp = url.appendingPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            // Set restrictive permissions
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmp.path)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
            DebugEngine.logSuccess("Atomic write to \(url.path) succeeded.")
        } catch {
            DebugEngine.logError("Atomic write to \(url.path) failed: \(error)")
            throw error
        }
    }

    // MARK: - Public API

    /// Save plaintext cookie data (encrypts and writes to disk).
    func saveCookiesPlaintext(_ plain: Data) throws {
        DebugEngine.logInfo("Saving plaintext cookies...")
        do {
            try createCookiesDirectory()
            let keyData = try ensureSymmetricKey()
            let cipher = try encrypt(plaintext: plain, keyData: keyData)
            try writeAtomic(data: cipher, to: cookiesFileURL)
            DebugEngine.logSuccess("Plaintext cookies encrypted and saved successfully.")
        } catch {
            DebugEngine.logError("Failed to save plaintext cookies: \(error)")
            throw error
        }
    }

    /// Load and return decrypted cookie data. This will prompt for Keychain access when required.
    func loadCookiesPlaintext() throws -> Data? {
        DebugEngine.logInfo("Loading plaintext cookies...")
        let fm = FileManager.default
        guard fm.fileExists(atPath: cookiesFileURL.path) else {
            DebugEngine.logInfo("No cookies file found at \(cookiesFileURL.path)")
            return nil
        }
        do {
            let cipher = try Data(contentsOf: cookiesFileURL)
            let keyData = try ensureSymmetricKey()
            let plain = try decrypt(combined: cipher, keyData: keyData)
            DebugEngine.logSuccess("Plaintext cookies loaded and decrypted successfully.")
            return plain
        } catch {
            DebugEngine.logError("Failed to load or decrypt cookies: \(error)")
            throw error
        }
    }

    /// Delete cookies file permanently.
    @discardableResult
    func deleteCookies() throws -> Bool {
        DebugEngine.logInfo("Deleting cookies file...")
        let fm = FileManager.default
        if fm.fileExists(atPath: cookiesFileURL.path) {
            do {
                try fm.removeItem(at: cookiesFileURL)
                DebugEngine.logSuccess("Cookies file deleted at \(cookiesFileURL.path)")
                return true
            } catch {
                DebugEngine.logError("Failed to delete cookies file: \(error)")
                throw error
            }
        } else {
            DebugEngine.logInfo("No cookies file to delete at \(cookiesFileURL.path)")
        }
        return false
    }

    /// Reset cookies: delete existing cookie file. Does NOT fetch new cookies automatically.
    func resetCookies() throws {
        DebugEngine.logInfo("Resetting cookies...")
        do {
            let deleted = try deleteCookies()
            if deleted {
                DebugEngine.logSuccess("Cookies reset (file deleted).")
            } else {
                DebugEngine.logInfo("Cookies reset: no file existed to delete.")
            }
        } catch {
            DebugEngine.logError("Failed to reset cookies: \(error)")
            throw error
        }
    }

    // Convenience: write decrypted cookie from a temp file (atomic move) and encrypt it
    func importPlaintextCookieFile(at tempURL: URL) throws {
        DebugEngine.logInfo("Importing plaintext cookie file from \(tempURL.path)")
        do {
            let data = try Data(contentsOf: tempURL)
            try saveCookiesPlaintext(data)
            try FileManager.default.removeItem(at: tempURL)
            DebugEngine.logSuccess("Plaintext cookie file imported and encrypted successfully.")
        } catch {
            DebugEngine.logError("Failed to import plaintext cookie file: \(error)")
            throw error
        }
    }
}
