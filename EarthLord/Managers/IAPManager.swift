//
//  IAPManager.swift
//  EarthLord
//
//  内购管理器
//  Day 37: StoreKit 2 集成，物资包购买
//

import Foundation
import StoreKit
import Supabase
import Combine

// MARK: - IAP Manager

@MainActor
class IAPManager: ObservableObject {

    // MARK: - 单例

    static let shared = IAPManager()

    // MARK: - Published 属性

    @Published var products: [IAPProduct] = []          // 数据库产品配置
    @Published var storeProducts: [Product] = []        // StoreKit 产品
    @Published var mailboxItems: [MailboxItem] = []     // 邮箱物品
    @Published var purchaseHistory: [PurchaseHistory] = [] // 购买历史
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var errorMessage: String?

    // 开箱相关
    @Published var showUnboxing = false
    @Published var unboxedItems: [UnboxedItem] = []
    @Published var currentUnboxingProduct: IAPProduct?

    // MARK: - 产品 ID

    private let productIds = [
        "com.earthlord.supply.emergency",
        "com.earthlord.supply.survival",
        "com.earthlord.supply.elite",
        "com.earthlord.supply.legendary"
    ]

    // MARK: - 初始化

    private init() {
        // 监听交易更新
        Task {
            await listenForTransactions()
        }
    }

    // MARK: - 加载产品

    /// 从数据库加载产品配置
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [IAPProduct] = try await supabase
                .from("iap_products")
                .select()
                .eq("is_active", value: true)
                .order("sort_order")
                .execute()
                .value

            products = response

