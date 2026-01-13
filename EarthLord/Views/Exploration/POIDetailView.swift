//
//  POIDetailView.swift
//  EarthLord
//
//  POI 详情页面
//  显示兴趣点的详细信息，提供搜寻和标记操作
//

import SwiftUI

struct POIDetailView: View {

    // MARK: - 参数

    /// 要显示的 POI
    let poi: POI

    // MARK: - 状态

    /// 是否显示探索结果弹窗
    @State private var showExplorationResult: Bool = false

    /// 是否正在执行搜寻
    @State private var isExploring: Bool = false

    // MARK: - 环境

    @Environment(\.dismiss) private var dismiss

    // MARK: - 假数据

    /// 假的距离数据
    private let mockDistance: Int = 350

    /// 假的来源
    private let mockSource: String = "地图数据"

    // MARK: - 计算属性

    /// POI 类型对应的渐变色
    private var typeGradient: LinearGradient {
        let colors: [Color]
        switch poi.type {
        case .hospital:
            colors = [Color.red.opacity(0.8), Color.red.opacity(0.4)]
        case .supermarket:
            colors = [Color.green.opacity(0.8), Color.green.opacity(0.4)]
        case .factory:
            colors = [Color.gray.opacity(0.8), Color.gray.opacity(0.4)]
        case .pharmacy:
            colors = [Color.purple.opacity(0.8), Color.purple.opacity(0.4)]
        case .gasStation:
            colors = [Color.orange.opacity(0.8), Color.orange.opacity(0.4)]
        case .warehouse:
            colors = [Color.brown.opacity(0.8), Color.brown.opacity(0.4)]
        case .residential:
            colors = [Color.blue.opacity(0.8), Color.blue.opacity(0.4)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// POI 类型对应的图标
    private var typeIcon: String {
        switch poi.type {
        case .hospital: return "cross.case.fill"
        case .supermarket: return "cart.fill"
        case .factory: return "building.2.fill"
        case .pharmacy: return "pills.fill"
        case .gasStation: return "fuelpump.fill"
        case .warehouse: return "shippingbox.fill"
        case .residential: return "house.fill"
        }
    }

    /// 危险等级文字
    private var dangerLevelText: String {
        switch poi.dangerLevel {
        case 1: return "安全"
        case 2: return "低危"
        case 3: return "中危"
        case 4: return "高危"
        case 5: return "极危"
        default: return "未知"
        }
    }

    /// 危险等级颜色
    private var dangerLevelColor: Color {
        switch poi.dangerLevel {
        case 1: return ApocalypseTheme.success
        case 2: return .green
        case 3: return ApocalypseTheme.warning
        case 4: return .orange
        case 5: return ApocalypseTheme.danger
        default: return ApocalypseTheme.textMuted
        }
    }

    /// 物资状态文字
    private var resourceStatusText: String {
        switch poi.resourceStatus {
        case .hasResources: return "有物资"
        case .empty: return "已清空"
        case .unknown: return "未知"
        }
    }

    /// 物资状态颜色
    private var resourceStatusColor: Color {
        switch poi.resourceStatus {
        case .hasResources: return ApocalypseTheme.success
        case .empty: return ApocalypseTheme.textMuted
        case .unknown: return ApocalypseTheme.info
        }
    }

    /// 是否可以搜寻（已清空的不能搜寻）
    private var canExplore: Bool {
        poi.resourceStatus != .empty
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部大图区域
                headerSection

                // 内容区域
                ScrollView {
                    VStack(spacing: 16) {
                        // 信息卡片
                        infoCard

                        // 描述文字
                        descriptionCard

                        // 操作按钮
                        actionButtons
                    }
                    .padding(16)
                }
            }

        }
        .sheet(isPresented: $showExplorationResult) {
            // 使用完整的探索结果页面，传递假数据
            ExplorationResultView(result: MockExplorationData.mockExplorationResult)
        }
        .navigationBarBackButtonHidden(false)
    }

    // MARK: - 顶部大图区域

    /// 顶部展示区：渐变背景 + 大图标 + POI名称
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            typeGradient
                .frame(height: 280)

            // 大图标
            VStack {
                Spacer()

                Image(systemName: typeIcon)
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                Spacer()
            }
            .frame(height: 280)

            // 底部半透明遮罩 + 文字
            VStack(alignment: .leading, spacing: 4) {
                Text(poi.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text(poi.type.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - 信息卡片

    /// 显示距离、物资状态、危险等级、来源的卡片
    private var infoCard: some View {
        VStack(spacing: 0) {
            // 第一行：距离 + 物资状态
            HStack {
                // 距离
                InfoItem(
                    icon: "location.fill",
                    title: "距离",
                    value: "\(mockDistance)米",
                    valueColor: ApocalypseTheme.textPrimary
                )

                Divider()
                    .frame(height: 40)
                    .background(ApocalypseTheme.textMuted)

                // 物资状态
                InfoItem(
                    icon: "shippingbox.fill",
                    title: "物资状态",
                    value: resourceStatusText,
                    valueColor: resourceStatusColor
                )
            }
            .padding(.vertical, 12)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 第二行：危险等级 + 来源
            HStack {
                // 危险等级
                InfoItem(
                    icon: "exclamationmark.triangle.fill",
                    title: "危险等级",
                    value: dangerLevelText,
                    valueColor: dangerLevelColor
                )

                Divider()
                    .frame(height: 40)
                    .background(ApocalypseTheme.textMuted)

                // 来源
                InfoItem(
                    icon: "doc.text.fill",
                    title: "来源",
                    value: mockSource,
                    valueColor: ApocalypseTheme.textSecondary
                )
            }
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 描述卡片

    /// POI 描述文字卡片
    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("地点描述")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(poi.description)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 操作按钮

    /// 搜寻按钮 + 标记按钮
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 主按钮：搜寻此POI
            Button(action: startExploration) {
                HStack(spacing: 10) {
                    if isExploring {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        Text("搜寻中...")
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                        Text("搜寻此POI")
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    canExplore && !isExploring
                        ? LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                          )
                        : LinearGradient(
                            colors: [ApocalypseTheme.textMuted, ApocalypseTheme.textMuted],
                            startPoint: .leading,
                            endPoint: .trailing
                          )
                )
                .cornerRadius(12)
            }
            .disabled(!canExplore || isExploring)

            // 不可搜寻时显示提示
            if !canExplore {
                Text("此地点已被清空，无法再次搜寻")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 两个小按钮并排
            HStack(spacing: 12) {
                // 标记已发现
                SecondaryButton(
                    title: "标记已发现",
                    icon: "eye.fill"
                ) {
                    handleMarkDiscovered()
                }

                // 标记无物资
                SecondaryButton(
                    title: "标记无物资",
                    icon: "xmark.bin.fill"
                ) {
                    handleMarkEmpty()
                }
            }
        }
    }

    // MARK: - 方法

    /// 开始搜寻POI
    private func startExploration() {
        guard canExplore else { return }

        isExploring = true
        print("🔍 开始搜寻 POI: \(poi.name)")

        // 模拟搜寻过程（2秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isExploring = false
            showExplorationResult = true
            print("✅ 搜寻完成，显示结果")
        }
    }

    /// 标记已发现
    private func handleMarkDiscovered() {
        print("👁️ 标记 POI 为已发现: \(poi.name)")
        // TODO: 更新 POI 状态
    }

    /// 标记无物资
    private func handleMarkEmpty() {
        print("📭 标记 POI 为无物资: \(poi.name)")
        // TODO: 更新 POI 状态
    }
}

// MARK: - 信息项组件

/// 单个信息项（图标 + 标题 + 数值）
struct InfoItem: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 次要按钮组件

/// 次要操作按钮（标记已发现、标记无物资）
struct SecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 探索结果弹窗

/// 搜寻POI后显示的结果页面
struct ExplorationResultSheet: View {
    let poi: POI

    @Environment(\.dismiss) private var dismiss

    /// 模拟获得的物品
    private let mockLoot: [(name: String, quantity: Int)] = [
        ("矿泉水", 2),
        ("罐头食品", 1),
        ("绷带", 3)
    ]

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 成功图标
                ZStack {
                    Circle()
                        .fill(ApocalypseTheme.success.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(ApocalypseTheme.success)
                }
                .padding(.top, 40)

                // 标题
                VStack(spacing: 8) {
                    Text("搜寻完成！")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("在 \(poi.name) 发现了以下物资")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 获得物品列表
                VStack(spacing: 10) {
                    ForEach(mockLoot, id: \.name) { item in
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(ApocalypseTheme.success)

                            Text(item.name)
                                .font(.system(size: 15))
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            Spacer()

                            Text("x\(item.quantity)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // 确认按钮
                Button(action: { dismiss() }) {
                    Text("太棒了！")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    POIDetailView(poi: MockExplorationData.mockPOIs[0])
}
