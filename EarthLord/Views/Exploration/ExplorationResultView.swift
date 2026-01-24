//
//  ExplorationResultView.swift
//  EarthLord
//
//  探索结果弹窗页面
//  探索结束后显示本次收获，包括统计数据和获得物品
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - 参数

    /// 探索结果数据（可选，nil表示探索失败）
    let result: ExplorationResult?

    /// 错误信息（探索失败时显示）
    let errorMessage: String?

    /// 重试回调
    var onRetry: (() -> Void)?

    // MARK: - 便捷初始化器

    /// 成功状态的初始化器
    init(result: ExplorationResult) {
        self.result = result
        self.errorMessage = nil
        self.onRetry = nil
    }

    /// 错误状态的初始化器
    init(errorMessage: String, onRetry: (() -> Void)? = nil) {
        self.result = nil
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    // MARK: - 环境

    @Environment(\.dismiss) private var dismiss

    // MARK: - 状态

    /// 控制动画：页面出现时依次显示各部分
    @State private var showTitle: Bool = false
    @State private var showStats: Bool = false
    @State private var showLoot: Bool = false
    @State private var showButton: Bool = false

    /// 数字跳动动画进度 (0-1)
    @State private var numberAnimationProgress: Double = 0

    /// 物品显示状态数组
    @State private var lootItemsVisible: [Bool] = []

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            if let errorMessage = errorMessage {
                // 错误状态
                errorView(message: errorMessage)
            } else if let result = result {
                // 成功状态
                successView(result: result)
            }
        }
        .onAppear {
            // 初始化物品显示状态
            if let result = result {
                lootItemsVisible = Array(repeating: false, count: result.loot.count)
                startAnimations()
            }
        }
    }

    // MARK: - 错误视图

    /// 探索失败时显示的错误视图
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.2))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 错误标题
            Text("探索失败")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 错误信息
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // 按钮区域
            VStack(spacing: 12) {
                // 重试按钮
                if let onRetry = onRetry {
                    Button(action: {
                        dismiss()
                        onRetry()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16))
                            Text("重试")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                    }
                }

                // 关闭按钮
                Button(action: { dismiss() }) {
                    Text("关闭")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }

    // MARK: - 成功视图

    /// 探索成功时显示的结果视图
    private func successView(result: ExplorationResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // 成就标题
                if showTitle {
                    titleSection
                        .transition(.scale.combined(with: .opacity))
                }

                // 统计数据卡片
                if showStats {
                    statsCard(result: result)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                // 奖励物品卡片
                if showLoot {
                    lootCard(result: result)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                // 确认按钮
                if showButton {
                    confirmButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(20)
            .padding(.top, 20)
        }
    }

    // MARK: - 成就标题

    /// 根据收获情况返回副标题文案
    private var subtitleText: String {
        guard let result = result else { return "" }
        if result.loot.isEmpty {
            if result.stats.walkDistance < 200 {
                return "走得还不够远，继续加油"
            } else {
                return "虽然没找到物资，但锻炼了身体"
            }
        } else if result.loot.count >= 3 {
            return "这次探索收获满满"
        } else {
            return "有所收获，继续努力"
        }
    }

    /// 顶部成就展示：大图标 + "探索完成！"
    private var titleSection: some View {
        VStack(spacing: 16) {
            // 大图标（带光环效果和旋转动画）
            ZStack {
                // 外圈光环（脉冲动画）
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ApocalypseTheme.primary.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(showTitle ? 1.0 : 0.8)
                    .opacity(showTitle ? 1.0 : 0.5)

                // 内圈
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 100, height: 100)

                // 图标
                Image(systemName: "map.fill")
                    .font(.system(size: 45))
                    .foregroundColor(ApocalypseTheme.primary)
                    .scaleEffect(showTitle ? 1.0 : 0.5)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showTitle)

            // 大标题
            Text("探索完成！")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题（根据收获动态调整）
            Text(subtitleText)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - 统计数据卡片

    /// 显示行走距离、探索面积、探索时长（带数字跳动动画）
    private func statsCard(result: ExplorationResult) -> some View {
        VStack(spacing: 16) {
            // 卡片标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.info)

                Text("探索统计")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 行走距离（带动画）
            AnimatedStatRow(
                icon: "figure.walk",
                title: "行走距离",
                thisTimeValue: result.stats.walkDistance,
                thisTimeFormatter: formatDistance,
                total: formatDistance(result.stats.totalWalkDistance),
                rank: result.stats.walkDistanceRank,
                animationProgress: numberAnimationProgress
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 探索面积（带动画）
            AnimatedStatRow(
                icon: "square.dashed",
                title: "探索面积",
                thisTimeValue: result.stats.exploredArea,
                thisTimeFormatter: formatArea,
                total: formatArea(result.stats.totalExploredArea),
                rank: result.stats.exploredAreaRank,
                animationProgress: numberAnimationProgress
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 探索时长
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("探索时长")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text(formatDuration(result.stats.duration * numberAnimationProgress))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .contentTransition(.numericText())
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 奖励物品卡片

    /// 显示获得的物品列表（依次出现动画）
    private func lootCard(result: ExplorationResult) -> some View {
        VStack(spacing: 14) {
            // 卡片标题
            HStack {
                Image(systemName: "gift.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(result.loot.count) 件")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            if result.loot.isEmpty {
                // 没有物品时显示提示
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text("本次探索未获得物品")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text("走得更远、搜刮更多 POI 可获得物资")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted.opacity(0.7))
                }
                .padding(.vertical, 20)
            } else {
                // 物品列表（依次出现）
                ForEach(result.loot.indices, id: \.self) { index in
                    if index < lootItemsVisible.count && lootItemsVisible[index] {
                        AnimatedLootItemRow(loot: result.loot[index], isVisible: lootItemsVisible[index])
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }

                // 底部提示（只有有物品时才显示）
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("已添加到背包")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.success)
                }
                .padding(.top, 4)
                .opacity(lootItemsVisible.allSatisfy({ $0 }) ? 1 : 0)
                .animation(.easeIn(duration: 0.3), value: lootItemsVisible)
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 确认按钮

    /// 根据收获情况返回按钮文案和图标
    private var buttonContent: (icon: String, text: String) {
        guard let result = result else { return ("checkmark", "确定") }
        if result.loot.isEmpty {
            return ("figure.walk", "继续探索")
        } else if result.loot.count >= 3 {
            return ("hand.thumbsup.fill", "太棒了！")
        } else {
            return ("checkmark.circle.fill", "不错！")
        }
    }

    /// 底部确认按钮
    private var confirmButton: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 8) {
                Image(systemName: buttonContent.icon)
                    .font(.system(size: 16))

                Text(buttonContent.text)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .padding(.top, 8)
    }

    // MARK: - 方法

    /// 启动入场动画
    private func startAnimations() {
        guard let result = result else { return }

        // 标题出现
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
            showTitle = true
        }

        // 统计卡片出现
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
            showStats = true
        }

        // 数字跳动动画（从0到目标值）
        withAnimation(.easeOut(duration: 1.2).delay(0.5)) {
            numberAnimationProgress = 1.0
        }

        // 奖励卡片出现
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) {
            showLoot = true
        }

        // 物品依次出现（每个间隔0.2秒）
        for index in result.loot.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(index) * 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    if index < self.lootItemsVisible.count {
                        self.lootItemsVisible[index] = true
                    }
                }
            }
        }

        // 确认按钮出现
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.9 + Double(result.loot.count) * 0.2)) {
            showButton = true
        }
    }

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    /// 格式化面积
    private func formatArea(_ sqMeters: Double) -> String {
        if sqMeters >= 1_000_000 {
            return String(format: "%.2f km²", sqMeters / 1_000_000)
        } else if sqMeters >= 10000 {
            return String(format: "%.1f 万m²", sqMeters / 10000)
        }
        return String(format: "%.0f m²", sqMeters)
    }

    /// 格式化时长
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)小时\(remainingMinutes)分钟"
        }
        return "\(minutes)分\(secs)秒"
    }
}

