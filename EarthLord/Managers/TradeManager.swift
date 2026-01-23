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

    /// 创建交易挂单（使用 RPC 函数）
    /// - Parameters:
    ///   - offeringItems: 我提供的物品
    ///   - requestingItems: 我需要的物品
    ///   - validHours: 有效期（小时），默认 24 小时
    ///   - message: 留言（可选）
    ///   - latitude: 纬度（可选）
    ///   - longitude: 经度（可选）
    /// - Returns: 创建结果
    func createTradeOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem],
        validHours: Int = 24,
        message: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws -> UUID {
        print("📦 [Trade] 开始创建交易挂单...")

        // 构建 JSON 字符串
        let offeringJson = try JSONEncoder().encode(offeringItems)
        let requestingJson = try JSONEncoder().encode(requestingItems)

        guard let offeringString = String(data: offeringJson, encoding: .utf8),
              let requestingString = String(data: requestingJson, encoding: .utf8) else {
            throw TradeError.databaseError("JSON 编码失败")
        }

        // 调用 RPC 函数
        var params: [String: AnyJSON] = [
            "p_offering_items": .string(offeringString),
            "p_requesting_items": .string(requestingString),
            "p_expires_hours": .integer(validHours)
        ]

        if let message = message {
            params["p_message"] = .string(message)
        }

        if let lat = latitude, let lon = longitude {
            params["p_latitude"] = .double(lat)
            params["p_longitude"] = .double(lon)
        }

        let response: TradeRPCResponse = try await supabase
            .rpc("create_trade_offer_v2", params: params)
            .execute()
            .value

        if response.success {
            print("✅ [Trade] 挂单创建成功: \(response.offer_id?.uuidString ?? "unknown")")
            await loadMyOffers()

            if let offerId = response.offer_id {
                return offerId
            } else {
                throw TradeError.databaseError("未返回挂单ID")
            }
        } else {
            let errorMessage = response.error ?? "未知错误"
            print("❌ [Trade] 创建挂单失败: \(errorMessage)")
            throw TradeError.databaseError(errorMessage)
        }
    }

    /// 接受交易挂单（使用 RPC 函数）
    /// - Parameter offerId: 挂单 ID
    func acceptTradeOffer(offerId: UUID) async throws {
        print("📦 [Trade] 开始接受交易挂单: \(offerId)")

        // 调用 PostgreSQL 存储过程（使用 auth.uid() 自动获取用户ID）
        let response: TradeRPCResponse = try await supabase
            .rpc("accept_trade_offer", params: [
                "p_offer_id": AnyJSON.string(offerId.uuidString)
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

    /// 取消交易挂单（使用 RPC 函数）
    /// - Parameter offerId: 挂单 ID
    func cancelTradeOffer(offerId: UUID) async throws {
        print("📦 [Trade] 开始取消交易挂单: \(offerId)")

        // 调用 PostgreSQL 存储过程
        let response: TradeRPCResponse = try await supabase
            .rpc("cancel_trade_offer", params: [
                "p_offer_id": AnyJSON.string(offerId.uuidString)
            ])
            .execute()
            .value

        if response.success {
            print("✅ [Trade] 挂单取消成功，物品已退还")
            await loadMyOffers()
        } else {
            let errorMessage = response.error ?? "未知错误"
            print("❌ [Trade] 取消挂单失败: \(errorMessage)")
            throw TradeError.databaseError(errorMessage)
        }
    }

    /// 加载我的挂单（使用 RPC 函数）
    func loadMyOffers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let offers: [TradeOffer] = try await supabase
                .rpc("get_my_trade_offers")
                .execute()
                .value

            myOffers = offers
            print("📦 [Trade] 加载了 \(offers.count) 个我的挂单")
        } catch {
            print("❌ [Trade] 加载我的挂单失败: \(error)")
        }
    }

    /// 加载可接受的挂单（其他人的）
    func loadAvailableOffers(latitude: Double? = nil, longitude: Double? = nil, radiusKm: Double = 10) async {
        isLoading = true
        defer { isLoading = false }

        do {
            var params: [String: AnyJSON] = [
                "p_radius_km": .double(radiusKm)
            ]

            if let lat = latitude, let lon = longitude {
                params["p_latitude"] = .double(lat)
                params["p_longitude"] = .double(lon)
            }

            let offers: [TradeOffer] = try await supabase
                .rpc("get_nearby_trade_offers", params: params)
                .execute()
                .value

            availableOffers = offers
            print("📦 [Trade] 加载了 \(offers.count) 个可接受的挂单")
        } catch {
            print("❌ [Trade] 加载可接受挂单失败: \(error)")
        }
    }

    /// 加载交易历史（使用 RPC 函数）
    func loadTradeHistory() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let history: [TradeHistory] = try await supabase
                .rpc("get_my_trade_history")
                .execute()
                .value

            tradeHistory = history
            print("📦 [Trade] 加载了 \(history.count) 条交易历史")
        } catch {
            print("❌ [Trade] 加载交易历史失败: \(error)")
        }
    }

    /// 评价交易（使用 RPC 函数）
    /// - Parameters:
    ///   - historyId: 交易历史 ID
    ///   - rating: 评分 (1-5)
    ///   - comment: 评语（可选）
    func rateTrade(historyId: UUID, rating: Int, comment: String?) async throws {
        guard rating >= 1 && rating <= 5 else {
            throw TradeError.databaseError("评分必须在 1-5 之间")
        }

        var params: [String: AnyJSON] = [
            "p_history_id": .string(historyId.uuidString),
            "p_rating": .integer(rating)
        ]

        if let comment = comment {
            params["p_comment"] = .string(comment)
        }

        let response: TradeRPCResponse = try await supabase
            .rpc("rate_trade", params: params)
            .execute()
            .value

        if response.success {
            print("✅ [Trade] 评价提交成功")
            await loadTradeHistory()
        } else {
            let errorMessage = response.error ?? "未知错误"
            print("❌ [Trade] 评价失败: \(errorMessage)")
            throw TradeError.databaseError(errorMessage)
        }
    }

    /// 清理过期挂单
    func cleanupExpiredOffers() async {
        do {
            // 调用数据库函数清理（返回清理的数量）
            let count: Int = try await supabase
                .rpc("cleanup_expired_trade_offers")
                .execute()
                .value

            print("✅ [Trade] 过期挂单清理完成，清理了 \(count) 个挂单")
            await loadMyOffers()
        } catch {
            print("❌ [Trade] 清理过期挂单失败: \(error)")
        }
    }
}
