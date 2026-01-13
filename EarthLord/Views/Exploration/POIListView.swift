//
//  POIListView.swift
//  EarthLord
//
//  附近兴趣点列表页面
//  显示周围可探索的地点，支持分类筛选
//

import SwiftUI

struct POIListView: View {

    // MARK: - 状态

    /// POI 列表数据（从假数据加载）
    @State private var poiList: [POI] = MockExplorationData.mockPOIs

    /// 当前选中的筛选分类（nil 表示"全部"）
    @State private var selectedCategory: POIType? = nil

    /// 是否正在搜索
    @State private var isSearching: Bool = false

    /// 假的 GPS 坐标
    private let mockLatitude: Double = 22.54
    private let mockLongitude: Double = 114.06

    // MARK: - 计算属性

    /// 筛选后的 POI 列表
    private var filteredPOIs: [POI] {
        if let category = selectedCategory {
            return poiList.filter { $0.type == category }
        }
        return poiList
    }

    /// 已发现的 POI 数量
    private var discoveredCount: Int {
        poiList.filter { $0.discoveryStatus == .discovered }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

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
            .navigationTitle("附近地点")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 状态栏

    /// 顶部状态栏：显示 GPS 坐标和发现数量
    private var statusBar: some View {
        HStack {
            // GPS 坐标
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.success)

                Text(String(format: "%.2f, %.2f", mockLatitude, mockLongitude))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 发现数量
            Text("附近发现 \(discoveredCount) 个地点")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 搜索按钮

    /// 搜索附近 POI 的大按钮
    private var searchButton: some View {
        Button(action: performSearch) {
            HStack(spacing: 10) {
                if isSearching {
                    // 搜索中状态
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    // 正常状态
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSearching
                    ? ApocalypseTheme.textMuted
                    : ApocalypseTheme.primary
            )
            .cornerRadius(12)
        }
        .disabled(isSearching)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 筛选工具栏

    /// 横向滚动的分类筛选按钮
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "全部"按钮
                FilterChip(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // 各分类按钮
                FilterChip(
                    title: "医院",
                    icon: "cross.case.fill",
                    color: .red,
                    isSelected: selectedCategory == .hospital
                ) {
                    selectedCategory = .hospital
                }

                FilterChip(
                    title: "超市",
                    icon: "cart.fill",
                    color: .green,
                    isSelected: selectedCategory == .supermarket
                ) {
                    selectedCategory = .supermarket
                }

                FilterChip(
                    title: "工厂",
                    icon: "building.2.fill",
                    color: .gray,
                    isSelected: selectedCategory == .factory
                ) {
                    selectedCategory = .factory
                }

                FilterChip(
                    title: "药店",
                    icon: "pills.fill",
                    color: .purple,
                    isSelected: selectedCategory == .pharmacy
                ) {
                    selectedCategory = .pharmacy
                }

                FilterChip(
                    title: "加油站",
                    icon: "fuelpump.fill",
                    color: .orange,
                    isSelected: selectedCategory == .gasStation
                ) {
                    selectedCategory = .gasStation
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
    }

    // MARK: - POI 列表

    /// POI 卡片列表
    private var poiListView: some View {
        Group {
            if filteredPOIs.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("没有找到该类型的地点")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // POI 列表
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(filteredPOIs) { poi in
                            POICard(poi: poi)
                                .onTapGesture {
                                    handlePOITap(poi)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - 方法

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        isSearching = true

        // 模拟 1.5 秒的网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            // 这里可以刷新数据，目前用假数据所以不变
            print("🔍 搜索完成，找到 \(poiList.count) 个 POI")
        }
    }

    /// 处理 POI 点击
    private func handlePOITap(_ poi: POI) {
        // TODO: 跳转到 POI 详情页
        print("📍 点击了 POI: \(poi.name)")
        print("   - 类型: \(poi.type.displayName)")
        print("   - 发现状态: \(poi.discoveryStatus.rawValue)")
        print("   - 资源状态: \(poi.resourceStatus.rawValue)")
        print("   - 危险等级: \(poi.dangerLevel)")
    }
}

// MARK: - 筛选按钮组件

/// 分类筛选的小按钮（Chip）
struct FilterChip: View {
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

// MARK: - POI 卡片组件

/// 单个 POI 的卡片视图
struct POICard: View {
    let poi: POI

    /// 根据 POI 类型返回对应的颜色
    private var typeColor: Color {
        switch poi.type {
        case .hospital: return .red
        case .supermarket: return .green
        case .factory: return .gray
        case .pharmacy: return .purple
        case .gasStation: return .orange
        case .warehouse: return .brown
        case .residential: return .blue
        }
    }

    /// 根据 POI 类型返回对应的图标
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

    /// 发现状态文字
    private var discoveryText: String {
        switch poi.discoveryStatus {
        case .discovered: return "已发现"
        case .undiscovered: return "未发现"
        }
    }

    /// 发现状态颜色
    private var discoveryColor: Color {
        switch poi.discoveryStatus {
        case .discovered: return ApocalypseTheme.success
        case .undiscovered: return ApocalypseTheme.textMuted
        }
    }

    /// 资源状态文字
    private var resourceText: String {
        switch poi.resourceStatus {
        case .hasResources: return "有物资"
        case .empty: return "已搜空"
        case .unknown: return "未知"
        }
    }

    /// 资源状态颜色
    private var resourceColor: Color {
        switch poi.resourceStatus {
        case .hasResources: return ApocalypseTheme.warning
        case .empty: return ApocalypseTheme.textMuted
        case .unknown: return ApocalypseTheme.info
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧类型图标
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: typeIcon)
                    .font(.system(size: 20))
                    .foregroundColor(typeColor)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 6) {
                // 名称
                Text(poi.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 类型
                Text(poi.type.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                // 状态标签
                HStack(spacing: 8) {
                    // 发现状态
                    StatusTag(text: discoveryText, color: discoveryColor)

                    // 资源状态
                    StatusTag(text: resourceText, color: resourceColor)

                    // 危险等级
                    if poi.dangerLevel >= 3 {
                        StatusTag(
                            text: "危险 Lv.\(poi.dangerLevel)",
                            color: ApocalypseTheme.danger
                        )
                    }
                }
            }

            Spacer()

            // 右侧箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - 状态标签组件

/// 小状态标签
struct StatusTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    POIListView()
}
