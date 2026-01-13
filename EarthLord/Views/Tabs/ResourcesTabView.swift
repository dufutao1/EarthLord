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

// MARK: - POI 内容视图（去掉导航栏的版本）

/// 嵌入到资源页面的 POI 列表（不带自己的 NavigationStack）
struct POIContentView: View {

    @State private var poiList: [POI] = MockExplorationData.mockPOIs
    @State private var selectedCategory: POIType? = nil
    @State private var isSearching: Bool = false

    /// 搜索按钮缩放状态
    @State private var searchButtonScale: CGFloat = 1.0

    /// POI 列表出现动画状态
    @State private var poiItemsVisible: [String: Bool] = [:]

    /// 是否已触发过列表动画
    @State private var hasAnimatedList: Bool = false

    private let mockLatitude: Double = 22.54
    private let mockLongitude: Double = 114.06

    private var filteredPOIs: [POI] {
        if let category = selectedCategory {
            return poiList.filter { $0.type == category }
        }
        return poiList
    }

    private var discoveredCount: Int {
        poiList.filter { $0.discoveryStatus == .discovered }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // 状态栏
            statusBar

            // 搜索按钮
            searchButton

            // 筛选工具栏
            filterToolbar

            // POI 列表
            poiListView
        }
    }

    private var statusBar: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.success)

                Text(String(format: "%.2f, %.2f", mockLatitude, mockLongitude))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Text("附近发现 \(discoveredCount) 个地点")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
    }

    private var searchButton: some View {
        Button(action: {
            // 按钮缩放动画
            withAnimation(.easeInOut(duration: 0.1)) {
                searchButtonScale = 0.95
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    searchButtonScale = 1.0
                }
            }

            isSearching = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isSearching = false
                print("🔍 搜索完成")
                // 重新触发列表动画
                triggerListAnimation()
            }
        }) {
            HStack(spacing: 10) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                    Text("搜索中...")
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                    Text("搜索附近POI")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSearching ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            .cornerRadius(12)
        }
        .scaleEffect(searchButtonScale)
        .disabled(isSearching)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 触发 POI 列表依次出现动画
    private func triggerListAnimation() {
        // 先重置所有状态
        poiItemsVisible = [:]

        // 依次显示每个 POI
        for (index, poi) in filteredPOIs.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    poiItemsVisible[poi.id] = true
                }
            }
        }
    }

    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "全部", icon: "square.grid.2x2.fill", color: ApocalypseTheme.primary, isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                FilterChip(title: "医院", icon: "cross.case.fill", color: .red, isSelected: selectedCategory == .hospital) {
                    selectedCategory = .hospital
                }
                FilterChip(title: "超市", icon: "cart.fill", color: .green, isSelected: selectedCategory == .supermarket) {
                    selectedCategory = .supermarket
                }
                FilterChip(title: "工厂", icon: "building.2.fill", color: .gray, isSelected: selectedCategory == .factory) {
                    selectedCategory = .factory
                }
                FilterChip(title: "药店", icon: "pills.fill", color: .purple, isSelected: selectedCategory == .pharmacy) {
                    selectedCategory = .pharmacy
                }
                FilterChip(title: "加油站", icon: "fuelpump.fill", color: .orange, isSelected: selectedCategory == .gasStation) {
                    selectedCategory = .gasStation
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    private var poiListView: some View {
        Group {
            if poiList.isEmpty {
                // 完全没有POI的空状态
                EmptyStateView(
                    icon: "map",
                    title: "附近暂无兴趣点",
                    subtitle: "点击搜索按钮发现周围的废墟"
                )
            } else if filteredPOIs.isEmpty {
                // 筛选后没有结果
                EmptyStateView(
                    icon: "mappin.slash",
                    title: "没有找到该类型的地点",
                    subtitle: "试试其他分类或清除筛选"
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(filteredPOIs) { poi in
                            // 使用 NavigationLink 跳转到详情页
                            NavigationLink(destination: POIDetailView(poi: poi)) {
                                POICard(poi: poi)
                            }
                            .buttonStyle(PlainButtonStyle())
                            // 依次出现动画
                            .opacity(poiItemsVisible[poi.id] == true ? 1 : 0)
                            .offset(y: poiItemsVisible[poi.id] == true ? 0 : 20)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .onAppear {
            // 首次出现时触发动画
            if !hasAnimatedList {
                hasAnimatedList = true
                triggerListAnimation()
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            // 切换分类时重新触发动画
            triggerListAnimation()
        }
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
