//
//  RewardGenerator.swift
//  EarthLord
//
//  奖励生成器
//  根据行走距离生成探索奖励物品
//

import Foundation

// MARK: - 奖励等级

/// 奖励等级枚举
enum RewardTier: String, Codable {
    case none = "none"           // 无奖励（<200米）
    case bronze = "bronze"       // 铜级（200-500米）
    case silver = "silver"       // 银级（500-1000米）
    case gold = "gold"           // 金级（1000-2000米）
    case diamond = "diamond"     // 钻石级（>2000米）

    /// 中文显示名称
    var displayName: String {
        switch self {
        case .none: return "无"
        case .bronze: return "铜级"
        case .silver: return "银级"
        case .gold: return "金级"
        case .diamond: return "钻石级"
        }
    }

    /// 显示图标
    var icon: String {
        switch self {
        case .none: return "circle.slash"
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "medal.fill"
        case .diamond: return "diamond.fill"
        }
    }

    /// 颜色（用于UI显示）
    var colorName: String {
        switch self {
        case .none: return "gray"
        case .bronze: return "brown"
        case .silver: return "gray"
        case .gold: return "yellow"
        case .diamond: return "cyan"
        }
    }
}

// MARK: - 物品稀有度

/// 物品稀有度（用于奖励生成）
enum ItemRarityLevel: String, Codable {
    case common = "common"   // 普通
    case rare = "rare"       // 稀有
    case epic = "epic"       // 史诗
}

// MARK: - 奖励物品

/// 生成的奖励物品
struct RewardItem: Codable, Identifiable {
    var id: String { itemId }
    let itemId: String      // 物品ID
    let quantity: Int       // 数量
    let rarity: ItemRarityLevel  // 稀有度
}

// MARK: - 奖励生成器

/// 奖励生成器（单例）
/// 根据行走距离生成奖励物品
class RewardGenerator {

    // MARK: - 单例

    static let shared = RewardGenerator()

    private init() {}

    // MARK: - 物品池

    /// 普通物品池
    private let commonItemPool: [String] = [
        "canned_food",      // 罐头
        "biscuit",          // 饼干
        "pure_water",       // 纯净水
        "bandage",          // 绷带
        "matches",          // 火柴
        "cloth",            // 布料
        "rope",             // 绳索
        "nail"              // 钉子
    ]

    /// 稀有物品池
    private let rareItemPool: [String] = [
        "first_aid_kit",    // 急救包
        "flashlight",       // 手电筒
        "radio",            // 收音机
        "toolbox",          // 工具箱
        "canned_meat",      // 肉罐头
        "energy_drink"      // 能量饮料
    ]

    /// 史诗物品池
    private let epicItemPool: [String] = [
        "antibiotics",      // 抗生素
        "generator_parts",  // 发电机零件
        "gas_mask",         // 防毒面具
        "military_ration",  // 军用口粮
        "water_purifier"    // 净水器
    ]

    // MARK: - 等级参数

    /// 各等级的奖励参数
    private struct TierConfig {
        let itemCount: Int           // 物品数量
        let commonProbability: Double    // 普通概率
        let rareProbability: Double      // 稀有概率
        let epicProbability: Double      // 史诗概率
    }

    /// 等级配置表
    private let tierConfigs: [RewardTier: TierConfig] = [
        .bronze: TierConfig(itemCount: 1, commonProbability: 0.90, rareProbability: 0.10, epicProbability: 0.00),
        .silver: TierConfig(itemCount: 2, commonProbability: 0.70, rareProbability: 0.25, epicProbability: 0.05),
        .gold: TierConfig(itemCount: 3, commonProbability: 0.50, rareProbability: 0.35, epicProbability: 0.15),
        .diamond: TierConfig(itemCount: 5, commonProbability: 0.30, rareProbability: 0.40, epicProbability: 0.30)
    ]

    // MARK: - 公开方法

    /// 根据行走距离计算奖励等级
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励等级
    func calculateTier(distance: Double) -> RewardTier {
        switch distance {
        case ..<200:
            return .none
        case 200..<500:
            return .bronze
        case 500..<1000:
            return .silver
        case 1000..<2000:
            return .gold
        default:
            return .diamond
        }
    }

    /// 根据行走距离生成奖励物品
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励物品列表
    func generateReward(distance: Double) -> [RewardItem] {
        let tier = calculateTier(distance: distance)

        // 无奖励
        guard tier != .none else {
            print("🎁 [奖励] 距离不足200米，无奖励")
            return []
        }

        // 获取等级配置
        guard let config = tierConfigs[tier] else {
            return []
        }

        print("🎁 [奖励] 等级: \(tier.displayName)，生成 \(config.itemCount) 个物品")

        var rewards: [RewardItem] = []

        // 生成指定数量的物品
        for _ in 0..<config.itemCount {
            let reward = generateSingleItem(config: config)
            rewards.append(reward)
        }

        // 合并相同物品
        let mergedRewards = mergeRewards(rewards)

        print("🎁 [奖励] 生成完成: \(mergedRewards.map { "\($0.itemId) x\($0.quantity)" }.joined(separator: ", "))")

        return mergedRewards
    }

    // MARK: - 私有方法

    /// 生成单个奖励物品
    private func generateSingleItem(config: TierConfig) -> RewardItem {
        // 掷骰子决定稀有度
        let roll = Double.random(in: 0..<1)
        let rarity: ItemRarityLevel
        let itemPool: [String]

        if roll < config.commonProbability {
            // 普通
            rarity = .common
            itemPool = commonItemPool
        } else if roll < config.commonProbability + config.rareProbability {
            // 稀有
            rarity = .rare
            itemPool = rareItemPool
        } else {
            // 史诗
            rarity = .epic
            itemPool = epicItemPool
        }

        // 从物品池随机选择
        let itemId = itemPool.randomElement() ?? commonItemPool[0]

        return RewardItem(itemId: itemId, quantity: 1, rarity: rarity)
    }

    /// 合并相同物品
    private func mergeRewards(_ rewards: [RewardItem]) -> [RewardItem] {
        var merged: [String: RewardItem] = [:]

        for reward in rewards {
            if var existing = merged[reward.itemId] {
                // 合并数量
                existing = RewardItem(
                    itemId: existing.itemId,
                    quantity: existing.quantity + reward.quantity,
                    rarity: existing.rarity
                )
                merged[reward.itemId] = existing
            } else {
                merged[reward.itemId] = reward
            }
        }

        return Array(merged.values)
    }
}