            // 同时加载 StoreKit 产品
            await loadStoreProducts()
        } catch {
            print("加载产品失败: \(error)")
            errorMessage = "加载产品失败"
        }

        isLoading = false
    }

    /// 从 App Store 加载产品
    private func loadStoreProducts() async {
        do {
            storeProducts = try await Product.products(for: productIds)
        } catch {
            print("加载 StoreKit 产品失败: \(error)")
        }
    }

    /// 获取指定产品的 StoreKit 产品
    func getStoreProduct(for productId: String) -> Product? {
        storeProducts.first { $0.id == productId }
    }

    // MARK: - 购买

    /// 购买产品
    func purchase(_ product: IAPProduct) async -> Bool {
        guard let storeProduct = getStoreProduct(for: product.id) else {
            errorMessage = "产品不可用"
            return false
        }

        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await storeProduct.purchase()

            switch result {
            case .success(let verification):
                // 验证交易
                let transaction = try checkVerified(verification)

                // 处理购买成功
                await handlePurchaseSuccess(product: product, transaction: transaction)

                // 完成交易
                await transaction.finish()

                isPurchasing = false
                return true

            case .pending:
                errorMessage = "购买待处理"
                isPurchasing = false
                return false

            case .userCancelled:
                isPurchasing = false
                return false

            @unknown default:
                errorMessage = "未知错误"
                isPurchasing = false
                return false
            }
        } catch {
            print("购买失败: \(error)")
            errorMessage = "购买失败: \(error.localizedDescription)"
            isPurchasing = false
            return false
        }
    }

    /// 验证交易
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    /// 处理购买成功
    private func handlePurchaseSuccess(product: IAPProduct, transaction: Transaction) async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        // 1. 生成物品列表（固定 + 随机）
        var allItems = product.contents

        // 处理随机奖励
        if let randomRewards = product.randomRewards, product.randomPickCount > 0 {
            let pickedRewards = pickRandomRewards(from: randomRewards, count: product.randomPickCount)
            allItems.append(contentsOf: pickedRewards)
        }

        // 2. 保存到邮箱
        do {
            let mailboxData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "source_type": .string("iap_purchase"),
                "source_id": .string(String(transaction.id)),
                "title": .string(product.name),
                "message": .string("感谢购买！物资已送达，请查收。"),
                "items": .array(allItems.map { item in
                    .object([
                        "item_id": .string(item.itemId),
                        "quantity": .integer(item.quantity)
                    ])
                })
            ]

            try await supabase
                .from("player_mailbox")
                .insert(mailboxData)
                .execute()
        } catch {
            print("保存到邮箱失败: \(error)")
        }

        // 3. 保存购买历史
        do {
            let historyData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "product_id": .string(product.id),
                "product_name": .string(product.name),
                "price_paid": .double(Double(truncating: product.priceCny as NSNumber)),
                "currency": .string("CNY"),
                "transaction_id": .string(String(transaction.id)),
                "items_received": .array(allItems.map { item in
                    .object([
                        "item_id": .string(item.itemId),
                        "quantity": .integer(item.quantity)
                    ])
                })
            ]

            try await supabase
                .from("iap_purchase_history")
                .insert(historyData)
                .execute()
        } catch {
            print("保存购买历史失败: \(error)")
        }

        // 4. 准备开箱动画
        await prepareUnboxingAnimation(product: product, items: allItems)
    }

    /// 随机抽取奖励
    private func pickRandomRewards(from rewards: [RandomReward], count: Int) -> [PackageItem] {
        var result: [PackageItem] = []
        var availableRewards = rewards

        for _ in 0..<count {
            guard !availableRewards.isEmpty else { break }

            // 按概率抽取
            let totalProbability = availableRewards.reduce(0) { $0 + $1.probability }
            let random = Double.random(in: 0..<totalProbability)

            var cumulative = 0.0
            for (index, reward) in availableRewards.enumerated() {
                cumulative += reward.probability
                if random < cumulative {
                    result.append(PackageItem(itemId: reward.itemId, quantity: reward.quantity))
                    availableRewards.remove(at: index)
                    break
                }
            }
        }

        return result
    }

    // MARK: - 开箱动画

    /// 准备开箱动画数据
    private func prepareUnboxingAnimation(product: IAPProduct, items: [PackageItem]) async {
        // 获取物品定义
        do {
            let itemIds = items.map { $0.itemId }
            let definitions: [ItemDefinitionDB] = try await supabase
                .from("item_definitions")
                .select()
                .in("id", values: itemIds)
                .execute()
                .value

            let definitionMap = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })

            unboxedItems = items.compactMap { item in
                guard let def = definitionMap[item.itemId] else { return nil }
                return UnboxedItem(
                    itemId: item.itemId,
                    itemName: def.name,
                    itemIcon: def.icon,
                    quantity: item.quantity,
                    rarity: ItemRarity(rawValue: def.rarity) ?? .common
                )
            }

            currentUnboxingProduct = product
            showUnboxing = true
        } catch {
            print("获取物品定义失败: \(error)")
        }
    }

    /// 关闭开箱动画
    func closeUnboxing() {
        showUnboxing = false
        unboxedItems = []
        currentUnboxingProduct = nil
    }

    // MARK: - 邮箱

    /// 加载邮箱物品
    func loadMailbox() async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        do {
            let response: [MailboxItem] = try await supabase
                .from("player_mailbox")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_claimed", value: false)
                .order("created_at", ascending: false)
                .execute()
                .value

            mailboxItems = response
        } catch {
            print("加载邮箱失败: \(error)")
        }
    }

    /// 领取邮箱物品
    func claimMailboxItem(_ item: MailboxItem) async -> Bool {
        guard let userId = supabase.auth.currentUser?.id else { return false }

        // 检查背包空间
        let inventoryManager = InventoryManager.shared
        let currentCount = inventoryManager.items.count
        let maxCapacity = 100 // 背包上限
        let itemCount = item.items.count

        if currentCount + itemCount > maxCapacity {
            errorMessage = "背包空间不足，请先清理背包"
            return false
        }

        do {
            // 1. 添加物品到背包
            for packageItem in item.items {
                await inventoryManager.addItem(
                    itemId: packageItem.itemId,
                    quantity: packageItem.quantity
                )
            }

            // 2. 标记邮件为已领取
            let updateData: [String: AnyJSON] = [
                "is_claimed": .bool(true),
                "claimed_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            try await supabase
                .from("player_mailbox")
                .update(updateData)
                .eq("id", value: item.id.uuidString)
                .execute()

            // 3. 刷新邮箱
            await loadMailbox()

            return true
        } catch {
            print("领取失败: \(error)")
            errorMessage = "领取失败"
            return false
        }
    }

    /// 未领取邮件数量
    var unclaimedCount: Int {
        mailboxItems.filter { !$0.isClaimed }.count
    }

    // MARK: - 购买历史

    /// 加载购买历史
    func loadPurchaseHistory() async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        do {
            let response: [PurchaseHistory] = try await supabase
                .from("iap_purchase_history")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("purchased_at", ascending: false)
                .execute()
                .value

            purchaseHistory = response
        } catch {
            print("加载购买历史失败: \(error)")
        }
    }

    // MARK: - 交易监听

    /// 监听交易更新
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                await transaction.finish()
            } catch {
                print("交易验证失败: \(error)")
            }
        }
    }
}

// MARK: - 错误定义

enum StoreError: Error {
    case failedVerification
    case productNotFound
    case purchaseFailed
}
