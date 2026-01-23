//
//  TradeOfferCard.swift
//  EarthLord
//
//  交易挂单卡片组件
//  用于显示单个交易挂单的信息
//

import SwiftUI

struct TradeOfferCard: View {

    let offer: TradeOffer

    /// 是否是自己的挂单
    let isOwn: Bool

    /// 操作回调
    var onCancel: (() -> Void)? = nil
    var onAccept: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    @StateObject private var inventoryManager = InventoryManager.shared

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // 顶部：状态 + 发布者/剩余时间
                topRow

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 物品交换信息
                itemsSection

                // 留言（如果有）
                if let message = offer.message, !message.isEmpty {
                    Text("「\(message)」")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .italic()
                        .lineLimit(2)
                }

                // 底部操作区域
                if offer.status == .active {
                    bottomActions
                }

                // 已完成信息
                if offer.status == .completed, let completedBy = offer.completed_by_username {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.success)
                        Text("被 @\(completedBy) 接受")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .padding(14)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusBorderColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 顶部行

    private var topRow: some View {
        HStack {
            // 状态标签
            statusBadge

            Spacer()

            // 发布者或剩余时间
            if isOwn {
                // 自己的挂单显示剩余时间
                if offer.status == .active {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(offer.remainingTimeText)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(
                        offer.remainingSeconds < 3600
                            ? ApocalypseTheme.warning
                            : ApocalypseTheme.textSecondary
                    )
                }
            } else {
                // 别人的挂单显示发布者
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 12))
                    Text(offer.owner_username ?? "未知用户")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    // MARK: - 状态标签

    private var statusBadge: some View {
        Text(offer.status.displayName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(4)
    }

    private var statusColor: Color {
        switch offer.status {
        case .active: return ApocalypseTheme.primary
        case .completed: return ApocalypseTheme.success
        case .cancelled: return ApocalypseTheme.textMuted
        case .expired: return ApocalypseTheme.warning
        }
    }

    private var statusBorderColor: Color {
        switch offer.status {
        case .active: return ApocalypseTheme.primary
        case .completed: return ApocalypseTheme.success
        case .cancelled: return ApocalypseTheme.textMuted
        case .expired: return ApocalypseTheme.warning
        }
    }

    // MARK: - 物品区域

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 提供的物品
            HStack(alignment: .top, spacing: 8) {
                Text(isOwn ? "我出" : "他出")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(width: 32, alignment: .leading)

                FlowLayout(spacing: 6) {
                    ForEach(offer.offering_items) { item in
                        ItemBadge(item: item)
                    }
                }
            }

            // 需要的物品
            HStack(alignment: .top, spacing: 8) {
                Text(isOwn ? "我要" : "他要")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .frame(width: 32, alignment: .leading)

                FlowLayout(spacing: 6) {
                    ForEach(offer.requesting_items) { item in
                        ItemBadge(item: item)
                    }
                }
            }
        }
    }

    // MARK: - 底部操作

    private var bottomActions: some View {
        HStack {
            if isOwn {
                // 自己的挂单：取消按钮
                Button(action: { onCancel?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                        Text("取消挂单")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.danger)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.danger.opacity(0.1))
                    .cornerRadius(6)
                }
            } else {
                Spacer()

                // 别人的挂单：查看详情
                HStack(spacing: 4) {
                    Text("查看详情")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                }
                .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }
}

// MARK: - 物品标签组件

struct ItemBadge: View {
    let item: TradeItem

    @StateObject private var inventoryManager = InventoryManager.shared

    private var itemName: String {
        inventoryManager.getItemName(by: item.item_id)
    }

    private var itemIcon: String {
        inventoryManager.getItemDefinition(by: item.item_id)?.icon ?? "cube.fill"
    }

    private var categoryColor: Color {
        switch inventoryManager.getItemDefinition(by: item.item_id)?.category {
        case "food": return .orange
        case "water": return .cyan
        case "medical": return .red
        case "material": return .brown
        case "tool": return .gray
        default: return ApocalypseTheme.primary
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: itemIcon)
                .font(.system(size: 10))
            Text(itemName)
                .font(.system(size: 11))
            Text("×\(item.quantity)")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(categoryColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(categoryColor.opacity(0.15))
        .cornerRadius(4)
    }
}

// MARK: - FlowLayout 流式布局

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TradeOfferCard(
            offer: TradeOffer(
                id: UUID(),
                owner_id: UUID(),
                owner_username: "测试用户",
                offering_items: [
                    TradeItem(item_id: "wood", quantity: 10),
                    TradeItem(item_id: "stone", quantity: 5)
                ],
                requesting_items: [
                    TradeItem(item_id: "iron", quantity: 3)
                ],
                status: .active,
                message: "急需铁矿，可小刀",
                created_at: Date(),
                expires_at: Date().addingTimeInterval(3600 * 12),
                completed_at: nil,
                completed_by_user_id: nil,
                completed_by_username: nil
            ),
            isOwn: true
        )

        TradeOfferCard(
            offer: TradeOffer(
                id: UUID(),
                owner_id: UUID(),
                owner_username: "其他玩家",
                offering_items: [
                    TradeItem(item_id: "iron", quantity: 5)
                ],
                requesting_items: [
                    TradeItem(item_id: "wood", quantity: 20)
                ],
                status: .active,
                message: nil,
                created_at: Date(),
                expires_at: Date().addingTimeInterval(3600 * 24),
                completed_at: nil,
                completed_by_user_id: nil,
                completed_by_username: nil
            ),
            isOwn: false
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}
