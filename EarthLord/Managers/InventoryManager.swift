//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器
//  负责管理背包物品，与数据库同步
//

import Foundation
import Combine
import Supabase

// MARK: - 数据库物品模型

/// 从数据库读取的背包物品
struct InventoryItemDB: Codable, Identifiable, Equatable {
    let id: UUID
    let user_id: UUID
    let item_id: String
    var quantity: Int
    let obtained_at: Date
    let updated_at: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case item_id
        case quantity
        case obtained_at
        case updated_at
    }
}

/// 从数据库读取的物品定义
struct ItemDefinitionDB: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let icon: String
    let rarity: String
    let category: String
    let weight: Double
    let max_stack: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, rarity, category, weight
        case max_stack
    }
}

// MARK: - 背包管理器

/// 背包管理器（单例）
/// 管理背包物品的增删改查，与数据库同步
class InventoryManager: ObservableObject {

    // MARK: - 单例

    static let shared = InventoryManager()

    // MARK: - 发布的状态

    /// 背包物品列表
    @Published var items: [InventoryItemDB] = []

    /// 物品定义缓存
    @Published var itemDefinitions: [String: ItemDefinitionDB] = [:]

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 初始化

    private init() {
        // 启动时加载物品定义
        Task {
            await loadItemDefinitions()
        }
    }

    // MARK: - 公开方法

    /// 加载物品定义（静态数据，只需加载一次）
    @MainActor
    func loadItemDefinitions() async {
        do {
            let definitions: [ItemDefinitionDB] = try await supabase
                .from("item_definitions")
                .select()
                .execute()
                .value

            // 转换为字典方便查询
            var cache: [String: ItemDefinitionDB] = [:]
            for def in definitions {
                cache[def.id] = def
            }
            self.itemDefinitions = cache

            print("✅ [背包] 加载了 \(definitions.count) 个物品定义")
        } catch {
            print("❌ [背包] 加载物品定义失败: \(error)")
            self.errorMessage = "加载物品定义失败"
        }
    }

    /// 加载背包物品
    @MainActor
    func loadInventory() async {
        guard let userId = supabase.auth.currentUser?.id else {
            print("⚠️ [背包] 用户未登录")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let inventoryItems: [InventoryItemDB] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("obtained_at", ascending: false)
                .execute()
                .value

            self.items = inventoryItems
            print("✅ [背包] 加载了 \(inventoryItems.count) 个背包物品")
        } catch {
            print("❌ [背包] 加载背包失败: \(error)")
            self.errorMessage = "加载背包失败"
        }

        isLoading = false
    }

    /// 添加物品到背包
    /// - Parameters:
    ///   - itemId: 物品ID
    ///   - quantity: 数量
    @MainActor
    func addItem(itemId: String, quantity: Int) async {
        guard let userId = supabase.auth.currentUser?.id else {
            print("⚠️ [背包] 用户未登录，无法添加物品")
            return
        }

        // 检查是否已有该物品
        if let existingItem = items.first(where: { $0.item_id == itemId }) {
            // 更新数量
            let newQuantity = existingItem.quantity + quantity
            await updateItemQuantity(itemId: itemId, quantity: newQuantity)
        } else {
            // 插入新物品
            await insertNewItem(userId: userId, itemId: itemId, quantity: quantity)
        }
    }

    /// 移除物品
    /// - Parameters:
    ///   - itemId: 物品ID
    ///   - quantity: 移除数量
    @MainActor
    func removeItem(itemId: String, quantity: Int) async {
        guard let existingItem = items.first(where: { $0.item_id == itemId }) else {
            print("⚠️ [背包] 物品不存在: \(itemId)")
            return
        }

        let newQuantity = existingItem.quantity - quantity

        if newQuantity <= 0 {
            // 删除物品
            await deleteItem(id: existingItem.id)
        } else {
            // 更新数量
            await updateItemQuantity(itemId: itemId, quantity: newQuantity)
        }
    }

