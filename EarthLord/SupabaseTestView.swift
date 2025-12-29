//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by taozi on 2025/12/24.
//

import SwiftUI
import Supabase

// MARK: - Supabase 客户端初始化
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://oweqpvstnomdoeobmypz.supabase.co")!,
    supabaseKey: "sb_publishable_X-DihtGVYc35ZTCClln2xA_PvPz8LVa"
)

// MARK: - 测试视图
struct SupabaseTestView: View {
    /// 连接状态：nil=未测试, true=成功, false=失败
    @State private var isConnected: Bool? = nil

    /// 调试日志
    @State private var debugLog: String = "点击按钮开始测试连接..."

    /// 是否正在测试
    @State private var isTesting: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // 状态图标
            statusIcon

            // 调试日志文本框
            debugLogView

            // 测试按钮
            testButton
        }
        .padding()
        .navigationTitle("Supabase 连接测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态图标
    private var statusIcon: some View {
        Group {
            if let connected = isConnected {
                if connected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                }
            } else {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - 调试日志视图
    private var debugLogView: some View {
        ScrollView {
            Text(debugLog)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(maxHeight: 300)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 测试按钮
    private var testButton: some View {
        Button(action: {
            testConnection()
        }) {
            HStack {
                if isTesting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 8)
                }
                Text(isTesting ? "测试中..." : "测试连接")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isTesting ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isTesting)
    }

    // MARK: - 测试连接逻辑
    private func testConnection() {
        Task {
            await MainActor.run {
                isTesting = true
                isConnected = nil
                debugLog = "[\(timestamp())] 开始测试连接...\n"
                debugLog += "[\(timestamp())] URL: https://oweqpvstnomdoeobmypz.supabase.co\n"
                debugLog += "[\(timestamp())] 正在查询测试表...\n"
            }

            do {
                // 故意查询一个不存在的表来测试连接
                let _: [EmptyResponse] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有抛出错误（理论上不应该发生）
                await MainActor.run {
                    debugLog += "[\(timestamp())] ⚠️ 意外：查询成功返回\n"
                    isConnected = true
                    isTesting = false
                }
            } catch {
                await handleError(error)
            }
        }
    }

    // MARK: - 错误处理
    @MainActor
    private func handleError(_ error: Error) {
        let errorString = String(describing: error)
        debugLog += "[\(timestamp())] 收到响应，分析中...\n"
        debugLog += "[\(timestamp())] 错误详情: \(errorString)\n\n"

        // 判断连接状态
        if errorString.contains("PGRST") ||
           errorString.contains("Could not find") ||
           errorString.contains("relation") && errorString.contains("does not exist") {
            // 服务器正常响应，只是表不存在
            debugLog += "[\(timestamp())] ✅ 连接成功（服务器已响应）\n"
            debugLog += "[\(timestamp())] 说明：服务器返回了 PostgreSQL 错误，\n"
            debugLog += "       表示网络连接正常，Supabase 服务可用。\n"
            isConnected = true
        } else if errorString.contains("hostname") ||
                  errorString.contains("URL") ||
                  errorString.contains("NSURLErrorDomain") ||
                  errorString.contains("Could not connect") ||
                  errorString.contains("network") {
            // 网络或 URL 错误
            debugLog += "[\(timestamp())] ❌ 连接失败：URL 错误或无网络\n"
            debugLog += "[\(timestamp())] 请检查：\n"
            debugLog += "       1. 网络连接是否正常\n"
            debugLog += "       2. Supabase URL 是否正确\n"
            debugLog += "       3. API Key 是否有效\n"
            isConnected = false
        } else {
            // 其他错误
            debugLog += "[\(timestamp())] ❓ 未知错误类型\n"
            debugLog += "[\(timestamp())] 原始错误: \(error.localizedDescription)\n"
            isConnected = false
        }

        isTesting = false
    }

    // MARK: - 时间戳
    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - 空响应结构体
private struct EmptyResponse: Decodable {}

// MARK: - 预览
#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
