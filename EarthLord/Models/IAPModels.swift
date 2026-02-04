//
//  IAPModels.swift
//  EarthLord
//
//  内购相关数据模型
//  Day 37: 物资包内购系统
//

import Foundation
import SwiftUI

// MARK: - IAP 产品模型

/// IAP 产品配置（从数据库读取）
struct IAPProduct: Codable, Identifiable {
    let id: String                      // Product ID
    let name: String                    // 产品名称
    let description: String?            // 产品描述
    let tier: Int                       // 等级 1-4
    let priceCny: Decimal               // 人民币价格
    let priceUsd: Decimal               // 美元价格
    let iconName: String?               // 图标名称
    let contents: [PackageItem]         // 固定内容
    let randomRewards: [RandomReward]?  // 随机奖励
    let randomPickCount: Int            // 随机抽取数量
    let firstPurchaseBonus: [PackageItem]? // 首购奖励
    let isActive: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description, tier
        case priceCny = "price_cny"
        case priceUsd = "price_usd"
        case iconName = "icon_name"
        case contents
        case randomRewards = "random_rewards"
        case randomPickCount = "random_pick_count"
        case firstPurchaseBonus = "first_purchase_bonus"
        case isActive = "is_active"
        case sortOrder = "sort_order"
    }

    /// 获取等级对应的颜色
    var tierColor: Color {
        switch tier {
        case 1: return .green
        case 2: return .blue
        case 3: return .purple
        case 4: return .orange
        default: return .gray
        }
    }

    /// 获取等级对应的图标
    var tierIcon: String {
        switch tier {
        case 1: return "shippingbox"
        case 2: return "shippingbox.fill"
        case 3: return "cube.box"
        case 4: return "cube.box.fill"
        default: return "shippingbox"
        }
    }

    /// 格式化价格显示
    var formattedPrice: String {
        return "¥\(priceCny)"
    }
}

/// 物资包内的物品
struct PackageItem: Codable, Identifiable {
    let itemId: String
    let quantity: Int

    var id: String { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
    }
}

/// 随机奖励配置
struct RandomReward: Codable, Identifiable {
    let itemId: String
    let quantity: Int
    let probability: Double     // 概率 0-1

    var id: String { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
        case probability
    }

    /// 格式化概率显示
    var formattedProbability: String {
        return "\(Int(probability * 100))%"
    }
}

// MARK: - 邮箱模型

/// 邮箱物品
struct MailboxItem: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let sourceType: String          // 'iap_purchase' / 'system_reward' / 'event'
    let sourceId: String?
    let title: String
    let message: String?
    let items: [PackageItem]
    let isClaimed: Bool
    let createdAt: Date
    let claimedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sourceType = "source_type"
        case sourceId = "source_id"
        case title, message, items
        case isClaimed = "is_claimed"
        case createdAt = "created_at"
        case claimedAt = "claimed_at"
    }

    /// 物品总数
    var totalItemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    /// 格式化时间
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: createdAt)
    }
}

// MARK: - 购买历史模型

/// 购买历史记录
struct PurchaseHistory: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let productId: String
    let productName: String
    let pricePaid: Decimal?
    let currency: String
    let transactionId: String
    let itemsReceived: [PackageItem]
    let purchasedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case productName = "product_name"
        case pricePaid = "price_paid"
        case currency
        case transactionId = "transaction_id"
        case itemsReceived = "items_received"
        case purchasedAt = "purchased_at"
    }

    /// 格式化价格
    var formattedPrice: String {
        guard let price = pricePaid else { return "免费" }
        return currency == "CNY" ? "¥\(price)" : "$\(price)"
    }

    /// 格式化日期
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: purchasedAt)
    }
}

// MARK: - 开箱结果模型

/// 开箱获得的物品（用于动画展示）
struct UnboxedItem: Identifiable {
    let id = UUID()
    let itemId: String
    let itemName: String
    let itemIcon: String
    let quantity: Int
    let rarity: ItemRarity

    /// 获取稀有度颜色
    var rarityColor: Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    /// 动画延迟时间
    var animationDelay: Double {
        switch rarity {
        case .common: return 0.2
        case .uncommon: return 0.3
        case .rare: return 0.4
        case .epic: return 0.8
        case .legendary: return 1.2
        }
    }
}

// ItemRarity 已在 ExplorationModels.swift 中定义