    /// 获取物品定义
    func getItemDefinition(by itemId: String) -> ItemDefinitionDB? {
        return itemDefinitions[itemId]
    }

    /// 获取物品名称
    func getItemName(by itemId: String) -> String {
        return itemDefinitions[itemId]?.name ?? "未知物品"
    }

    /// 获取物品图标
    func getItemIcon(by itemId: String) -> String {
        return itemDefinitions[itemId]?.icon ?? "questionmark.circle"
    }

    /// 计算背包总重量
    func calculateTotalWeight() -> Double {
        return items.reduce(0) { total, item in
            let weight = itemDefinitions[item.item_id]?.weight ?? 0
            return total + (weight * Double(item.quantity))
        }
    }

    // MARK: - 私有方法

    /// 插入新物品
    @MainActor
    private func insertNewItem(userId: UUID, itemId: String, quantity: Int) async {
        do {
            let newItem = [
                "user_id": userId.uuidString,
                "item_id": itemId,
                "quantity": String(quantity)
            ]

            try await supabase
                .from("inventory_items")
                .insert(newItem)
                .execute()

            print("✅ [背包] 添加物品成功: \(itemId) x\(quantity)")

            // 重新加载背包
            await loadInventory()
        } catch {
            print("❌ [背包] 添加物品失败: \(error)")
            self.errorMessage = "添加物品失败"
        }
    }

    /// 更新物品数量
    @MainActor
    private func updateItemQuantity(itemId: String, quantity: Int) async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        do {
            try await supabase
                .from("inventory_items")
                .update(["quantity": quantity])
                .eq("user_id", value: userId.uuidString)
                .eq("item_id", value: itemId)
                .execute()

            print("✅ [背包] 更新物品数量: \(itemId) → \(quantity)")

            // 更新本地状态
            if let index = items.firstIndex(where: { $0.item_id == itemId }) {
                var updated = items[index]
                updated.quantity = quantity
                items[index] = updated
            }
        } catch {
            print("❌ [背包] 更新物品数量失败: \(error)")
            self.errorMessage = "更新物品失败"
        }
    }

    /// 删除物品
    @MainActor
    private func deleteItem(id: UUID) async {
        do {
            try await supabase
                .from("inventory_items")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            print("✅ [背包] 删除物品成功")

            // 更新本地状态
            items.removeAll { $0.id == id }
        } catch {
            print("❌ [背包] 删除物品失败: \(error)")
            self.errorMessage = "删除物品失败"
        }
    }
}

// MARK: - 背包物品扩展（兼容旧代码）

extension InventoryItemDB {
    /// 转换为旧的BackpackItem格式（用于UI兼容）
    func toBackpackItem() -> BackpackItem {
        return BackpackItem(
            id: id.uuidString,
            itemId: item_id,
            quantity: quantity,
            quality: nil,
            obtainedAt: obtained_at,
            obtainedFrom: nil
        )
    }
}

extension ItemDefinitionDB {
    /// 转换为旧的ItemDefinition格式（用于UI兼容）
    func toItemDefinition() -> ItemDefinition {
        let rarityValue: ItemRarity
        switch rarity {
        case "common": rarityValue = .common
        case "rare": rarityValue = .rare
        case "epic": rarityValue = .epic
        default: rarityValue = .common
        }

        let categoryValue: ItemCategory
        switch category {
        case "food": categoryValue = .food
        case "water": categoryValue = .water
        case "medical": categoryValue = .medical
        case "material": categoryValue = .material
        case "tool": categoryValue = .tool
        default: categoryValue = .misc
        }

        return ItemDefinition(
            id: id,
            name: name,
            category: categoryValue,
            weight: weight,
            volume: 0,
            rarity: rarityValue,
            hasQuality: false,
            description: description ?? "",
            maxStack: max_stack
        )
    }
}