// MARK: - 带动画的统计行组件

/// 单行统计数据（带数字跳动动画）
struct AnimatedStatRow: View {
    let icon: String
    let title: String
    let thisTimeValue: Double
    let thisTimeFormatter: (Double) -> String
    let total: String
    let rank: Int
    let animationProgress: Double

    /// 动画后的当前值
    private var animatedValue: Double {
        thisTimeValue * animationProgress
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧图标
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 20)

            // 中间信息
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 16) {
                    // 本次（数字跳动）
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本次")
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(thisTimeFormatter(animatedValue))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .contentTransition(.numericText())
                    }

                    // 累计
                    VStack(alignment: .leading, spacing: 2) {
                        Text("累计")
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(total)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }

            Spacer()

            // 右侧排名（带弹跳效果）
            VStack(spacing: 2) {
                Text("排名")
                    .font(.system(size: 10))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("#\(Int(Double(rank) * animationProgress))")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.success)
                    .scaleEffect(animationProgress >= 1.0 ? 1.0 : 0.8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animationProgress)
            }
        }
    }
}

// MARK: - 带动画的奖励物品行组件

/// 单个获得物品的行（带出现动画和对勾弹跳）
struct AnimatedLootItemRow: View {
    let loot: ExplorationLoot
    let isVisible: Bool

    /// 背包管理器（用于获取物品定义）
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 对勾弹跳状态
    @State private var checkmarkBounce: Bool = false

    /// 物品定义（优先从数据库获取，否则用本地Mock）
    private var definition: ItemDefinitionDB? {
        inventoryManager.getItemDefinition(by: loot.itemId)
    }

    /// 物品名称
    private var itemName: String {
        definition?.name ?? MockExplorationData.getItemName(by: loot.itemId)
    }

    /// 物品图标
    private var itemIcon: String {
        definition?.icon ?? categoryIcon
    }

    /// 物品分类
    private var categoryString: String {
        definition?.category ?? "other"
    }

    /// 分类图标（fallback）
    private var categoryIcon: String {
        switch categoryString {
        case "water": return "drop.fill"
        case "food": return "fork.knife"
        case "medical": return "cross.case.fill"
        case "material": return "cube.fill"
        case "tool": return "wrench.fill"
        default: return "questionmark.circle.fill"
        }
    }

    /// 分类颜色
    private var categoryColor: Color {
        switch categoryString {
        case "water": return .cyan
        case "food": return .orange
        case "medical": return .red
        case "material": return .brown
        case "tool": return .gray
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: itemIcon)
                    .font(.system(size: 14))
                    .foregroundColor(categoryColor)
            }

            // 物品名称
            Text(itemName)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量
            Text("x\(loot.quantity)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.primary)

            // 对勾（弹跳效果）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkBounce ? 1.0 : 0.3)
                .animation(.spring(response: 0.4, dampingFraction: 0.4), value: checkmarkBounce)
        }
        .padding(.vertical, 6)
        .onAppear {
            // 延迟触发对勾弹跳动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                checkmarkBounce = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExplorationResultView(result: MockExplorationData.mockExplorationResult)
}
