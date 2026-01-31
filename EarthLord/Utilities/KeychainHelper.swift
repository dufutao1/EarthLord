//
//  KeychainHelper.swift
//  EarthLord
//
//  Keychain 工具类 - 安全存储登录凭据
//

import Foundation
import Security

final class KeychainHelper {

    static let shared = KeychainHelper()

    private let service = "com.futuremind2075.EarthLord"
    private let emailKey = "savedEmail"
    private let passwordKey = "savedPassword"

    private init() {}

    // MARK: - 保存凭据

    func saveCredentials(email: String, password: String) {
        save(key: emailKey, value: email)
        save(key: passwordKey, value: password)
    }

    // MARK: - 读取凭据

    func loadCredentials() -> (email: String, password: String)? {
        guard let email = load(key: emailKey),
              let password = load(key: passwordKey) else {
            return nil
        }
        return (email, password)
    }

    // MARK: - 清除凭据

    func clearCredentials() {
        delete(key: emailKey)
        delete(key: passwordKey)
    }

    // MARK: - 私有方法

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // 先删除旧值
        delete(key: key)

        // 创建查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Keychain] 保存失败: \(key), 状态: \(status)")
        }
    }

    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
