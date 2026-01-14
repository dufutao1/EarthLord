//
//  ScavengeResultView.swift
//  EarthLord
//
//  搜刮结果视图
//  显示 POI 搜刮获得的物品
//

import SwiftUI

/// 搜刮结果视图
struct ScavengeResultView: View {

    /// POI 名称
    let poiName: String

    /// 获得的物品
    let items: [RewardItem]

    /// 确认回调
    let onConfirm: () -> Void

    /// 背包管理器（用于获取物品名称）
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 物品出现动画状态
    @State private var itemsVisible: [Bool] = []

    var body: some View {
        VStack(spacing: 0) {
            // 半透明背景
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // 结果卡片
            resultCard
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .onAppear {
            // 初始化动画状态
            itemsVisible = Array(repeating: false, count: items.count)
            // 依次显示物品
            for (index, _) in items.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15 + 0.3) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        if index < itemsVisible.count {
                            itemsVisible[index] = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - 结果卡片

    private var resultCard: some View {
        VStack(spacing: 20) {
            // 成功图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.success.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.success)
            }
            .padding(.top, 24)

            // 标题
            VStack(spacing: 8) {
                Text("搜刮成功！")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                    Text(poiName)
                        .font(.system(size: 14))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 分隔线
            Rectangle()
                .fill(ApocalypseTheme.textMuted.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)

            // 获得物品标题
            HStack {
                Text("获得物品")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 24)

            // 物品列表
            VStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.element.itemId) { index, item in
                    itemRow(item: item, index: index)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // 确认按钮
            Button(action: onConfirm) {
                Text("确认")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.background)
        .cornerRadius(24, corners: [.topLeft, .topRight])
    }

    // MARK: - 物品行

    private func itemRow(item: RewardItem, index: Int) -> some View {
        let definition = inventoryManager.getItemDefinition(by: item.itemId)
        let isVisible = index < itemsVisible.count ? itemsVisible[index] : false

        return HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(itemColor(for: definition?.category).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: definition?.icon ?? "questionmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(itemColor(for: definition?.category))
            }

            // 物品名称
            VStack(alignment: .leading, spacing: 2) {
                Text(definition?.name ?? "未知物品")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 稀有度
                if let rarity = definition?.rarity {
                    Text(rarityText(rarity))
                        .font(.system(size: 11))
                        .foregroundColor(rarityColor(rarity))
                }
            }

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
    }

    // MARK: - 辅助方法

    private func itemColor(for category: String?) -> Color {
        switch category {
        case "food": return .orange
        case "water": return .cyan
        case "medical": return .red
        case "material": return .brown
        case "tool": return .gray
        default: return .gray
        }
    }

    private func rarityText(_ rarity: String) -> String {
        switch rarity {
        case "epic": return "史诗"
        case "rare": return "稀有"
        default: return "普通"
        }
    }

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity {
        case "epic": return .purple
        case "rare": return .blue
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    ScavengeResultView(
        poiName: "沃尔玛超市",
        items: [
            RewardItem(itemId: "canned_food", quantity: 2, rarity: .common),
            RewardItem(itemId: "pure_water", quantity: 1, rarity: .common),
            RewardItem(itemId: "bandage", quantity: 3, rarity: .rare)
        ],
        onConfirm: { print("确认") }
    )
}
