//
//  TerritoryBuildingRow.swift
//  EarthLord
//
//  领地建筑行组件
//  显示建筑状态、进度条、操作菜单
//

import SwiftUI

// MARK: - 领地建筑行

struct TerritoryBuildingRow: View {
    let building: PlayerBuilding
    let onUpgrade: () -> Void
    let onDemolish: () -> Void

    @State private var remainingTime: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            buildingIcon

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                // 名称和等级
                HStack(spacing: 6) {
                    Text(building.buildingName)
                        .font(.headline)

                    statusBadge
                }

                // 建造中显示进度条
                if building.status == .constructing {
                    buildingProgressView
                } else {
                    Text("Lv.\(building.level)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 操作菜单
            if building.status == .active {
                actionMenu
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            startTimerIfNeeded()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - 建筑图标

    private var buildingIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 44, height: 44)

            if building.status == .constructing {
                // 建造中显示旋转动画
                Image(systemName: "hammer.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
            } else {
                Image(systemName: building.template?.icon ?? "building.2.fill")
                    .font(.title3)
                    .foregroundColor(statusColor)
            }
        }
    }

    // MARK: - 状态徽章

    private var statusBadge: some View {
        Group {
            if building.status == .constructing {
                Text("建造中")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .clipShape(Capsule())
            } else {
                Text("运行中")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - 建造进度视图

    private var buildingProgressView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .clipShape(Capsule())

                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .clipShape(Capsule())
                }
            }
            .frame(height: 4)
            .frame(maxWidth: 150)

            // 剩余时间
            Text(formatRemainingTime(remainingTime))
                .font(.caption)
                .foregroundColor(.orange)
        }
    }

    // MARK: - 操作菜单

    private var actionMenu: some View {
        Menu {
            // 升级按钮
            Button {
                onUpgrade()
            } label: {
                Label("升级", systemImage: "arrow.up.circle")
            }
            .disabled(isMaxLevel)

            Divider()

            // 拆除按钮
            Button(role: .destructive) {
                onDemolish()
            } label: {
                Label("拆除", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 计算属性

    private var statusColor: Color {
        switch building.status {
        case .constructing:
            return .orange
        case .active:
            return .green
        }
    }

    private var progress: Double {
        guard let completedAt = building.buildCompletedAt else {
            return 0
        }

        let startedAt = building.buildStartedAt
        let totalDuration = completedAt.timeIntervalSince(startedAt)
        let elapsed = Date().timeIntervalSince(startedAt)

        return min(max(elapsed / totalDuration, 0), 1)
    }

    private var isMaxLevel: Bool {
        guard let template = building.template else { return true }
        return building.level >= template.maxLevel
    }

    // MARK: - 计时器

    private func startTimerIfNeeded() {
        guard building.status == .constructing,
              building.buildCompletedAt != nil else {
            return
        }

        updateRemainingTime()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateRemainingTime()
        }
    }

    private func updateRemainingTime() {
        guard let completedAt = building.buildCompletedAt else {
            remainingTime = 0
            return
        }
        remainingTime = max(0, completedAt.timeIntervalSinceNow)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 格式化剩余时间

    private func formatRemainingTime(_ interval: TimeInterval) -> String {
        if interval <= 0 {
            return "即将完成"
        }

        let seconds = Int(interval)
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return "\(minutes)分\(secs)秒"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)时\(minutes)分"
        }
    }
}

// MARK: - 建筑列表视图

struct TerritoryBuildingListView: View {
    let buildings: [PlayerBuilding]
    let onUpgrade: (PlayerBuilding) -> Void
    let onDemolish: (PlayerBuilding) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack {
                Text("建筑列表")
                    .font(.headline)

                Spacer()

                Text("\(buildings.count) 个建筑")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if buildings.isEmpty {
                // 空状态
                emptyStateView
            } else {
                // 建筑列表
                ForEach(buildings, id: \.id) { building in
                    TerritoryBuildingRow(
                        building: building,
                        onUpgrade: { onUpgrade(building) },
                        onDemolish: { onDemolish(building) }
                    )
                    .padding(.horizontal, 16)

                    if building.id != buildings.last?.id {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("还没有建筑")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("点击\"建造\"开始建设你的领地")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - 预览

#Preview {
    let buildings: [PlayerBuilding] = [
        PlayerBuilding(
            id: UUID(),
            userId: UUID(),
            territoryId: "test",
            templateId: "campfire",
            buildingName: "篝火",
            status: .active,
            level: 2,
            locationLat: 39.9,
            locationLon: 116.4,
            buildStartedAt: Date().addingTimeInterval(-60),
            buildCompletedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        PlayerBuilding(
            id: UUID(),
            userId: UUID(),
            territoryId: "test",
            templateId: "shelter",
            buildingName: "庇护所",
            status: .constructing,
            level: 1,
            locationLat: 39.91,
            locationLon: 116.41,
            buildStartedAt: Date().addingTimeInterval(-30),
            buildCompletedAt: Date().addingTimeInterval(30),
            createdAt: Date(),
            updatedAt: Date()
        )
    ]

    return ScrollView {
        TerritoryBuildingListView(
            buildings: buildings,
            onUpgrade: { _ in },
            onDemolish: { _ in }
        )
        .padding()
    }
}
