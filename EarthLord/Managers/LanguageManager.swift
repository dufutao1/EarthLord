//
//  LanguageManager.swift
//  EarthLord
//
//  Created by Claude on 2025/12/31.
//

import SwiftUI
import Foundation
import Combine

/// 支持的语言选项
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"      // 跟随系统
    case zhHans = "zh-Hans"     // 简体中文
    case en = "en"              // English

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统".localized
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }

    /// 图标
    var icon: String {
        switch self {
        case .system:
            return "iphone"
        case .zhHans:
            return "character"
        case .en:
            return "a.square"
        }
    }
}

/// 语言管理器
final class LanguageManager: ObservableObject {

    /// 单例
    static let shared = LanguageManager()

    /// UserDefaults key
    private let languageKey = "app_language"

    /// 当前选择的语言
    @Published var currentLanguage: AppLanguage {
        didSet {
            print("🌐 [语言] 语言设置变更: \(oldValue.rawValue) → \(currentLanguage.rawValue)")
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            updateBundle()
        }
    }

    /// 当前使用的 Bundle（用于加载本地化字符串）
    @Published private(set) var currentBundle: Bundle = .main

    /// 语言变更标识（用于触发视图刷新）
    @Published var languageRefreshID: UUID = UUID()

    private init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
            print("🌐 [语言] 从存储中恢复语言设置: \(language.rawValue)")
        } else {
            self.currentLanguage = .system
            print("🌐 [语言] 使用默认语言设置: 跟随系统")
        }

        updateBundle()
    }

    /// 更新当前使用的 Bundle
    private func updateBundle() {
        let languageCode = resolveLanguageCode()
        print("🌐 [语言] 解析后的语言代码: \(languageCode)")

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            currentBundle = bundle
            print("🌐 [语言] 成功加载语言包: \(languageCode)")
        } else {
            // 尝试备选语言
            let fallbackCode = languageCode == "zh-Hans" ? "zh-Hans" : "en"
            if let path = Bundle.main.path(forResource: fallbackCode, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                currentBundle = bundle
                print("🌐 [语言] 使用备选语言包: \(fallbackCode)")
            } else {
                currentBundle = .main
                print("🌐 [语言] 使用主 Bundle")
            }
        }

        // 触发视图刷新
        languageRefreshID = UUID()
    }

    /// 解析实际使用的语言代码
    private func resolveLanguageCode() -> String {
        switch currentLanguage {
        case .system:
            // 获取系统首选语言
            let preferredLanguages = Locale.preferredLanguages
            print("🌐 [语言] 系统首选语言列表: \(preferredLanguages)")

            for language in preferredLanguages {
                if language.hasPrefix("zh-Hans") || language.hasPrefix("zh-CN") {
                    return "zh-Hans"
                } else if language.hasPrefix("en") {
                    return "en"
                }
            }
            // 默认返回中文
            return "zh-Hans"

        case .zhHans:
            return "zh-Hans"

        case .en:
            return "en"
        }
    }

    /// 设置语言
    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        currentLanguage = language
    }

    /// 获取本地化字符串
    func localizedString(_ key: String) -> String {
        return NSLocalizedString(key, bundle: currentBundle, comment: "")
    }
}

// MARK: - String Extension for Localization

extension String {
    /// 使用 LanguageManager 获取本地化字符串
    var localized: String {
        return LanguageManager.shared.localizedString(self)
    }
}

// MARK: - View Extension for Language

extension View {
    /// 添加语言变更监听，自动刷新视图
    func languageAware() -> some View {
        self.id(LanguageManager.shared.languageRefreshID)
    }
}
