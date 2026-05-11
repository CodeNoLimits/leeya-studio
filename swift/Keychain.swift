// Keychain.swift — minimal generic-password helper for Leeya Studio.
// Stores Gemini / ElevenLabs / OAuth-token-path keys without ever touching
// the binary or the filesystem in plaintext.

import Foundation
import Security

enum Keychain {
    static let service = "com.dreamnova.leeyastudio"

    /// Account names used across the app — extend as new keys appear.
    enum Account: String {
        case geminiKey      = "gemini"
        case elevenLabsKey  = "elevenlabs"
        case voiceId        = "voice_id"
        case youtubeToken   = "youtube_token_path"  // path to JSON on disk
        case youtubeChannel = "youtube_channel_title"
    }

    @discardableResult
    static func set(_ value: String, for account: Account) -> Bool {
        let data = Data(value.utf8)
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
        SecItemDelete(q as CFDictionary) // overwrite by delete-then-add
        var add = q
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ account: Account) -> String? {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
            kSecMatchLimit as String:  kSecMatchLimitOne,
            kSecReturnData as String:  true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func has(_ account: Account) -> Bool {
        guard let v = get(account) else { return false }
        return !v.isEmpty
    }

    @discardableResult
    static func delete(_ account: Account) -> Bool {
        let q: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
        return SecItemDelete(q as CFDictionary) == errSecSuccess
    }

    static func wipe() {
        for a: Account in [.geminiKey, .elevenLabsKey, .voiceId, .youtubeToken, .youtubeChannel] {
            delete(a)
        }
    }
}
