//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页
//  全屏地图布局 + 悬浮工具栏 + 可折叠信息面板
//  Day 29: 集成建造系统
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - 属性

    /// 领地数据
    let territory: Territory

    /// 删除成功回调
    var onDelete: (() -> Void)?

    /// 环境变量
    @Environment(\.dismiss) private var dismiss

    // MARK: - 管理器

    @StateObject private var buildingManager = BuildingManager.shared

    // MARK: - 状态

    /// 是否显示信息面板
    @State private var showInfoPanel: Bool = true

    /// 是否显示删除确认
    @State private var showDeleteAlert: Bool = false

    /// 是否正在删除
    @State private var isDeleting: Bool = false

    /// 是否显示重命名对话框
    @State private var showRenameAlert: Bool = false

    /// 新名称
    @State private var newName: String = ""

    /// 是否显示建筑浏览器
    @State private var showBuildingBrowser: Bool = false

    /// 选中的建筑模板（用于建造确认页）
    @State private var selectedTemplateForConstruction: BuildingTemplate?

    /// 选中的建筑（用于详情/操作）
    @State private var selectedBuilding: PlayerBuilding?

    /// 是否显示升级确认
    @State private var showUpgradeAlert: Bool = false

    /// 是否显示拆除确认
    @State private var showDemolishAlert: Bool = false

    var body: some View {
        ZStack {
            // 1. 全屏地图（底层）
            TerritoryMapView(
                territoryCoordinates: territory.toCoordinates(),
                buildings: buildingManager.playerBuildings,
                onBuildingTap: { building in
                    selectedBuilding = building
                }
            )
            .ignoresSafeArea()

            // 2. 悬浮工具栏（顶部）
            VStack {
                toolbarView
                Spacer()
            }

            // 3. 可折叠信息面板（底部）
            VStack {
                Spacer()
                if showInfoPanel {
                    infoPanelView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showInfoPanel)
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                Task {
                    await deleteTerritory()
                }
            }
        } message: {
            Text("删除后无法恢复，确定要删除这块领地吗？")
        }
        .alert("重命名领地", isPresented: $showRenameAlert) {
            TextField("新名称", text: $newName)
            Button("取消", role: .cancel) { }
            Button("确定") {
                Task {
                    await renameTerritory()
                }
            }
        } message: {
            Text("请输入新的领地名称")
        }
        .alert("确认升级", isPresented: $showUpgradeAlert) {
            Button("取消", role: .cancel) { }
            Button("升级") {
                if let building = selectedBuilding {
                    Task {
                        await upgradeBuilding(building)
                    }
                }
            }
        } message: {
            if let building = selectedBuilding {
                Text("将 \(building.buildingName) 升级到 Lv.\(building.level + 1)?")
            }
        }
        .alert("确认拆除", isPresented: $showDemolishAlert) {
            Button("取消", role: .cancel) { }
            Button("拆除", role: .destructive) {
                if let building = selectedBuilding {
                    Task {
                        await demolishBuilding(building)
                    }
                }
            }
        } message: {
            if let building = selectedBuilding {
                Text("确定要拆除 \(building.buildingName) 吗？拆除后无法恢复。")
            }
        }
        // Sheet 1: 建筑浏览器
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                territoryId: territory.id,
                onDismiss: { showBuildingBrowser = false },
                onStartConstruction: { template in
                    showBuildingBrowser = false
                    // 延迟 0.3s 等待关闭动画完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTemplateForConstruction = template
                    }
                }
            )
        }
        // Sheet 2: 建造确认页（使用 fullScreenCover 避免手势冲突）
        .fullScreenCover(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territoryId: territory.id,
                territoryCoordinates: territory.toCoordinates(),
                onDismiss: { selectedTemplateForConstruction = nil },
                onConstructionStarted: { _ in
                    selectedTemplateForConstruction = nil
                    Task {
                        await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
                    }
                }
            )
        }
        .onAppear {
            newName = territory.displayName
            Task {
                await buildingManager.fetchPlayerBuildings(territoryId: territory.id)
            }
        }
    }

    // MARK: - 悬浮工具栏

    private var toolbarView: some View {
        HStack {
            // 返回按钮
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }

            Spacer()

            // 领地名称
            Text(territory.displayName)
                .font(.headline)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

            Spacer()

            // 更多菜单
            Menu {
                Button {
                    showRenameAlert = true
                } label: {
                    Label("重命名", systemImage: "pencil")
                }

                Button {
                    withAnimation {
                        showInfoPanel.toggle()
                    }
                } label: {
                    Label(showInfoPanel ? "隐藏信息" : "显示信息", systemImage: showInfoPanel ? "chevron.down" : "chevron.up")
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("删除领地", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.5), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - 信息面板

    private var infoPanelView: some View {
        VStack(spacing: 0) {
            // 拖动手柄
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .onTapGesture {
                    withAnimation {
                        showInfoPanel.toggle()
                    }
                }

            ScrollView {
                VStack(spacing: 16) {
                    // 领地信息卡片
                    territoryInfoCard

                    // 快捷操作
                    quickActionsSection

                    // 建筑列表
                    TerritoryBuildingListView(
                        buildings: buildingManager.playerBuildings,
                        onUpgrade: { building in
                            selectedBuilding = building
                            showUpgradeAlert = true
                        },
                        onDemolish: { building in
                            selectedBuilding = building
                            showDemolishAlert = true
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - 领地信息卡片

    private var territoryInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("面积")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(territory.formattedArea)
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Text("坐标点")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(territory.pointCount ?? 0)")
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("建筑数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(buildingManager.playerBuildings.count)")
                        .font(.headline)
                }
            }

            Divider()

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("占领于 \(territory.formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 快捷操作

    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            // 建造按钮
            Button {
                showBuildingBrowser = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.title2)
                    Text("建造")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 重命名按钮
            Button {
                showRenameAlert = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.title2)
                    Text("重命名")
                        .font(.caption)
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(UIColor.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 删除按钮
            Button {
                showDeleteAlert = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.title2)
                    Text("删除")
                        .font(.caption)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - 方法

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true

        let success = await TerritoryManager.shared.deleteTerritory(territoryId: territory.id)

        isDeleting = false

        if success {
            // 发送通知刷新列表
            NotificationCenter.default.post(name: .territoryUpdated, object: nil)
            dismiss()
            onDelete?()
        }
    }

    /// 重命名领地
    private func renameTerritory() async {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let success = await TerritoryManager.shared.updateTerritoryName(
            territoryId: territory.id,
            newName: newName.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if success {
            // 发送通知刷新列表
            NotificationCenter.default.post(name: .territoryUpdated, object: nil)
        }
    }

    /// 升级建筑
    private func upgradeBuilding(_ building: PlayerBuilding) async {
        let result = await buildingManager.upgradeBuilding(buildingId: building.id)

        switch result {
        case .success(let upgraded):
            print("✅ [TerritoryDetail] 升级成功: \(upgraded.buildingName) Lv.\(upgraded.level)")
        case .failure(let error):
            print("❌ [TerritoryDetail] 升级失败: \(error)")
        }
    }

    /// 拆除建筑
    private func demolishBuilding(_ building: PlayerBuilding) async {
        let success = await buildingManager.demolishBuilding(buildingId: building.id)

        if success {
            print("✅ [TerritoryDetail] 拆除成功: \(building.buildingName)")
        }
    }
}

// MARK: - 预览

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test-id",
            userId: "user-id",
            name: "测试领地",
            path: [
                ["lat": 39.9, "lon": 116.4],
                ["lat": 39.91, "lon": 116.4],
                ["lat": 39.91, "lon": 116.41],
                ["lat": 39.9, "lon": 116.41]
            ],
            area: 12345,
            pointCount: 50,
            isActive: true,
            createdAt: "2024-01-01T12:00:00.000Z",
            startedAt: nil,
            completedAt: nil
        )
    )
}
