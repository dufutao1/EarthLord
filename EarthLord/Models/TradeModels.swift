//
//  TradeModels.swift
//  EarthLord
//
//  交易系统数据模型
//

import Foundation

// MARK: - 交易物品

/// 交易物品（物品ID + 数量）
struct TradeItem: Codable, Hashable, Identifiable {
    var id: String { item_id }
    let item_id: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case item_id = "item_id"
        case quantity
    }
}

// MARK: - 交易状态

/// 交易挂单状态
enum TradeOfferStatus: String, Codable {
    case active = "active"         // 等待中
    case completed = "completed"   // 已完成
    case cancelled = "cancelled"   // 已取消
    case expired = "expired"       // 已过期

    var displayName: String {
        switch self {
        case .active: return "等待中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .expired: return "已过期"
        }
    }

    var color: String {
        switch self {
        case .active: return "green"
        case .completed: return "blue"
        case .cancelled: return "gray"
        case .expired: return "orange"
        }
    }
}

// MARK: - 交易挂单

/// 交易挂单模型
struct TradeOffer: Codable, Identifiable {
    let id: UUID
    let owner_id: UUID
    let owner_username: String?

    /// 提供的物品列表
    let offering_items: [TradeItem]

    /// 需要的物品列表
    let requesting_items: [TradeItem]

    let status: TradeOfferStatus
    let message: String?

    let created_at: Date
    let expires_at: Date
    let completed_at: Date?

    let completed_by_user_id: UUID?
    let completed_by_username: String?

    // MARK: - 辅助属性

    /// 是否已过期
    var isExpired: Bool {
        expires_at < Date()
    }

    /// 是否可接受
    var isAvailable: Bool {
        status == .active && !isExpired
    }

    /// 是否是我的挂单
    func isOwnedBy(_ userId: UUID) -> Bool {
        owner_id == userId
    }

    /// 剩余时间（秒）
    var remainingSeconds: TimeInterval {
        max(0, expires_at.timeIntervalSinceNow)
    }

    /// 剩余时间（格式化）
    var remainingTimeText: String {
        let seconds = remainingSeconds
        if seconds <= 0 {
            return "已过期"
        }

        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case owner_id
        case owner_username
        case offering_items
        case requesting_items
        case status
        case message
        case created_at
        case expires_at
        case completed_at
        case completed_by_user_id
        case completed_by_username
    }
}

// MARK: - 交易历史

/// 交易历史模型
struct TradeHistory: Codable, Identifiable {
    let id: UUID
    let offer_id: UUID?

    let seller_id: UUID
    let seller_username: String?
    let buyer_id: UUID
    let buyer_username: String?

    /// 交换的物品详情
    let items_exchanged: TradeExchangeDetail

    let completed_at: Date

    // 评价信息
    let seller_rating: Int?
    let seller_comment: String?
    let buyer_rating: Int?
    let buyer_comment: String?

    // MARK: - 辅助方法

    /// 判断用户在交易中的角色
    func role(for userId: UUID) -> TradeRole? {
        if seller_id == userId {
            return .seller
        } else if buyer_id == userId {
            return .buyer
        }
        return nil
    }

    /// 获取对方的用户名
    func counterpartyUsername(for userId: UUID) -> String? {
        if seller_id == userId {
            return buyer_username
        } else if buyer_id == userId {
            return seller_username
        }
        return nil
    }

    /// 用户是否已评价
    func hasRated(userId: UUID) -> Bool {
        if seller_id == userId {
            return seller_rating != nil
        } else if buyer_id == userId {
            return buyer_rating != nil
        }
        return false
    }

    enum CodingKeys: String, CodingKey {
        case id
        case offer_id
        case seller_id
        case seller_username
        case buyer_id
        case buyer_username
        case items_exchanged
        case completed_at
        case seller_rating
        case seller_comment
        case buyer_rating
        case buyer_comment
    }
}

// MARK: - 交易详情

/// 交易物品交换详情
struct TradeExchangeDetail: Codable {
    let offered: [TradeItem]
    let requested: [TradeItem]
}

// MARK: - 交易角色

/// 交易中的角色
enum TradeRole {
    case seller  // 卖家（发布者）
    case buyer   // 买家（接受者）

    var displayName: String {
        switch self {
        case .seller: return "卖家"
        case .buyer: return "买家"
        }
    }
}

// MARK: - RPC 响应

/// 接受交易的 RPC 响应
struct AcceptTradeResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

// MARK: - 交易错误

/// 交易相关错误
enum TradeError: LocalizedError {
    case notAuthenticated
    case insufficientItems(String)  // 物品不足
    case offerNotFound
    case offerExpired
    case offerUnavailable
    case cannotAcceptOwnOffer
    case alreadyRated
    case invalidPermission
    case databaseError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "请先登录"
        case .insufficientItems(let itemName):
            return "物品不足：\(itemName)"
        case .offerNotFound:
            return "交易挂单不存在"
        case .offerExpired:
            return "交易挂单已过期"
        case .offerUnavailable:
            return "交易挂单已失效"
        case .cannotAcceptOwnOffer:
            return "不能接受自己的挂单"
        case .alreadyRated:
            return "已经评价过此交易"
        case .invalidPermission:
            return "没有权限执行此操作"
        case .databaseError(let message):
            return "数据库错误：\(message)"
        }
    }
}
