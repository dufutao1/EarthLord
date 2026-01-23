//
//  TradeOfferDetailView.swift
//  EarthLord
//
//  交易挂单详情页面
//  查看挂单详情并接受交易
//

import SwiftUI

struct TradeOfferDetailView: View {

    let offer: TradeOffer

    @Environment(\.dismiss) private var dismiss

    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 显示确认交易弹窗
    @State private var showConfirmAlert = false

    /// 是否正在处理
    @State private var isProcessing = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 成功信息
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 发布者信息
                    publisherSection

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))

                    // 提供的物品
                    offeringSection

                    // 需要的物品
                    requestingSection

                    // 留言
                    if let message = offer.message, !message.isEmpty {
                        messageSection(message)
                    }

                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))

                    // 库存检查
                    inventoryCheckSection

                    // 接受交易按钮
                    acceptButton
                }
                .padding(20)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("挂单详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("确认交易", isPresented: $showConfirmAlert) {
                Button("取消", role: .cancel) {}
                Button("确认交易") {
                    acceptTrade()
                }
            } message: {
                Text(confirmAlertMessage)
            }
            .alert("交易成功", isPresented: .init(
                get: { successMessage != nil },
                set: { if !$0 { successMessage = nil; dismiss() } }
            )) {
                Button("确定") {
                    successMessage = nil
                    dismiss()
                }
            } message: {
                Text(successMessage ?? "")
            }
            .alert("交易失败", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            Task {
                await inventoryManager.loadInventory()
            }
        }
    }

    // MARK: - 确认弹窗消息

    private var confirmAlertMessage: String {
        let paying = offer.requesting_items.map { item in
            "\(inventoryManager.getItemName(by: item.item_id)) ×\(item.quantity)"
        }.joined(separator: "、")

        let receiving = offer.offering_items.map { item in
            "\(inventoryManager.getItemName(by: item.item_id)) ×\(item.quantity)"
        }.joined(separator: "、")

        return "你将付出：\(paying)\n\n你将获得：\(receiving)"
    }

    // MARK: - 发布者信息

    private var publisherSection: some View {
        HStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(offer.owner_username ?? "未知用户")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("剩余 \(offer.remainingTimeText)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(
                        offer.remainingSeconds < 3600
                            ? ApocalypseTheme.warning
                            : ApocalypseTheme.textSecondary
                    )
                }
            }

            Spacer()

            // 状态标签
            Text(offer.status.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ApocalypseTheme.primary)
                .cornerRadius(6)
        }
    }

    // MARK: - 提供的物品

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("他提供")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 10)
            ], spacing: 10) {
                ForEach(offer.offering_items) { item in
                    ItemDetailCard(item: item)
                }
            }
        }
    }

    // MARK: - 需要的物品

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("他想要")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 10)
            ], spacing: 10) {
                ForEach(offer.requesting_items) { item in
                    ItemDetailCard(item: item, showInventoryStatus: true)
                }
            }
        }
    }

    // MARK: - 留言区域

    private func messageSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("留言")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("「\(message)」")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .italic()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
        }
    }

    // MARK: - 库存检查

    private var inventoryCheckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("你的库存")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(offer.requesting_items) { item in
                    inventoryCheckRow(for: item)
                }
            }
        }
    }

    private func inventoryCheckRow(for item: TradeItem) -> some View {
        let ownedQuantity = inventoryManager.getQuantity(of: item.item_id)
        let isSufficient = ownedQuantity >= item.quantity

        return HStack {
            Image(systemName: inventoryManager.getItemDefinition(by: item.item_id)?.icon ?? "cube.fill")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(inventoryManager.getItemName(by: item.item_id))
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Text("需要 \(item.quantity) / 拥有 \(ownedQuantity)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)

            Image(systemName: isSufficient ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
        }
        .padding(10)
        .background(
            (isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger).opacity(0.1)
        )
        .cornerRadius(8)
    }

    // MARK: - 接受交易按钮

    private var acceptButton: some View {
        let canAccept = checkCanAccept()

        return Button(action: { showConfirmAlert = true }) {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                }

                Text(isProcessing ? "处理中..." : "接受交易")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canAccept && !isProcessing
                    ? ApocalypseTheme.success
                    : ApocalypseTheme.textMuted
            )
            .cornerRadius(12)
        }
        .disabled(!canAccept || isProcessing)
    }

    // MARK: - 检查是否可接受

    private func checkCanAccept() -> Bool {
        for item in offer.requesting_items {
            let owned = inventoryManager.getQuantity(of: item.item_id)
            if owned < item.quantity {
                return false
            }
        }
        return offer.isAvailable
    }

    // MARK: - 接受交易

    private func acceptTrade() {
        isProcessing = true

        Task {
            do {
                try await tradeManager.acceptTradeOffer(offerId: offer.id)

                let receivedItems = offer.offering_items.map { item in
                    inventoryManager.getItemName(by: item.item_id)
                }.joined(separator: "、")

                successMessage = "交易成功！你获得了：\(receivedItems)"
            } catch {
                errorMessage = error.localizedDescription
            }

            isProcessing = false
        }
    }
}

// MARK: - 物品详情卡片

struct ItemDetailCard: View {
    let item: TradeItem
    var showInventoryStatus: Bool = false

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

    private var ownedQuantity: Int {
        inventoryManager.getQuantity(of: item.item_id)
    }

    private var isSufficient: Bool {
        ownedQuantity >= item.quantity
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: itemIcon)
                    .font(.system(size: 22))
                    .foregroundColor(categoryColor)
            }

            Text(itemName)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            Text("×\(item.quantity)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(categoryColor)

            if showInventoryStatus {
                HStack(spacing: 2) {
                    Image(systemName: isSufficient ? "checkmark" : "xmark")
                        .font(.system(size: 10))
                    Text("\(ownedQuantity)")
                        .font(.system(size: 10))
                }
                .foregroundColor(isSufficient ? ApocalypseTheme.success : ApocalypseTheme.danger)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }
}

#Preview {
    TradeOfferDetailView(
        offer: TradeOffer(
            id: UUID(),
            owner_id: UUID(),
            owner_username: "测试玩家",
            offering_items: [
                TradeItem(item_id: "wood", quantity: 20),
                TradeItem(item_id: "stone", quantity: 10)
            ],
            requesting_items: [
                TradeItem(item_id: "iron", quantity: 5)
            ],
            status: .active,
            message: "急需铁矿，价格可谈",
            created_at: Date(),
            expires_at: Date().addingTimeInterval(3600 * 12),
            completed_at: nil,
            completed_by_user_id: nil,
            completed_by_username: nil
        )
    )
}
