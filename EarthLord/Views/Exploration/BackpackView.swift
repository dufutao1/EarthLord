//
//  BackpackView.swift
//  EarthLord
//
//  背包管理页面
//  显示玩家携带的物品，支持搜索、筛选、使用和存储操作
//

import SwiftUI

struct BackpackView: View {

    // MARK: - 状态

    /// 背包物品列表（从假数据加载）
    @State private var backpackItems: [BackpackItem] = MockExplorationData.mockBackpackItems

    /// 搜索文字
    @State private var searchText: String = ""

    /// 当前选中的筛选分类（nil 表示"全部"）
    @State private var selectedCategory: ItemCategory? = nil

    /// 背包最大容量（假数据）
    private let maxCapacity: Double = 100.0

    // MARK: - 计算属性

    /// 当前背包已用容量
    private var usedCapacity: Double {
        MockExplorationData.calculateTotalWeight(items: backpackItems)
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        usedCapacity / maxCapacity
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    /// 筛选后的物品列表
    private var filteredItems: [BackpackItem] {
        var result = backpackItems

        // 按分类筛选
        if let category = selectedCategory {
            result = result.filter { item in
                let definition = MockExplorationData.getItemDefinition(by: item.itemId)
                return definition?.category == category
            }
        }

        // 按搜索文字筛选
        if !searchText.isEmpty {
            result = result.filter { item in
                let name = MockExplorationData.getItemName(by: item.itemId)
                return name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 容量状态卡
                    capacityCard

                    // 搜索和筛选
                    searchAndFilterSection

                    // 物品列表
                    itemListView
                }
            }
            .navigationTitle("背包")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 容量状态卡

    /// 显示背包容量使用情况
    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 标题和数值
            HStack {
                Text("背包容量")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text(String(format: "%.1f / %.0f kg", usedCapacity, maxCapacity))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.textMuted.opacity(0.3))
                        .frame(height: 12)

                    // 进度条
                    RoundedRectangle(cornerRadius: 6)
                        .fill(capacityColor)
                        .frame(width: geometry.size.width * min(capacityPercentage, 1.0), height: 12)
                }
            }
            .frame(height: 12)

