//
//  BuildingPlacementView.swift
//  EarthLord
//
//  建造确认页
//  资源检查 + 地图位置选择 + 确认建造
//

import SwiftUI
import CoreLocation

// MARK: - 建造确认页

struct BuildingPlacementView: View {
    let template: BuildingTemplate
    let territoryId: String
    let territoryCoordinates: [CLLocationCoordinate2D]
    let onDismiss: () -> Void
    let onConstructionStarted: (PlayerBuilding) -> Void

    @StateObject private var buildingManager = BuildingManager.shared
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var isConstructing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            if territoryCoordinates.count < 3 {
                // 错误状态：坐标不足
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("领地数据错误")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("无法加载领地边界坐标")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Button("关闭") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .navigationTitle("选择建造位置")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                // 正常状态
                VStack(spacing: 0) {
                    // 地图选点区域
                    mapSection

                    // 底部信息区域
                    bottomInfoSection
                }
                .navigationTitle("选择建造位置")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            print("🗺️ [BuildingPlacement] 取消按钮被点击")
                            onDismiss()
                        }
                    }
                }
                .alert("建造失败", isPresented: $showError) {
                    Button("确定", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
                .onAppear {
                    print("🗺️ [BuildingPlacement] 视图出现")
                    print("🗺️ [BuildingPlacement] 建筑: \(template.name)")
                    print("🗺️ [BuildingPlacement] 领地坐标数: \(territoryCoordinates.count)")
                }
            }
        }
    }

    // MARK: - 地图区域

    private var mapSection: some View {
        ZStack(alignment: .top) {
            // 地图选择器
            BuildingLocationPickerView(
                territoryCoordinates: territoryCoordinates,
                existingBuildings: buildingManager.playerBuildings,
                selectedCoordinate: $selectedCoordinate
            )

            // 提示信息（顶部悬浮）
            if selectedCoordinate == nil {
                HStack {
                    Image(systemName: "hand.tap")
                    Text("长按蓝色区域选择建造位置")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(.top, 16)
                .allowsHitTesting(false)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("已选择位置，可再次长按更改")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.8))
                .clipShape(Capsule())
                .padding(.top, 16)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 底部信息区域

    private var bottomInfoSection: some View {
        VStack(spacing: 16) {
            // 建筑信息
            buildingInfoRow

            Divider()

            // 资源需求
            resourcesRow

            // 位置信息
            if let coord = selectedCoordinate {
                locationRow(coord)
            }

            // 确认建造按钮
            constructButton
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - 建筑信息行

    private var buildingInfoRow: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: template.icon)
                    .font(.title2)
                    .foregroundColor(categoryColor)
            }

            // 名称和描述
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)

                Text("\(template.category.displayName) · Tier \(template.tier)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 建造时间
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text(formatBuildTime(template.buildTimeSeconds))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 资源需求行

    private var resourcesRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("资源需求")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resourceId in
                    let required = template.requiredResources[resourceId] ?? 0
                    let available = getAvailableResource(resourceId)
                    let isSufficient = available >= required

                    HStack(spacing: 4) {
                        Image(systemName: resourceIcon(for: resourceId))
                            .foregroundColor(isSufficient ? .green : .red)

                        Text(resourceDisplayName(for: resourceId))
                            .font(.caption)

                        Text("\(available)/\(required)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isSufficient ? .green : .red)
                    }
                }
            }
        }
    }

    // MARK: - 位置信息行

    private func locationRow(_ coord: CLLocationCoordinate2D) -> some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.green)

            Text("已选择位置")
                .font(.subheadline)

            Spacer()

            Text("(\(coord.latitude, specifier: "%.4f"), \(coord.longitude, specifier: "%.4f"))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 确认建造按钮

    private var constructButton: some View {
        Button {
            Task {
                await startConstruction()
            }
        } label: {
            HStack {
                if isConstructing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "hammer.fill")
                    Text(canConstruct ? "确认建造" : buttonDisabledReason)
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canConstruct ? Color.blue : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canConstruct || isConstructing)
    }

    // MARK: - 是否可以建造

    private var canConstruct: Bool {
        // 1. 必须选择位置
        guard selectedCoordinate != nil else { return false }

        // 2. 资源必须足够
        for (resourceId, required) in template.requiredResources {
            let available = getAvailableResource(resourceId)
            if available < required {
                return false
            }
        }

        return true
    }

    // MARK: - 按钮禁用原因

    private var buttonDisabledReason: String {
        if selectedCoordinate == nil {
            return "请选择位置"
        }

        for (resourceId, required) in template.requiredResources {
            let available = getAvailableResource(resourceId)
            if available < required {
                return "资源不足"
            }
        }

        return "无法建造"
    }

    // MARK: - 开始建造

    private func startConstruction() async {
        guard let coord = selectedCoordinate else { return }

        isConstructing = true

        // 🔄 坐标转换：用户选择的是 GCJ-02，需要转换回 WGS-84 保存到数据库
        let wgs84Coord = CoordinateConverter.gcj02ToWgs84(coord)
        print("🗺️ [BuildingPlacement] 用户选择坐标（GCJ-02）: (\(coord.latitude), \(coord.longitude))")
        print("🗺️ [BuildingPlacement] 转换为 WGS-84 保存: (\(wgs84Coord.latitude), \(wgs84Coord.longitude))")

        let result = await buildingManager.startConstruction(
            templateId: template.templateId,
            territoryId: territoryId,
            location: wgs84Coord
        )

        isConstructing = false

        switch result {
        case .success(let building):
            print("✅ [BuildingPlacement] 建造成功: \(building.buildingName)")
            onConstructionStarted(building)
        case .failure(let error):
            print("❌ [BuildingPlacement] 建造失败: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - 辅助方法

    private var categoryColor: Color {
        template.category.color
    }

    private func getAvailableResource(_ resourceId: String) -> Int {
        let resources = buildingManager.getPlayerResources()
        return resources[resourceId] ?? 0
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
            return "\(minutes)分钟"
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
    let template = BuildingTemplate(
        id: UUID(),
        templateId: "campfire",
        name: "篝火",
        category: .survival,
        tier: 1,
        description: "简单的篝火",
        icon: "flame.fill",
        requiredResources: ["wood": 30, "stone": 20],
        buildTimeSeconds: 30,
        maxPerTerritory: 3,
        maxLevel: 5
    )

    let territoryCoords: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 39.9100, longitude: 116.4000),
        CLLocationCoordinate2D(latitude: 39.9100, longitude: 116.4020),
        CLLocationCoordinate2D(latitude: 39.9080, longitude: 116.4020),
        CLLocationCoordinate2D(latitude: 39.9080, longitude: 116.4000)
    ]

    BuildingPlacementView(
        template: template,
        territoryId: "test-territory",
        territoryCoordinates: territoryCoords,
        onDismiss: {},
        onConstructionStarted: { _ in }
    )
}
