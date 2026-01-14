//
//  ResourcesTabView.swift
//  EarthLord
//
//  资源模块主入口页面
//  包含 POI、背包、已购、领地、交易 五个分段
//

import SwiftUI

/// 资源页面的分段类型
enum ResourceSegment: Int, CaseIterable {
    case poi = 0        // 兴趣点
    case backpack = 1   // 背包
    case purchased = 2  // 已购
    case territory = 3  // 领地
    case trade = 4      // 交易

    var title: String {
        switch self {
        case .poi: return "POI"
        case .backpack: return "背包"
        case .purchased: return "已购"
        case .territory: return "领地"
        case .trade: return "交易"
        }
    }
}

struct ResourcesTabView: View {

    // MARK: - 状态

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradeEnabled: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 分段选择器
                    segmentPicker

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // 右上角交易开关
                ToolbarItem(placement: .topBarTrailing) {
                    tradeToggle
                }
            }
        }
    }

    // MARK: - 分段选择器

    /// 自定义深色风格的分段选择器
    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSegment = segment
                    }
                }) {
                    Text(segment.title)
                        .font(.system(size: 14, weight: selectedSegment == segment ? .semibold : .medium))
                        .foregroundColor(
                            selectedSegment == segment
                                ? ApocalypseTheme.textPrimary
                                : ApocalypseTheme.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedSegment == segment
                                ? ApocalypseTheme.cardBackground
                                : Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(ApocalypseTheme.background.opacity(0.8))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 交易开关

    /// 右上角的交易开关按钮
    private var tradeToggle: some View {
        Button(action: {
            isTradeEnabled.toggle()
            print("🔄 交易模式: \(isTradeEnabled ? "开启" : "关闭")")
        }) {
            HStack(spacing: 4) {
                Image(systemName: isTradeEnabled ? "arrow.left.arrow.right.circle.fill" : "arrow.left.arrow.right.circle")
                    .font(.system(size: 16))

                Text(isTradeEnabled ? "交易中" : "交易")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isTradeEnabled ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isTradeEnabled
                    ? ApocalypseTheme.success.opacity(0.15)
                    : ApocalypseTheme.cardBackground
            )
            .cornerRadius(16)
        }
    }

    // MARK: - 内容区域

    /// 根据选中的分段显示对应内容
    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            // POI 列表页面
            POIContentView()

        case .backpack:
            // 背包页面
            BackpackContentView()

        case .purchased:
            // 已购 - 占位
            placeholderView(
                icon: "bag.fill",
                title: "已购物品",
                subtitle: "功能开发中..."
            )

        case .territory:
            // 领地 - 占位
            placeholderView(
                icon: "flag.fill",
                title: "领地资源",
                subtitle: "功能开发中..."
            )

        case .trade:
            // 交易 - 占位
            placeholderView(
                icon: "arrow.left.arrow.right",
                title: "交易市场",
                subtitle: "功能开发中..."
            )
        }
    }

    // MARK: - 占位视图

    /// 功能开发中的占位视图
    private func placeholderView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - POI 内容视图

/// POI 页面 - 提示用户去地图探索
struct POIContentView: View {

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 图标
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.primary.opacity(0.6))

            // 标题
            Text("探索发现 POI")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明文字
            VStack(spacing: 8) {
                Text("在地图页面点击「探索」按钮")
                Text("系统会自动搜索附近的兴趣点")
                Text("走近 POI 50米范围内即可搜刮物资")
            }
            .font(.system(size: 14))
            .foregroundColor(ApocalypseTheme.textSecondary)
            .multilineTextAlignment(.center)

            // 提示卡片
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("点击地图页「探索」按钮开始")
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                HStack(spacing: 10) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("地图上会显示附近的 POI 标记")
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
                HStack(spacing: 10) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                    Text("走近 POI 并点击搜刮获得物资")
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }
            }
            .font(.system(size: 13))
            .padding(16)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 背包内容视图（去掉导航栏的版本）