            // 警告文字（容量超过90%时显示）
            if capacityPercentage > 0.9 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))

                    Text("背包快满了！")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 搜索和筛选

    /// 搜索框和分类筛选按钮
    private var searchAndFilterSection: some View {
        VStack(spacing: 10) {
            // 搜索框
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textMuted)

                TextField("搜索物品...", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 清除按钮
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .padding(.horizontal, 16)

            // 分类筛选按钮
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // 全部
                    CategoryChip(
                        title: "全部",
                        icon: "square.grid.2x2.fill",
                        color: ApocalypseTheme.primary,
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    // 食物
                    CategoryChip(
                        title: "食物",
                        icon: "fork.knife",
                        color: .orange,
                        isSelected: selectedCategory == .food
                    ) {
                        selectedCategory = .food
                    }

                    // 水
                    CategoryChip(
                        title: "水",
                        icon: "drop.fill",
                        color: .cyan,
                        isSelected: selectedCategory == .water
                    ) {
                        selectedCategory = .water
                    }

                    // 材料
                    CategoryChip(
                        title: "材料",
                        icon: "cube.fill",
                        color: .brown,
                        isSelected: selectedCategory == .material
                    ) {
                        selectedCategory = .material
                    }

                    // 工具
                    CategoryChip(
                        title: "工具",
                        icon: "wrench.fill",
                        color: .gray,
                        isSelected: selectedCategory == .tool
                    ) {
                        selectedCategory = .tool
                    }

                    // 医疗
                    CategoryChip(
                        title: "医疗",
                        icon: "cross.case.fill",
                        color: .red,
                        isSelected: selectedCategory == .medical
                    ) {
                        selectedCategory = .medical
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 物品列表

    /// 物品卡片列表或空状态
    private var itemListView: some View {
        Group {
            if filteredItems.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 50))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(searchText.isEmpty && selectedCategory == nil
                         ? "背包是空的"
                         : "没有找到符合条件的物品")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    if !searchText.isEmpty || selectedCategory != nil {
                        Button("清除筛选") {
                            searchText = ""
                            selectedCategory = nil
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.primary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 物品列表
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            BackpackItemCard(
                                item: item,
                                onUse: { handleUseItem(item) },
                                onStore: { handleStoreItem(item) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - 方法

    /// 使用物品
    private func handleUseItem(_ item: BackpackItem) {
        let name = MockExplorationData.getItemName(by: item.itemId)
        print("🎒 使用物品: \(name)")
        print("   - 数量: \(item.quantity)")
        print("   - 品质: \(item.quality?.displayName ?? "无")")
        // TODO: 实现使用物品的逻辑
    }

    /// 存储物品（放入仓库）
    private func handleStoreItem(_ item: BackpackItem) {
        let name = MockExplorationData.getItemName(by: item.itemId)
        print("📦 存储物品: \(name)")
        print("   - 数量: \(item.quantity)")
        // TODO: 实现存储物品的逻辑
    }
}

// MARK: - 分类筛选按钮组件

/// 分类筛选的小按钮
struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? color
                    : color.opacity(0.15)
            )
            .cornerRadius(20)
        }
    }
}

// MARK: - 背包物品卡片组件

/// 单个物品的卡片视图
struct BackpackItemCard: View {
    let item: BackpackItem
    let onUse: () -> Void
    let onStore: () -> Void

    /// 物品定义
    private var definition: ItemDefinition? {
        MockExplorationData.getItemDefinition(by: item.itemId)
    }

    /// 物品名称
    private var itemName: String {
        definition?.name ?? "未知物品"
    }

    /// 物品分类
    private var category: ItemCategory {
        definition?.category ?? .misc
    }

    /// 物品稀有度
    private var rarity: ItemRarity {
        definition?.rarity ?? .common
    }

    /// 单个物品重量
    private var weight: Double {
        definition?.weight ?? 0
    }

    /// 分类图标
    private var categoryIcon: String {
        switch category {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.fill"
        case .weapon: return "bolt.fill"
        case .clothing: return "tshirt.fill"
        case .misc: return "questionmark.circle.fill"
        }
    }

    /// 分类颜色
    private var categoryColor: Color {
        switch category {
        case .water: return .cyan
        case .food: return .orange
        case .medical: return .red
        case .material: return .brown
        case .tool: return .gray
        case .weapon: return .red
        case .clothing: return .blue
        case .misc: return .gray
        }
    }

    /// 稀有度颜色
    private var rarityColor: Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    /// 品质颜色
    private var qualityColor: Color {
        guard let quality = item.quality else { return .clear }
        switch quality {
        case .poor: return .gray
        case .normal: return .white
        case .good: return .green
        case .excellent: return .blue
        case .rare: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧分类图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 46, height: 46)

                Image(systemName: categoryIcon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            // 中间物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 第一行：名称和数量
                HStack(spacing: 6) {
                    Text(itemName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("x\(item.quantity)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 第二行：重量、品质、稀有度
                HStack(spacing: 8) {
                    // 重量
                    Text(String(format: "%.1fkg", weight * Double(item.quantity)))
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 品质（如果有）
                    if let quality = item.quality {
                        Text(quality.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(qualityColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(qualityColor.opacity(0.15))
                            .cornerRadius(4)
                    }

                    // 稀有度标签
                    Text(rarity.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(rarityColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(rarityColor.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            Spacer()

            // 右侧操作按钮
            VStack(spacing: 6) {
                // 使用按钮
                Button(action: onUse) {
                    Text("使用")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(6)
                }

                // 存储按钮
                Button(action: onStore) {
                    Text("存储")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ApocalypseTheme.textMuted.opacity(0.3))
                        .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    BackpackView()
}
