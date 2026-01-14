//
//  ExplorationLogger.swift
//  EarthLord
//
//  探索功能日志管理器
//  用于在 App 内显示调试日志，方便真机测试
//

import Foundation
import Combine

/// 探索日志条目
struct ExplorationLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType

    /// 格式化的显示文本（短时间格式）
    var displayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: timestamp))] [\(type.rawValue)] \(message)"
    }

    /// 格式化的导出文本（完整时间格式）
    var exportText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "[\(formatter.string(from: timestamp))] [\(type.rawValue)] \(message)"
    }
}

/// 探索功能日志管理器
final class ExplorationLogger: ObservableObject {

    // MARK: - 单例

    static let shared = ExplorationLogger()

    // MARK: - Published 属性

    /// 日志数组
    @Published var logs: [ExplorationLogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    // MARK: - 私有属性

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 300

    // MARK: - 初始化

    private init() {
        log("探索日志系统初始化完成", type: .info)
    }

    // MARK: - 公开方法

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogType = .info) {
        let entry = ExplorationLogEntry(timestamp: Date(), message: message, type: type)

        // 确保在主线程更新
        DispatchQueue.main.async {
            // 添加新日志
            self.logs.append(entry)

            // 限制最大条数
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }

            // 更新格式化文本
            self.updateLogText()
        }

        // 同时输出到控制台（便于 Xcode 调试）
        print("🔍 [Exploration] \(entry.displayText)")
    }

    /// 添加信息日志
    func info(_ message: String) {
        log(message, type: .info)
    }

    /// 添加成功日志
    func success(_ message: String) {
        log(message, type: .success)
    }

    /// 添加警告日志
    func warning(_ message: String) {
        log(message, type: .warning)
    }

    /// 添加错误日志
    func error(_ message: String) {
        log(message, type: .error)
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.logText = ""
        }
        print("🔍 [Exploration] 日志已清空")
    }

    /// 导出日志为文本
    /// - Returns: 格式化的日志文本（包含头信息）
    func export() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let exportTime = formatter.string(from: Date())

        var result = """
        === 探索功能测试日志 ===
        导出时间: \(exportTime)
        日志条数: \(logs.count)

        """

        for entry in logs {
            result += entry.exportText + "\n"
        }

        return result
    }

    // MARK: - 私有方法

    /// 更新格式化的日志文本
    private func updateLogText() {
        logText = logs.map { $0.displayText }.joined(separator: "\n")
    }
}
