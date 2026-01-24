//
//  CreateTradeOfferView.swift
//  EarthLord
//
//  发布交易挂单页面
//  用户填写"我要出什么"和"我想要什么"
//

import SwiftUI

struct CreateTradeOfferView: View {

    /// 发布成功回调
    var onSuccess: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @StateObject private var tradeManager = TradeManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 我要出的物品
    @State private var offeringItems: [TradeItem] = []

    /// 我想要的物品
    @State private var requestingItems: [TradeItem] = []

    /// 有效期（小时）
    @State private var validHours: Int = 24

    /// 留言
    @State private var message: String = ""

    /// 显示物品选择器
    @State private var showItemPicker = false
    @State private var pickerMode: ItemPickerMode = .fromInventory

    /// 正在编辑的物品列表类型
    @State private var editingOffering = true

    /// 提交状态
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    /// 有效期选项
    private let validHoursOptions = [1, 6, 12, 24, 48, 72]

    /// 是否可以发布
    private var canPublish: Bool {
        !offeringItems.isEmpty && !requestingItems.isEmpty && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 我要出的物品
                    offeringSection

                    // 我想要的物品
                    requestingSection

                    // 有效期选择
                    validitySection

                    // 留言
                    messageSection

                    // 发布按钮
                    publishButton
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("发布交易挂单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showItemPicker) {
                ItemPickerView(mode: pickerMode) { item in
                    addItem(item)
                }
            }
            .alert("发布失败", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("发布成功", isPresented: $showSuccess) {
                Button("确定") {
                    onSuccess?()
                    dismiss()
                }
            } message: {
                Text("挂单发布成功！物品已从背包锁定。")
            }
        }
    }

    // MARK: - 我要出的物品区域

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.danger)
                Text("我要出的物品")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            if offeringItems.isEmpty {
                emptyItemsPlaceholder(message: "点击下方按钮添加要出的物品")
            } else {
                selectedItemsList(items: $offeringItems, isOffering: true)
            }

            Button(action: {
                editingOffering = true
                pickerMode = .fromInventory
                showItemPicker = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("添加物品")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.primary.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 我想要的物品区域

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.success)
                Text("我想要的物品")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            if requestingItems.isEmpty {
                emptyItemsPlaceholder(message: "点击下方按钮添加想要的物品")
            } else {
                selectedItemsList(items: $requestingItems, isOffering: false)
            }

            Button(action: {
                editingOffering = false
                pickerMode = .allItems
                showItemPicker = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("添加物品")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.primary.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 空物品占位

    private func emptyItemsPlaceholder(message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundColor(ApocalypseTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(ApocalypseTheme.background.opacity(0.5))
            .cornerRadius(8)
    }

    // MARK: - 已选物品列表

    private func selectedItemsList(items: Binding<[TradeItem]>, isOffering: Bool) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items.wrappedValue.indices, id: \.self) { index in
                let item = items.wrappedValue[index]
                SelectedItemChip(
                    item: item,
                    onRemove: {
                        items.wrappedValue.remove(at: index)
                    }
                )
            }
        }
    }

    // MARK: - 有效期选择

    private var validitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.warning)
                Text("有效期")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(validHoursOptions, id: \.self) { hours in
                        Button(action: { validHours = hours }) {
                            Text(formatHours(hours))
                                .font(.system(size: 13, weight: validHours == hours ? .semibold : .medium))
                                .foregroundColor(validHours == hours ? .white : ApocalypseTheme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(validHours == hours ? ApocalypseTheme.primary : ApocalypseTheme.background)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func formatHours(_ hours: Int) -> String {
        if hours < 24 {
            return "\(hours)小时"
        } else {
            return "\(hours / 24)天"
        }
    }

    // MARK: - 留言区域

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("留言（可选）")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            TextField("写下你想说的话...", text: $message, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(12)
                .background(ApocalypseTheme.background)
                .cornerRadius(8)
                .lineLimit(2...4)
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 发布按钮

    private var publishButton: some View {
        Button(action: publishOffer) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                }

                Text(isSubmitting ? "发布中..." : "发布挂单")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canPublish
                    ? LinearGradient(colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [ApocalypseTheme.textMuted, ApocalypseTheme.textMuted], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(12)
        }
        .disabled(!canPublish)
    }

    // MARK: - 添加物品

    private func addItem(_ item: TradeItem) {
        if editingOffering {
            // 检查是否已有相同物品，如果有则合并数量
            if let index = offeringItems.firstIndex(where: { $0.item_id == item.item_id }) {
                let existing = offeringItems[index]
                let maxQuantity = inventoryManager.getQuantity(of: item.item_id)
                let newQuantity = min(existing.quantity + item.quantity, maxQuantity)
                offeringItems[index] = TradeItem(item_id: item.item_id, quantity: newQuantity)
            } else {
                offeringItems.append(item)
            }
        } else {
            // 检查是否已有相同物品
            if let index = requestingItems.firstIndex(where: { $0.item_id == item.item_id }) {
                let existing = requestingItems[index]
                requestingItems[index] = TradeItem(item_id: item.item_id, quantity: existing.quantity + item.quantity)
            } else {
                requestingItems.append(item)
            }
        }
    }

    // MARK: - 发布挂单

    private func publishOffer() {
        isSubmitting = true

        Task {
            do {
                _ = try await tradeManager.createTradeOffer(
                    offeringItems: offeringItems,
                    requestingItems: requestingItems,
                    validHours: validHours,
                    message: message.isEmpty ? nil : message
                )
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }

            isSubmitting = false
        }
    }
}

// MARK: - 已选物品标签

struct SelectedItemChip: View {

    let item: TradeItem
    let onRemove: () -> Void

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
        HStack(spacing: 6) {
            Image(systemName: itemIcon)
                .font(.system(size: 12))
                .foregroundColor(categoryColor)

            Text(itemName)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("×\(item.quantity)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(categoryColor)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(categoryColor.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    CreateTradeOfferView()
}
