//
//  ScavengeResultView.swift
//  EarthLord
//
//  搜刮结果视图
//  显示 AI 生成的独特物品和背景故事
//

import SwiftUI

/// 搜刮结果视图（全屏）
struct ScavengeResultView: View {

    /// POI 名称
    let poiName: String

    /// POI 危险等级
    let dangerLevel: Int

    /// AI 生成的物品（优先显示）
    let aiItems: [AIGeneratedItem]?

    /// 传统物品（降级方案）
    let items: [RewardItem]?

    /// 是否真正由 AI 生成（false 表示使用了 fallback）
    var isRealAI: Bool = true

    /// 确认回调
    let onConfirm: () -> Void

    /// 物品出现动画状态
    @State private var itemsVisible: [Bool] = []

    /// 展开的故事索引
    @State private var expandedStoryIndex: Int? = nil

    /// 使用 AI 生成的物品
    private var useAIItems: Bool {
        aiItems != nil && !(aiItems?.isEmpty ?? true)
    }

    var body: some View {
        ZStack {
            // 全屏背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            // 全屏内容
            VStack(spacing: 0) {
                // 头部区域
                headerSection
                    .padding(.top, 60)
                    .padding(.bottom, 16)

                // AI 物品特殊标题
                if useAIItems {
                    HStack(spacing: 6) {
                        Image(systemName: isRealAI ? "sparkles" : "cube.box")
                            .font(.system(size: 14))
                            .foregroundColor(isRealAI ? .purple : .orange)
                        Text(isRealAI ? "发现独特物品！" : "发现物资（预设）")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isRealAI ? .purple : .orange)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }

                // 物品列表（占据剩余空间）
                ScrollView {
                    VStack(spacing: 12) {
                        if useAIItems, let aiItems = aiItems {
                            ForEach(Array(aiItems.enumerated()), id: \.element.id) { index, item in
                                aiItemRow(item: item, index: index)
                            }
                        } else if let items = items {
                            ForEach(Array(items.enumerated()), id: \.element.itemId) { index, item in
                                legacyItemRow(item: item, index: index)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }

                // 底部确认按钮
                Button(action: onConfirm) {
                    Text("收下物资")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
        .onAppear {
            let count = useAIItems ? (aiItems?.count ?? 0) : (items?.count ?? 0)
            itemsVisible = Array(repeating: false, count: count)
            // 依次显示物品
            for index in 0..<count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15 + 0.2) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        if index < itemsVisible.count {
                            itemsVisible[index] = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - 头部

    private var headerSection: some View {
        VStack(spacing: 12) {
            // 成功图标（全屏版本稍大）
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.success.opacity(0.2))
                    .frame(width: 70, height: 70)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.success)
            }

            // 标题
            Text("搜刮成功！")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // POI 信息
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14))
                Text(poiName)
                    .font(.system(size: 15))
                    .lineLimit(1)
                dangerLevelBadge
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 危险等级徽章

    private var dangerLevelBadge: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < dangerLevel ? "star.fill" : "star")
                    .font(.system(size: 8))
                    .foregroundColor(dangerLevelColor)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(dangerLevelColor.opacity(0.2))
        .cornerRadius(4)
    }

    private var dangerLevelColor: Color {
        switch dangerLevel {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .gray
        }
    }

    // MARK: - AI 物品行

    private func aiItemRow(item: AIGeneratedItem, index: Int) -> some View {
        let isVisible = index < itemsVisible.count ? itemsVisible[index] : false
        let isExpanded = expandedStoryIndex == index

        return VStack(alignment: .leading, spacing: 0) {
            // 主行
            HStack(spacing: 12) {
                // 物品图标
                ZStack {
                    Circle()
                        .fill(rarityColor(item.rarity).opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: item.icon)
                        .font(.system(size: 22))
                        .foregroundColor(rarityColor(item.rarity))
                }

                // 物品信息
                VStack(alignment: .leading, spacing: 4) {
                    // 名称 + AI 徽章
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .lineLimit(1)

                        // AI 紫色渐变徽章
                        Text("AI")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(4)
                    }

                    // 稀有度和分类
                    HStack(spacing: 8) {
                        // 稀有度标签
                        Text(item.rarityDisplayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(rarityColor(item.rarity))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rarityColor(item.rarity).opacity(0.15))
                            .cornerRadius(4)

                        // 分类
                        Text(item.category)
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }

                Spacer()

                // 展开故事按钮
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if isExpanded {
                            expandedStoryIndex = nil
                        } else {
                            expandedStoryIndex = index
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "text.quote")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .frame(width: 32, height: 32)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(8)
                }
            }
            .padding(12)

            // 故事（可展开）
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(ApocalypseTheme.textMuted.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal, 12)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 12))
                            .foregroundColor(.purple.opacity(0.6))

                        Text(item.story)
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .italic()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.5), .pink.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
    }

    // MARK: - 传统物品行（降级方案）

    @StateObject private var inventoryManager = InventoryManager.shared

    private func legacyItemRow(item: RewardItem, index: Int) -> some View {
        let definition = inventoryManager.getItemDefinition(by: item.itemId)
        let isVisible = index < itemsVisible.count ? itemsVisible[index] : false

        return HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(categoryColor(definition?.category).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: definition?.icon ?? "questionmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor(definition?.category))
            }

            // 物品名称
            VStack(alignment: .leading, spacing: 2) {
                Text(definition?.name ?? "未知物品")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let rarity = definition?.rarity {
                    Text(rarityText(rarity))
                        .font(.system(size: 11))
                        .foregroundColor(rarityColor(rarity))
                }
            }

            Spacer()

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

    private func rarityColor(_ rarity: String) -> Color {
        switch rarity {
        case "legendary": return .yellow
        case "epic": return .purple
        case "rare": return .blue
        case "uncommon": return .green
        default: return .gray
        }
    }

    private func categoryColor(_ category: String?) -> Color {
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
        case "legendary": return "传奇"
        case "epic": return "史诗"
        case "rare": return "稀有"
        case "uncommon": return "优秀"
        default: return "普通"
        }
    }
}

// MARK: - Preview

#Preview {
    ScavengeResultView(
        poiName: "协和医院急诊室",
        dangerLevel: 4,
        aiItems: [
            AIGeneratedItem(
                name: "「最后的希望」应急包",
                category: "医疗",
                rarity: "epic",
                story: "这个急救包上贴着一张便签：'给值夜班的自己准备的'。便签已经褪色，主人再也没能用上它..."
            ),
            AIGeneratedItem(
                name: "护士站的咖啡罐头",
                category: "食物",
                rarity: "rare",
                story: "罐头上写着'夜班续命神器'。末日来临时，护士们大概正在喝着咖啡讨论患者病情。"
            ),
            AIGeneratedItem(
                name: "急诊科常备止痛片",
                category: "医疗",
                rarity: "uncommon",
                story: "瓶身上还贴着患者的名字，看来他再也不需要这些了..."
            )
        ],
        items: nil,
        onConfirm: { print("确认") }
    )
}
