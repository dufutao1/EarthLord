//
//  BuildingCard.swift
//  EarthLord
//
//  建筑卡片组件
//  用于建筑浏览器中展示单个建筑模板
//

import SwiftUI

// MARK: - 建筑卡片

struct BuildingCard: View {
    let template: BuildingTemplate
    let canBuild: Bool
    let missingResources: [String: Int]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 图标
                iconSection

                // 名称和分类
                infoSection

                // 资源需求
                resourceSection

                // 建造时间
                timeSection
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(canBuild ? Color.green.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: canBuild ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 图标部分

    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.2))
                .frame(width: 60, height: 60)

            Image(systemName: template.icon)
                .font(.system(size: 28))
                .foregroundColor(categoryColor)
        }
    }

    // MARK: - 信息部分

    private var infoSection: some View {
        VStack(spacing: 4) {
            Text(template.name)
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 4) {
                Text(template.category.displayName)
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

    // MARK: - 资源部分

    private var resourceSection: some View {
        VStack(spacing: 6) {
            ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resourceId in
                let required = template.requiredResources[resourceId] ?? 0
                let missing = missingResources[resourceId] ?? 0
                let isSufficient = missing == 0

                HStack {
                    Image(systemName: resourceIcon(for: resourceId))
                        .font(.caption)
                        .foregroundColor(isSufficient ? .green : .red)

                    Text(resourceDisplayName(for: resourceId))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if isSufficient {
                        Text("\(required)")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("\(required) (缺\(missing))")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - 时间部分

    private var timeSection: some View {
        HStack {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(formatBuildTime(template.buildTimeSeconds))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 卡片背景

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - 分类颜色

    private var categoryColor: Color {
        template.category.color
    }

    // MARK: - 资源图标

    private func resourceIcon(for resourceId: String) -> String {
        switch resourceId {
        case "wood":
            return "leaf.fill"
        case "stone":
            return "mountain.2.fill"
        case "metal":
            return "gearshape.fill"
        case "glass":
            return "square.fill"
        default:
            return "cube.fill"
        }
    }

    // MARK: - 资源显示名

    private func resourceDisplayName(for resourceId: String) -> String {
        switch resourceId {
        case "wood":
            return "木材"
        case "stone":
            return "石头"
        case "metal":
            return "金属"
        case "glass":
            return "玻璃"
        default:
            return resourceId
        }
    }

    // MARK: - 格式化建造时间

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

    VStack(spacing: 20) {
        // 可建造
        BuildingCard(
            template: template,
            canBuild: true,
            missingResources: [:],
            onTap: {}
        )
        .frame(width: 180)

        // 资源不足
        BuildingCard(
            template: template,
            canBuild: false,
            missingResources: ["wood": 10, "stone": 5],
            onTap: {}
        )
        .frame(width: 180)
    }
    .padding()
}
