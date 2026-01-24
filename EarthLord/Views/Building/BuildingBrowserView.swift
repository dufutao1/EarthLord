//
//  BuildingBrowserView.swift
//  EarthLord
//
//  建筑浏览器
//  分类筛选 + 建筑卡片网格
//

import SwiftUI

// MARK: - 建筑浏览器

struct BuildingBrowserView: View {
    let territoryId: String
    let onDismiss: () -> Void
    let onStartConstruction: (BuildingTemplate) -> Void

    @StateObject private var buildingManager = BuildingManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared
    @State private var selectedCategory: BuildingCategory? = nil
    @State private var selectedTemplate: BuildingTemplate?
    @State private var showTemplateDetail = false
    @State private var isLoadingResources = true

    // 两列网格
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类筛选器
                categoryPicker

                Divider()

                // 建筑网格
                buildingGrid
            }
            .navigationTitle("建筑浏览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        onDismiss()
                    }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                BuildingTemplateDetailView(
                    template: template,
                    canBuild: checkCanBuild(template).canBuild,
                    missingResources: getMissingResources(template),
                    onDismiss: { selectedTemplate = nil },
                    onStartConstruction: {
                        selectedTemplate = nil
                        // 延迟 0.3s 等待关闭动画
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onStartConstruction(template)
                        }
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .task {
                // 加载背包数据以检查资源
                await inventoryManager.loadInventory()
                isLoadingResources = false
                print("✅ [BuildingBrowser] 背包数据加载完成，物品数量: \(inventoryManager.items.count)")
            }
            .overlay {
                if isLoadingResources {
                    ProgressView("加载资源数据...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground).opacity(0.8))
                }
            }
        }
    }

    // MARK: - 分类筛选器

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部" 选项
                categoryButton(nil, name: "全部")

                // 各分类
                ForEach(BuildingCategory.allCases, id: \.self) { category in
                    categoryButton(category, name: category.displayName)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(UIColor.systemBackground))
    }

    private func categoryButton(_ category: BuildingCategory?, name: String) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            Text(name)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(UIColor.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 建筑网格

    private var buildingGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredTemplates) { template in
                    let (canBuild, _) = checkCanBuild(template)
                    let missingResources = getMissingResources(template)

                    BuildingCard(
                        template: template,
                        canBuild: canBuild,
                        missingResources: missingResources,
                        onTap: {
                            selectedTemplate = template
                        }
                    )
                }
            }
            .padding(16)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - 筛选后的模板

    private var filteredTemplates: [BuildingTemplate] {
        if let category = selectedCategory {
            return buildingManager.buildingTemplates.filter { $0.category == category }
        } else {
            return buildingManager.buildingTemplates
        }
    }

    // MARK: - 检查是否可建造

    private func checkCanBuild(_ template: BuildingTemplate) -> (canBuild: Bool, error: BuildingError?) {
        let resources = buildingManager.getPlayerResources()
        return buildingManager.canBuild(
            template: template,
            territoryId: territoryId,
            playerResources: resources
        )
    }

    // MARK: - 获取缺少的资源

    private func getMissingResources(_ template: BuildingTemplate) -> [String: Int] {
        let resources = buildingManager.getPlayerResources()
        var missing: [String: Int] = [:]

        for (resourceId, required) in template.requiredResources {
            let available = resources[resourceId] ?? 0
            if available < required {
                missing[resourceId] = required - available
            }
        }

        return missing
    }
}

// MARK: - 建筑模板详情视图

struct BuildingTemplateDetailView: View {
    let template: BuildingTemplate
    let canBuild: Bool
    let missingResources: [String: Int]
    let onDismiss: () -> Void
    let onStartConstruction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 图标和名称
                    headerSection

                    // 描述
                    descriptionSection

                    // 资源需求
                    resourcesSection

                    // 建造信息
                    buildInfoSection

                    Spacer(minLength: 20)

                    // 建造按钮
                    constructButton
                }
                .padding(20)
            }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onDismiss()
                    }
                }
            }
        }
    }

    // MARK: - 头部

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: template.icon)
                    .font(.system(size: 40))
                    .foregroundColor(categoryColor)
            }

            VStack(spacing: 4) {
                Text(template.name)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Label(template.category.displayName, systemImage: categoryIcon)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text("Tier \(template.tier)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 描述

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("描述")
                .font(.headline)

            Text(template.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 资源需求

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建造需求")
                .font(.headline)

            ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resourceId in
                let required = template.requiredResources[resourceId] ?? 0
                let missing = missingResources[resourceId] ?? 0
                let isSufficient = missing == 0

                HStack {
                    Image(systemName: resourceIcon(for: resourceId))
                        .foregroundColor(isSufficient ? .green : .red)
                        .frame(width: 24)

                    Text(resourceDisplayName(for: resourceId))
                        .foregroundColor(.primary)

                    Spacer()

                    if isSufficient {
                        Text("\(required)")
                            .foregroundColor(.green)
                            .fontWeight(.medium)

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Text("\(required)")
                            .foregroundColor(.red)
                            .fontWeight(.medium)

                        Text("(缺少\(missing))")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 建造信息

    private var buildInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("建造信息")
                .font(.headline)

            HStack {
                Label("建造时间", systemImage: "clock")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatBuildTime(template.buildTimeSeconds))
                    .fontWeight(.medium)
            }

            HStack {
                Label("最大等级", systemImage: "arrow.up.circle")
                    .foregroundColor(.secondary)
                Spacer()
                Text("Lv.\(template.maxLevel)")
                    .fontWeight(.medium)
            }

            HStack {
                Label("领地上限", systemImage: "building.2")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(template.maxPerTerritory)个")
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 建造按钮

    private var constructButton: some View {
        Button {
            onStartConstruction()
        } label: {
            HStack {
                Image(systemName: "hammer.fill")
                Text(canBuild ? "开始建造" : "资源不足")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canBuild ? Color.blue : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canBuild)
    }

    // MARK: - 辅助属性和方法

    private var categoryColor: Color {
        template.category.color
    }

    private var categoryIcon: String {
        template.category.icon
    }

    private func resourceIcon(for resourceId: String) -> String {
        switch resourceId {
        case "wood": return "leaf.fill"
        case "stone": return "mountain.2.fill"
        case "metal": return "gearshape.fill"
        case "glass": return "square.fill"
        default: return "cube.fill"
        }
    }

    private func resourceDisplayName(for resourceId: String) -> String {
        switch resourceId {
        case "wood": return "木材"
        case "stone": return "石头"
        case "metal": return "金属"
        case "glass": return "玻璃"
        default: return resourceId
        }
    }

    private func formatBuildTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes)分钟"
            } else {
                return "\(minutes)分\(remainingSeconds)秒"
            }
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            if minutes == 0 {
                return "\(hours)小时"
            } else {
                return "\(hours)时\(minutes)分"
            }
        }
    }
}

// MARK: - 预览

#Preview {
    BuildingBrowserView(
        territoryId: "test-territory",
        onDismiss: {},
        onStartConstruction: { _ in }
    )
}
