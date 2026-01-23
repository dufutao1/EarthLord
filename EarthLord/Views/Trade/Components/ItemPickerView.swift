//
//  ItemPickerView.swift
//  EarthLord
//
//  物品选择器组件
//  用于在发布挂单时选择物品
//

import SwiftUI

/// 物品选择模式
enum ItemPickerMode {
    case fromInventory  // 从库存选择（有数量限制）
    case allItems       // 选择任意物品（无数量限制）
}

struct ItemPickerView: View {

    let mode: ItemPickerMode
    let onSelect: (TradeItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var inventoryManager = InventoryManager.shared

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil

    /// 选中的物品（等待设置数量）
    @State private var selectedItem: ItemDefinitionDB?
    @State private var selectedQuantity: Int = 1

    /// 显示数量选择弹窗
    @State private var showQuantityPicker = false

    /// 可用物品列表
    private var availableItems: [ItemDefinitionDB] {
        var items: [ItemDefinitionDB]

        if mode == .fromInventory {
            // 只显示库存中有的物品
            let inventoryItemIds = Set(inventoryManager.items.map { $0.item_id })
            items = inventoryManager.allItemDefinitions.filter { inventoryItemIds.contains($0.id) }
        } else {
            // 显示所有物品
            items = inventoryManager.allItemDefinitions
        }

        // 分类筛选
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        // 搜索筛选
        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar

                // 分类筛选
                categoryFilter

                // 物品列表
                if availableItems.isEmpty {
                    emptyView
                } else {
                    itemGrid
                }
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(mode == .fromInventory ? "选择要出的物品" : "选择想要的物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .sheet(isPresented: $showQuantityPicker) {
                if let item = selectedItem {
                    QuantityPickerView(
                        item: item,
                        mode: mode,
                        initialQuantity: selectedQuantity,
                        onConfirm: { quantity in
                            onSelect(TradeItem(item_id: item.id, quantity: quantity))
                            showQuantityPicker = false
                            dismiss()
                        }
                    )
                    .presentationDetents([.height(300)])
                }
            }
        }
        .onAppear {
            Task {
                await inventoryManager.loadItemDefinitions()
                if mode == .fromInventory {
                    await inventoryManager.loadInventory()
                }
            }
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textMuted)

            TextField("搜索物品...", text: $searchText)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryChip(title: "全部", icon: "square.grid.2x2.fill", color: ApocalypseTheme.primary, isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                CategoryChip(title: "食物", icon: "fork.knife", color: .orange, isSelected: selectedCategory == "food") {
                    selectedCategory = "food"
                }
                CategoryChip(title: "水", icon: "drop.fill", color: .cyan, isSelected: selectedCategory == "water") {
                    selectedCategory = "water"
                }
                CategoryChip(title: "材料", icon: "cube.fill", color: .brown, isSelected: selectedCategory == "material") {
                    selectedCategory = "material"
                }
                CategoryChip(title: "工具", icon: "wrench.fill", color: .gray, isSelected: selectedCategory == "tool") {
                    selectedCategory = "tool"
                }
                CategoryChip(title: "医疗", icon: "cross.case.fill", color: .red, isSelected: selectedCategory == "medical") {
                    selectedCategory = "medical"
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: mode == .fromInventory ? "bag" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(mode == .fromInventory ? "背包中没有这类物品" : "没有找到相关物品")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 物品网格

    private var itemGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 90), spacing: 12)
            ], spacing: 12) {
                ForEach(availableItems, id: \.id) { item in
                    ItemPickerCell(
                        item: item,
                        ownedQuantity: mode == .fromInventory ? inventoryManager.getQuantity(of: item.id) : nil,
                        onTap: {
                            selectedItem = item
                            selectedQuantity = 1
                            showQuantityPicker = true
                        }
                    )
                }
            }
            .padding(16)
        }
    }
}

// MARK: - 物品选择单元格

struct ItemPickerCell: View {

    let item: ItemDefinitionDB
    let ownedQuantity: Int?
    let onTap: () -> Void

    private var categoryColor: Color {
        switch item.category {
        case "food": return .orange
        case "water": return .cyan
        case "medical": return .red
        case "material": return .brown
        case "tool": return .gray
        default: return ApocalypseTheme.primary
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: item.icon ?? "cube.fill")
                        .font(.system(size: 20))
                        .foregroundColor(categoryColor)
                }

                Text(item.name)
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                if let quantity = ownedQuantity {
                    Text("库存 \(quantity)")
                        .font(.system(size: 10))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 数量选择器

struct QuantityPickerView: View {

    let item: ItemDefinitionDB
    let mode: ItemPickerMode
    let initialQuantity: Int
    let onConfirm: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var inventoryManager = InventoryManager.shared

    @State private var quantity: Int

    init(item: ItemDefinitionDB, mode: ItemPickerMode, initialQuantity: Int, onConfirm: @escaping (Int) -> Void) {
        self.item = item
        self.mode = mode
        self.initialQuantity = initialQuantity
        self.onConfirm = onConfirm
        _quantity = State(initialValue: initialQuantity)
    }

    /// 最大可选数量
    private var maxQuantity: Int {
        if mode == .fromInventory {
            return inventoryManager.getQuantity(of: item.id)
        } else {
            return 999
        }
    }

    private var categoryColor: Color {
        switch item.category {
        case "food": return .orange
        case "water": return .cyan
        case "medical": return .red
        case "material": return .brown
        case "tool": return .gray
        default: return ApocalypseTheme.primary
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // 物品信息
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: item.icon ?? "cube.fill")
                        .font(.system(size: 26))
                        .foregroundColor(categoryColor)
                }

                Text(item.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if mode == .fromInventory {
                    Text("库存中有：\(maxQuantity) 个")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 数量选择
            HStack(spacing: 20) {
                Button(action: {
                    if quantity > 1 { quantity -= 1 }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(quantity > 1 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                }
                .disabled(quantity <= 1)

                Text("\(quantity)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(minWidth: 60)

                Button(action: {
                    if quantity < maxQuantity { quantity += 1 }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(quantity < maxQuantity ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                }
                .disabled(quantity >= maxQuantity)
            }

            // 确认按钮
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("取消")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(10)
                }

                Button(action: { onConfirm(quantity) }) {
                    Text("确认添加")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(10)
                }
            }
        }
        .padding(20)
        .background(ApocalypseTheme.background)
    }
}

#Preview {
    ItemPickerView(mode: .fromInventory) { item in
        print("Selected: \(item)")
    }
}