/// 嵌入到资源页面的背包（不带自己的 NavigationStack）
/// 使用 InventoryManager 从数据库加载真实数据
struct BackpackContentView: View {

    /// 背包管理器
    @StateObject private var inventoryManager = InventoryManager.shared

    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil  // 使用 String 匹配数据库字段

    /// 容量动画值
    @State private var animatedCapacity: Double = 0

    /// 列表动画ID（用于触发列表刷新动画）
    @State private var listAnimationID: UUID = UUID()

    private let maxCapacity: Double = 100.0

    /// 已使用容量（从数据库计算）
    private var usedCapacity: Double {
        inventoryManager.calculateTotalWeight()
    }

    private var capacityPercentage: Double {
        usedCapacity / maxCapacity
    }

    /// 动画后的容量百分比
    private var animatedCapacityPercentage: Double {
        animatedCapacity / maxCapacity
    }

    private var capacityColor: Color {
        if capacityPercentage > 0.9 { return ApocalypseTheme.danger }
        else if capacityPercentage > 0.7 { return ApocalypseTheme.warning }
        else { return ApocalypseTheme.success }
    }

    /// 筛选后的物品列表
    private var filteredItems: [InventoryItemDB] {
        var result = inventoryManager.items
        if let category = selectedCategory {
            result = result.filter { item in
                inventoryManager.getItemDefinition(by: item.item_id)?.category == category
            }
        }
        if !searchText.isEmpty {
            result = result.filter { item in
                inventoryManager.getItemName(by: item.item_id).localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            capacityCard
            searchAndFilterSection
            itemListView
        }
        .onAppear {
            // 加载背包数据
            Task {
                await inventoryManager.loadInventory()
            }
        }
        .onChange(of: inventoryManager.items) { _, _ in
            // 物品变化时更新容量动画
            withAnimation(.easeOut(duration: 0.8)) {
                animatedCapacity = usedCapacity
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            // 切换分类时触发列表刷新动画
            withAnimation(.easeInOut(duration: 0.3)) {
                listAnimationID = UUID()
            }
        }
        .refreshable {
            // 下拉刷新
            await inventoryManager.loadInventory()
        }
    }

    private var capacityCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("背包容量")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                if inventoryManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    // 容量数字动画
                    Text(String(format: "%.1f / %.0f kg", animatedCapacity, maxCapacity))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .contentTransition(.numericText())
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.textMuted.opacity(0.3))
                        .frame(height: 12)
                    // 进度条动画
                    RoundedRectangle(cornerRadius: 6)
                        .fill(capacityColor)
                        .frame(width: geometry.size.width * min(animatedCapacityPercentage, 1.0), height: 12)
                        .animation(.easeOut(duration: 0.8), value: animatedCapacity)
                }
            }
            .frame(height: 12)

            if capacityPercentage > 0.9 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("背包快满了！")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
    }

    private var searchAndFilterSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textMuted)
                TextField("搜索物品...", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textPrimary)
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    CategoryChip(title: "全部", icon: "square.grid.2x2.fill", color: ApocalypseTheme.primary, isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    CategoryChip(title: "食物", icon: "fork.knife", color: .orange, isSelected: selectedCategory == "food") {
                        selectedCategory = "food"
                    }
                    CategoryChip(title: "水", icon: "drop.fill", color: .cyan, isSelected: selectedCategory == "water") {
                        selectedCategory = "water"
                    }
                    CategoryChip(title: "材料", icon: "cube.fill", color: .brown, isSelected: selectedCategory == "material") {
                        selectedCategory = "material"
                    }
                    CategoryChip(title: "工具", icon: "wrench.fill", color: .gray, isSelected: selectedCategory == "tool") {
                        selectedCategory = "tool"
                    }
                    CategoryChip(title: "医疗", icon: "cross.case.fill", color: .red, isSelected: selectedCategory == "medical") {
                        selectedCategory = "medical"
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .padding(.top, 8)
    }

    private var itemListView: some View {
        Group {
            if inventoryManager.isLoading && inventoryManager.items.isEmpty {
                // 首次加载中
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载中...")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = inventoryManager.errorMessage {
                // 加载错误
                ErrorStateView(
                    title: "加载失败",
                    message: error,
                    retryAction: {
                        Task {
                            await inventoryManager.loadInventory()
                        }
                    }
                )
            } else if inventoryManager.items.isEmpty {
                // 背包完全是空的
                EmptyStateView(
                    icon: "bag",
                    title: "背包空空如也",
                    subtitle: "去探索收集物资吧"
                )
            } else if filteredItems.isEmpty {
                // 搜索/筛选后没有结果
                VStack(spacing: 16) {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "没有找到相关物品",
                        subtitle: "试试其他关键词或分类"
                    )

                    Button(action: {
                        searchText = ""
                        selectedCategory = nil
                    }) {
                        Text("清除筛选")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(8)
                    }
                }
                .transition(.opacity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            InventoryItemCard(
                                item: item,
                                inventoryManager: inventoryManager,
                                onUse: {
                                    print("🎒 使用: \(inventoryManager.getItemName(by: item.item_id))")
                                    // TODO: 实现使用物品逻辑
                                },
                                onDiscard: {
                                    print("🗑️ 丢弃: \(inventoryManager.getItemName(by: item.item_id))")
                                    Task {
                                        await inventoryManager.removeItem(itemId: item.item_id, quantity: 1)
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .id(listAnimationID)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedCategory)
        .animation(.easeInOut(duration: 0.3), value: searchText)
    }
}

// MARK: - 背包物品卡片（数据库版本）

/// 显示单个背包物品的卡片
struct InventoryItemCard: View {
    let item: InventoryItemDB
    let inventoryManager: InventoryManager
    let onUse: () -> Void
    let onDiscard: () -> Void

    /// 物品定义
    private var definition: ItemDefinitionDB? {
        inventoryManager.getItemDefinition(by: item.item_id)
    }

    /// 物品名称
    private var itemName: String {
        definition?.name ?? "未知物品"
    }

    /// 物品图标
    private var itemIcon: String {
        definition?.icon ?? "questionmark.circle"
    }

    /// 物品稀有度颜色
    private var rarityColor: Color {
        switch definition?.rarity {
        case "epic": return .purple
        case "rare": return .blue
        default: return .gray
        }
    }

    /// 物品分类颜色
    private var categoryColor: Color {
        switch definition?.category {
        case "food": return .orange
        case "water": return .cyan
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
                    .frame(width: 44, height: 44)

                Image(systemName: itemIcon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(itemName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 稀有度标签
                    if definition?.rarity == "epic" {
                        Text("史诗")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .cornerRadius(4)
                    } else if definition?.rarity == "rare" {
                        Text("稀有")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }

                // 描述或重量
                if let weight = definition?.weight {
                    Text("单重 \(String(format: "%.1f", weight)) kg")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 10)

            // 操作按钮
            Menu {
                Button(action: onUse) {
                    Label("使用", systemImage: "hand.tap")
                }
                Button(role: .destructive, action: onDiscard) {
                    Label("丢弃", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 分类筛选芯片

/// 分类筛选按钮组件
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
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? color : ApocalypseTheme.cardBackground
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 通用空状态视图

/// 空状态显示组件
/// 用于各种列表为空时的占位显示
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            // 大图标
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 主标题
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 副标题
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - 通用错误状态视图

/// 错误状态显示组件
/// 用于加载失败或操作出错时的占位显示
struct ErrorStateView: View {
    let icon: String
    let title: String
    let message: String
    let retryAction: (() -> Void)?

    init(icon: String = "exclamationmark.triangle", title: String = "出错了", message: String, retryAction: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 16) {
            // 错误图标
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.danger)

            // 标题
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 错误信息
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            // 重试按钮
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                        Text("重试")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - Preview

#Preview {
    ResourcesTabView()
}
