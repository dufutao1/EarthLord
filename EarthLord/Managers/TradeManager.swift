//
//  TradeManager.swift
//  EarthLord
//
//  交易系统管理器
//  负责处理玩家之间的物品交易
//

import Foundation
import Supabase
import Combine

@MainActor
final class TradeManager: ObservableObject {

    // MARK: - 单例

    static let shared = TradeManager()

    private init() {}

    // MARK: - Published 状态

    /// 我发布的挂单列表
    @Published var myOffers: [TradeOffer] = []

    /// 可接受的挂单列表（其他人的）
    @Published var availableOffers: [TradeOffer] = []

    /// 交易历史列表
    @Published var tradeHistory: [TradeHistory] = []

    /// 是否正在加载
    @Published var isLoading = false

    // MARK: - 公开方法

    /// 创建交易挂单
    /// - Parameters:
    ///   - offeringItems: 我提供的物品
    ///   - requestingItems: 我需要的物品
    ///   - validHours: 有效期（小时），默认 24 小时
    ///   - message: 留言（可选）
    /// - Returns: 创建的挂单
    func createTradeOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        validHours: Int = 24,
        message: String? = nil
    ) async throws -> TradeOffer {
        print("📦 [Trade] 开始创建交易挂单...")

        // 1. 获取当前用户
        guard let userId = supabase.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        // 2. 验证物品是否足够（从数据库查询）
        for item in offeringItems {
            // 从数据库查询物品数量
            let inventoryItems: [InventoryItemDB] = try await supabase
                .from("inventory")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("item_id", value: item.item_id)
                .execute()
                .value

            let available = inventoryItems.first?.quantity ?? 0

            if available < item.quantity {
                throw TradeError.insufficientItems(item.item_id)
            }
        }

        // 3. 扣除物品（锁定到挂单中）
        for item in offeringItems {
            await InventoryManager.shared.removeItem(itemId: item.item_id, quantity: item.quantity)
        }

        // 4. 计算过期时间
        let expiresAt = Date().addingTimeInterval(TimeInterval(validHours * 3600))

        // 5. 获取用户名
        let username = supabase.auth.currentUser?.email ?? "未知用户"

        // 6. 创建挂单
        let offerData: [String: AnyJSON] = [
            "owner_id": .string(userId.uuidString),
            "owner_username": .string(username),
            "offering_items": .array(offeringItems.map { item in
                    .object([
                        "item_id": .string(item.item_id),
                        "quantity": .integer(item.quantity)
                    ])
            }),
            "requesting_items": .array(requestingItems.map { item in
                    .object([
                        "item_id": .string(item.item_id),
                        "quantity": .integer(item.quantity)
                    ])
            }),
            "status": .string("active"),
            "message": message.map { .string($0) } ?? .null,
            "expires_at": .string(ISO8601DateFormatter().string(from: expiresAt))
        ]

        let response: TradeOffer = try await supabase
            .from("trade_offers")
            .insert(offerData)
            .select()
            .single()
            .execute()
            .value

        print("✅ [Trade] 挂单创建成功: \(response.id)")

        // 7. 刷新我的挂单列表
        await loadMyOffers()

        return response
    }

    /// 接受交易挂单
    /// - Parameter offerId: 挂单 ID
    func acceptTradeOffer(offerId: UUID) async throws {
        print("📦 [Trade] 开始接受交易挂单: \(offerId)")

        guard let userId = supabase.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        let username = supabase.auth.currentUser?.email ?? "未知用户"

        // 调用 PostgreSQL 存储过程（带行级锁和事务）
        let response: AcceptTradeResponse = try await supabase
            .rpc("accept_trade_offer", params: [
                "p_offer_id": offerId.uuidString,
                "p_buyer_id": userId.uuidString,
                "p_buyer_username": username
            ])
            .execute()
            .value

        if response.success {
            print("✅ [Trade] 交易接受成功")

            // 刷新相关数据
            await loadAvailableOffers()
            await loadTradeHistory()
            await InventoryManager.shared.loadInventory()
        } else {
            let errorMessage = response.error ?? "未知错误"
            print("❌ [Trade] 交易接受失败: \(errorMessage)")
            throw TradeError.databaseError(errorMessage)
        }
    }

    /// 取消交易挂单
    /// - Parameter offerId: 挂单 ID
    func cancelTradeOffer(offerId: UUID) async throws {
        print("📦 [Trade] 开始取消交易挂单: \(offerId)")

        guard let userId = supabase.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        // 1. 查询挂单
        let offer: TradeOffer = try await supabase
            .from("trade_offers")
            .select()
            .eq("id", value: offerId.uuidString)
            .single()
            .execute()
            .value

        // 2. 验证权限
        guard offer.owner_id == userId else {
            throw TradeError.invalidPermission
        }

        guard offer.status == .active else {
            throw TradeError.offerUnavailable
        }

        // 3. 退还物品
        for item in offer.offering_items {
            await InventoryManager.shared.addItem(
                itemId: item.item_id,
                quantity: item.quantity
            )
        }

        // 4. 更新挂单状态
        try await supabase
            .from("trade_offers")
            .update(["status": "cancelled"])
            .eq("id", value: offerId.uuidString)
            .execute()

        print("✅ [Trade] 挂单取消成功，物品已退还")

        // 5. 刷新挂单列表
        await loadMyOffers()
    }

    /// 加载我的挂单
    func loadMyOffers() async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            myOffers = offers
            print("📦 [Trade] 加载了 \(offers.count) 个我的挂单")
        } catch {
            print("❌ [Trade] 加载我的挂单失败: \(error)")
        }
    }

    /// 加载可接受的挂单（其他人的）
    func loadAvailableOffers() async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let offers: [TradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("status", value: "active")
                .neq("owner_id", value: userId.uuidString)
                .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .order("created_at", ascending: false)
                .execute()
                .value

            availableOffers = offers
            print("📦 [Trade] 加载了 \(offers.count) 个可接受的挂单")
        } catch {
            print("❌ [Trade] 加载可接受挂单失败: \(error)")
        }
    }

    /// 加载交易历史
    func loadTradeHistory() async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // 查询我作为卖家或买家的交易
            let history: [TradeHistory] = try await supabase
                .from("trade_history")
                .select()
                .or("seller_id.eq.\(userId.uuidString),buyer_id.eq.\(userId.uuidString)")
                .order("completed_at", ascending: false)
                .execute()
                .value

            tradeHistory = history
            print("📦 [Trade] 加载了 \(history.count) 条交易历史")
        } catch {
            print("❌ [Trade] 加载交易历史失败: \(error)")
        }
    }

    /// 评价交易
    /// - Parameters:
    ///   - historyId: 交易历史 ID
    ///   - rating: 评分 (1-5)
    ///   - comment: 评语（可选）
    func rateTrade(historyId: UUID, rating: Int, comment: String?) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw TradeError.notAuthenticated
        }

        guard rating >= 1 && rating <= 5 else {
            throw TradeError.databaseError("评分必须在 1-5 之间")
        }

        // 1. 查询交易历史
        let history: TradeHistory = try await supabase
            .from("trade_history")
            .select()
            .eq("id", value: historyId.uuidString)
            .single()
            .execute()
            .value

        // 2. 判断角色
        var updateData: [String: AnyJSON] = [:]

        if history.seller_id == userId {
            // 卖家评价买家
            guard history.seller_rating == nil else {
                throw TradeError.alreadyRated
            }
            updateData["seller_rating"] = .integer(rating)
            if let comment = comment {
                updateData["seller_comment"] = .string(comment)
            }
        } else if history.buyer_id == userId {
            // 买家评价卖家
            guard history.buyer_rating == nil else {
                throw TradeError.alreadyRated
            }
            updateData["buyer_rating"] = .integer(rating)
            if let comment = comment {
                updateData["buyer_comment"] = .string(comment)
            }
        } else {
            throw TradeError.invalidPermission
        }

        // 3. 更新评价
        try await supabase
            .from("trade_history")
            .update(updateData)
            .eq("id", value: historyId.uuidString)
            .execute()

        print("✅ [Trade] 评价提交成功")

        // 4. 刷新交易历史
        await loadTradeHistory()
    }

    /// 清理过期挂单
    func cleanupExpiredOffers() async {
        do {
            // 调用数据库函数清理（返回清理的数量）
            let result = try await supabase
                .rpc("cleanup_expired_trade_offers")
                .execute()

            print("✅ [Trade] 过期挂单清理完成")
            await loadMyOffers()
        } catch {
            print("❌ [Trade] 清理过期挂单失败: \(error)")
        }
    }
}

