//
//  ExplorationTestView.swift
//  EarthLord
//
//  探索功能测试界面
//  显示探索模块的实时调试日志
//

import SwiftUI

/// 探索功能测试界面
struct ExplorationTestView: View {

    // MARK: - 数据绑定

    /// 探索管理器（监听探索状态）
    @ObservedObject var explorationManager = ExplorationManager.shared

    /// 日志管理器（监听日志更新）
    @ObservedObject var logger = ExplorationLogger.shared

    // MARK: - 状态

    /// 滚动位置标识
    @State private var scrollToBottom: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 日志区域
            logArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 底部按钮
            bottomButtons
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.background)
        .navigationTitle("探索测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态指示器

    private var statusIndicator: some View {
        HStack(spacing: 8) {
            // 状态圆点
            Circle()
                .fill(explorationManager.isExploring ? Color.green : Color.gray)
                .frame(width: 10, height: 10)

            // 状态文字
            Text(explorationManager.isExploring ? "探索中" : "未探索")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(explorationManager.isExploring ? .green : ApocalypseTheme.textMuted)

            Spacer()

            // 当前速度
            if explorationManager.isExploring {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 12))
                    Text(String(format: "%.1f km/h", explorationManager.currentSpeed))
                        .font(.system(size: 12))
                }
                .foregroundColor(explorationManager.showSpeedWarning ? .red : ApocalypseTheme.textSecondary)
            }

            // 日志条数
            Text("\(logger.logs.count) 条日志")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 超速警告
            if explorationManager.showSpeedWarning {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("超速!")
                        .font(.system(size: 12))
                }
                .foregroundColor(.red)
            }
        }
    }

    // MARK: - 日志区域

    private var logArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if logger.logs.isEmpty {
                        // 空状态
                        emptyLogView
                    } else {
                        // 日志列表
                        ForEach(logger.logs) { entry in
                            logEntryView(entry)
                        }

                        // 底部锚点
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: logger.logText) { _, _ in
                // 日志更新时自动滚动到底部
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    // MARK: - 日志条目视图

    private func logEntryView(_ entry: ExplorationLogEntry) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(entry.displayText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(logColor(for: entry.type))
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    /// 根据日志类型返回颜色
    private func logColor(for type: LogType) -> Color {
        switch type {
        case .info:
            return ApocalypseTheme.textSecondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    // MARK: - 空状态视图

    private var emptyLogView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无日志")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("开始探索后，日志将显示在这里")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - 底部按钮

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            // 清空日志按钮
            Button {
                logger.clear()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("清空日志")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.danger.opacity(0.8))
                .cornerRadius(10)
            }

            // 导出日志按钮
            ShareLink(item: logger.export()) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出日志")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary.opacity(0.8))
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ExplorationTestView()
    }
}
