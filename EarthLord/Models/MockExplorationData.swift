//
//  MockExplorationData.swift
//  EarthLord
//
//  探索模块测试假数据
//  用于开发和测试阶段，模拟真实的探索场景数据
//

import Foundation
import CoreLocation

// MARK: - POI 状态枚举

/// 兴趣点发现状态
enum POIDiscoveryStatus: String, Codable {
    case undiscovered = "undiscovered"  // 未发现（地图上不显示或显示为问号）
    case discovered = "discovered"       // 已发现（显示详细信息）
}

/// 兴趣点资源状态
enum POIResourceStatus: String, Codable {
    case hasResources = "has_resources"  // 有物资可搜刮
    case empty = "empty"                  // 已被搜空
    case unknown = "unknown"              // 未知（未探索）
}

/// 兴趣点类型
enum POIType: String, Codable {
    case supermarket = "supermarket"     // 超市
    case hospital = "hospital"           // 医院
    case gasStation = "gas_station"      // 加油站
    case pharmacy = "pharmacy"           // 药店
    case factory = "factory"             // 工厂
    case warehouse = "warehouse"         // 仓库
    case residential = "residential"     // 居民区

    /// 中文名称
    var displayName: String {
        switch self {
        case .supermarket: return "超市"
        case .hospital: return "医院"
        case .gasStation: return "加油站"
        case .pharmacy: return "药店"
        case .factory: return "工厂"
        case .warehouse: return "仓库"
        case .residential: return "居民区"
        }
    }
}

// MARK: - POI 模型

/// 兴趣点（Point of Interest）模型
struct POI: Identifiable, Codable {
    let id: String
    let name: String                          // POI 名称
    let type: POIType                         // POI 类型
    let coordinate: CLLocationCoordinate2D   // 位置坐标
    let discoveryStatus: POIDiscoveryStatus  // 发现状态
    let resourceStatus: POIResourceStatus    // 资源状态
    let dangerLevel: Int                      // 危险等级 1-5
    let description: String                   // 描述文本

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case latitude, longitude
        case discoveryStatus = "discovery_status"
        case resourceStatus = "resource_status"
        case dangerLevel = "danger_level"
        case description
    }

    init(id: String, name: String, type: POIType, coordinate: CLLocationCoordinate2D,
         discoveryStatus: POIDiscoveryStatus, resourceStatus: POIResourceStatus,
         dangerLevel: Int, description: String) {
        self.id = id
        self.name = name
        self.type = type
        self.coordinate = coordinate
        self.discoveryStatus = discoveryStatus
        self.resourceStatus = resourceStatus
        self.dangerLevel = dangerLevel
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(POIType.self, forKey: .type)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        discoveryStatus = try container.decode(POIDiscoveryStatus.self, forKey: .discoveryStatus)
        resourceStatus = try container.decode(POIResourceStatus.self, forKey: .resourceStatus)
        dangerLevel = try container.decode(Int.self, forKey: .dangerLevel)
        description = try container.decode(String.self, forKey: .description)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(discoveryStatus, forKey: .discoveryStatus)
        try container.encode(resourceStatus, forKey: .resourceStatus)
        try container.encode(dangerLevel, forKey: .dangerLevel)
        try container.encode(description, forKey: .description)
    }
}

// MARK: - 物品相关枚举

/// 物品分类
enum ItemCategory: String, Codable {
    case water = "water"           // 水类
    case food = "food"             // 食物
    case medical = "medical"       // 医疗用品
    case material = "material"     // 材料
    case tool = "tool"             // 工具
    case weapon = "weapon"         // 武器
    case clothing = "clothing"     // 衣物
    case misc = "misc"             // 杂物

    /// 中文名称
    var displayName: String {
        switch self {
        case .water: return "水类"
        case .food: return "食物"
        case .medical: return "医疗"
        case .material: return "材料"
        case .tool: return "工具"
        case .weapon: return "武器"
        case .clothing: return "衣物"
        case .misc: return "杂物"
        }
    }
}

/// 物品品质（部分物品可能没有品质区分）
enum ItemQuality: String, Codable {
    case poor = "poor"           // 劣质
    case normal = "normal"       // 普通
    case good = "good"           // 良好
    case excellent = "excellent" // 优秀
    case rare = "rare"           // 稀有

    /// 中文名称
    var displayName: String {
        switch self {
        case .poor: return "劣质"
        case .normal: return "普通"
        case .good: return "良好"
        case .excellent: return "优秀"
        case .rare: return "稀有"
        }
    }
}

/// 物品稀有度（影响掉落概率）
enum ItemRarity: String, Codable {
    case common = "common"         // 常见 (60%)
    case uncommon = "uncommon"     // 不常见 (25%)
    case rare = "rare"             // 稀有 (10%)
    case epic = "epic"             // 史诗 (4%)
    case legendary = "legendary"   // 传说 (1%)

    /// 中文名称
    var displayName: String {
        switch self {
        case .common: return "常见"
        case .uncommon: return "不常见"
        case .rare: return "稀有"
        case .epic: return "史诗"
        case .legendary: return "传说"
        }
    }
}

// MARK: - 物品定义模型

/// 物品定义（静态数据表，定义物品的基础属性）
struct ItemDefinition: Identifiable, Codable {
    let id: String                // 物品唯一标识符
    let name: String              // 中文名称
    let category: ItemCategory    // 物品分类
    let weight: Double            // 单个重量（千克）
    let volume: Double            // 单个体积（升）
    let rarity: ItemRarity        // 稀有度
    let hasQuality: Bool          // 是否有品质区分
    let description: String       // 物品描述
    let maxStack: Int             // 最大堆叠数量

    enum CodingKeys: String, CodingKey {
        case id, name, category, weight, volume, rarity
        case hasQuality = "has_quality"
        case description
        case maxStack = "max_stack"
    }
}

// MARK: - 背包物品模型

/// 背包中的物品实例（包含数量和品质）
struct BackpackItem: Identifiable, Codable {
    let id: String                     // 实例唯一ID
    let itemId: String                 // 对应物品定义ID
    var quantity: Int                  // 数量
    let quality: ItemQuality?          // 品质（可选，部分物品无品质）
    let obtainedAt: Date               // 获得时间
    let obtainedFrom: String?          // 获得来源（POI名称等）

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case quantity, quality
        case obtainedAt = "obtained_at"
        case obtainedFrom = "obtained_from"
    }
}

// MARK: - 探索结果模型

/// 单次探索统计数据
struct ExplorationStats: Codable {
    let walkDistance: Double           // 本次行走距离（米）
    let totalWalkDistance: Double      // 累计行走距离（米）
    let walkDistanceRank: Int          // 行走距离排名

    let exploredArea: Double           // 本次探索面积（平方米）
    let totalExploredArea: Double      // 累计探索面积（平方米）
    let exploredAreaRank: Int          // 探索面积排名

    let duration: TimeInterval         // 探索时长（秒）
    let startTime: Date                // 开始时间
    let endTime: Date                  // 结束时间

    enum CodingKeys: String, CodingKey {
        case walkDistance = "walk_distance"
        case totalWalkDistance = "total_walk_distance"
        case walkDistanceRank = "walk_distance_rank"
        case exploredArea = "explored_area"
        case totalExploredArea = "total_explored_area"
        case exploredAreaRank = "explored_area_rank"
        case duration
        case startTime = "start_time"
        case endTime = "end_time"
    }

    /// 格式化行走距离显示
    var formattedWalkDistance: String {
        if walkDistance >= 1000 {
            return String(format: "%.2f km", walkDistance / 1000)
        }
        return String(format: "%.0f m", walkDistance)
    }

    /// 格式化探索面积显示
    var formattedExploredArea: String {
        if exploredArea >= 1_000_000 {
            return String(format: "%.2f km²", exploredArea / 1_000_000)
        } else if exploredArea >= 10000 {
            return String(format: "%.1f 万m²", exploredArea / 10000)
        }
        return String(format: "%.0f m²", exploredArea)
    }

    /// 格式化时长显示
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)小时\(remainingMinutes)分钟"
        }
        return "\(minutes)分\(seconds)秒"
    }
}

/// 探索获得的物品
struct ExplorationLoot: Codable {
    let itemId: String      // 物品定义ID
    let quantity: Int       // 获得数量
    let quality: ItemQuality?  // 品质

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity, quality
    }
}

/// 完整的探索结果
struct ExplorationResult: Codable {
    let id: String                    // 探索记录ID
    let userId: String                // 用户ID
    let stats: ExplorationStats       // 统计数据
    let loot: [ExplorationLoot]       // 获得的物品
    let discoveredPOIs: [String]      // 新发现的POI ID列表
    let visitedPOIs: [String]         // 访问过的POI ID列表

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case stats, loot
        case discoveredPOIs = "discovered_pois"
        case visitedPOIs = "visited_pois"
    }
}

// MARK: - Mock 数据

/// 探索模块测试假数据
struct MockExplorationData {

    // MARK: - POI 假数据

    /// 测试用 POI 列表
    /// 包含5个不同状态的兴趣点，用于测试地图显示和交互
    static let mockPOIs: [POI] = [
        // 废弃超市：已发现，有物资
        POI(
            id: "poi_001",
            name: "废弃超市",
            type: .supermarket,
            coordinate: CLLocationCoordinate2D(latitude: 23.1291, longitude: 113.2644),
            discoveryStatus: .discovered,
            resourceStatus: .hasResources,
            dangerLevel: 2,
            description: "一家被遗弃的大型超市，货架上还散落着一些物资。注意可能有其他幸存者出没。"
        ),
        // 医院废墟：已发现，已被搜空
        POI(
            id: "poi_002",
            name: "医院废墟",
            type: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 23.1305, longitude: 113.2680),
            discoveryStatus: .discovered,
            resourceStatus: .empty,
            dangerLevel: 4,
            description: "曾经繁忙的医院如今只剩断壁残垣，医疗物资已被搜刮一空。这里危险等级较高。"
        ),
        // 加油站：未发现
        POI(
            id: "poi_003",
            name: "加油站",
            type: .gasStation,
            coordinate: CLLocationCoordinate2D(latitude: 23.1275, longitude: 113.2700),
            discoveryStatus: .undiscovered,
            resourceStatus: .unknown,
            dangerLevel: 3,
            description: "路边的加油站，可能还有燃料和便利店物资。"
        ),
        // 药店废墟：已发现，有物资
        POI(
            id: "poi_004",
            name: "药店废墟",
            type: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 23.1260, longitude: 113.2620),
            discoveryStatus: .discovered,
            resourceStatus: .hasResources,
            dangerLevel: 2,
            description: "街角的药店，柜台后面可能还藏有一些药品和医疗用品。"
        ),
        // 工厂废墟：未发现
        POI(
            id: "poi_005",
            name: "工厂废墟",
            type: .factory,
            coordinate: CLLocationCoordinate2D(latitude: 23.1320, longitude: 113.2590),
            discoveryStatus: .undiscovered,
            resourceStatus: .unknown,
            dangerLevel: 3,
            description: "废弃的工厂建筑群，可能有大量工业材料和工具。"
        )
    ]

    // MARK: - 物品定义假数据

    /// 物品定义表
    /// 记录每种物品的基础属性，用于物品系统
    static let itemDefinitions: [ItemDefinition] = [
        // 水类
        ItemDefinition(
            id: "item_water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            hasQuality: false,
            description: "一瓶干净的矿泉水，可以补充水分。",
            maxStack: 20
        ),
        // 食物
        ItemDefinition(
            id: "item_canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            hasQuality: true,
            description: "密封的罐头食品，保质期较长。",
            maxStack: 15
        ),
        // 医疗 - 绷带
        ItemDefinition(
            id: "item_bandage",
            name: "绷带",
            category: .medical,
            weight: 0.05,
            volume: 0.02,
            rarity: .common,
            hasQuality: true,
            description: "用于包扎伤口的医用绷带。",
            maxStack: 30
        ),
        // 医疗 - 药品
        ItemDefinition(
            id: "item_medicine",
            name: "药品",
            category: .medical,
            weight: 0.1,
            volume: 0.05,
            rarity: .uncommon,
            hasQuality: true,
            description: "各类常用药品，可治疗轻微疾病。",
            maxStack: 20
        ),
        // 材料 - 木材
        ItemDefinition(
            id: "item_wood",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 3.0,
            rarity: .common,
            hasQuality: true,
            description: "可用于建造和修缮的木材。",
            maxStack: 50
        ),
        // 材料 - 废金属
        ItemDefinition(
            id: "item_scrap_metal",
            name: "废金属",
            category: .material,
            weight: 1.5,
            volume: 0.5,
            rarity: .common,
            hasQuality: false,
            description: "从废墟中收集的金属碎片，可用于制作和修理。",
            maxStack: 100
        ),
        // 工具 - 手电筒
        ItemDefinition(
            id: "item_flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            hasQuality: true,
            description: "便携式手电筒，探索黑暗区域的必备工具。",
            maxStack: 1
        ),
        // 工具 - 绳子
        ItemDefinition(
            id: "item_rope",
            name: "绳子",
            category: .tool,
            weight: 0.8,
            volume: 0.5,
            rarity: .common,
            hasQuality: true,
            description: "结实的尼龙绳，用途广泛。",
            maxStack: 10
        )
    ]

    // MARK: - 背包物品假数据

    /// 测试用背包物品列表
    /// 包含6-8种不同类型的物品实例
    static let mockBackpackItems: [BackpackItem] = [
        // 矿泉水 x5
        BackpackItem(
            id: "bp_001",
            itemId: "item_water_bottle",
            quantity: 5,
            quality: nil,  // 矿泉水没有品质区分
            obtainedAt: Date().addingTimeInterval(-3600),
            obtainedFrom: "废弃超市"
        ),
        // 罐头食品 x3（良好品质）
        BackpackItem(
            id: "bp_002",
            itemId: "item_canned_food",
            quantity: 3,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-7200),
            obtainedFrom: "废弃超市"
        ),
        // 绷带 x8（普通品质）
        BackpackItem(
            id: "bp_003",
            itemId: "item_bandage",
            quantity: 8,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-1800),
            obtainedFrom: "药店废墟"
        ),
        // 药品 x2（优秀品质）
        BackpackItem(
            id: "bp_004",
            itemId: "item_medicine",
            quantity: 2,
            quality: .excellent,
            obtainedAt: Date().addingTimeInterval(-1800),
            obtainedFrom: "药店废墟"
        ),
        // 木材 x12（普通品质）
        BackpackItem(
            id: "bp_005",
            itemId: "item_wood",
            quantity: 12,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-5400),
            obtainedFrom: nil
        ),
        // 废金属 x25
        BackpackItem(
            id: "bp_006",
            itemId: "item_scrap_metal",
            quantity: 25,
            quality: nil,  // 废金属没有品质区分
            obtainedAt: Date().addingTimeInterval(-9000),
            obtainedFrom: nil
        ),
        // 手电筒 x1（良好品质）
        BackpackItem(
            id: "bp_007",
            itemId: "item_flashlight",
            quantity: 1,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-86400),
            obtainedFrom: "废弃超市"
        ),
        // 绳子 x3（普通品质）
        BackpackItem(
            id: "bp_008",
            itemId: "item_rope",
            quantity: 3,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-43200),
            obtainedFrom: nil
        )
    ]

    // MARK: - 探索结果假数据

    /// 测试用探索结果
    /// 模拟一次30分钟的探索活动
    static let mockExplorationResult: ExplorationResult = {
        let now = Date()
        let startTime = now.addingTimeInterval(-1800) // 30分钟前

        let stats = ExplorationStats(
            walkDistance: 2500,              // 本次行走 2500 米
            totalWalkDistance: 15000,        // 累计行走 15000 米
            walkDistanceRank: 42,            // 排名第 42
            exploredArea: 50000,             // 本次探索 5 万平方米
            totalExploredArea: 250000,       // 累计探索 25 万平方米
            exploredAreaRank: 38,            // 排名第 38
            duration: 1800,                  // 探索时长 30 分钟
            startTime: startTime,
            endTime: now
        )

        // 本次探索获得的物品
        let loot: [ExplorationLoot] = [
            ExplorationLoot(itemId: "item_wood", quantity: 5, quality: .normal),
            ExplorationLoot(itemId: "item_water_bottle", quantity: 3, quality: nil),
            ExplorationLoot(itemId: "item_canned_food", quantity: 2, quality: .good)
        ]

        return ExplorationResult(
            id: "exp_001",
            userId: "user_test_001",
            stats: stats,
            loot: loot,
            discoveredPOIs: ["poi_003"],    // 新发现了加油站
            visitedPOIs: ["poi_001", "poi_004"]  // 访问了废弃超市和药店废墟
        )
    }()

    // MARK: - 辅助方法

    /// 根据物品ID获取物品定义
    /// - Parameter itemId: 物品ID
    /// - Returns: 物品定义，如果不存在返回nil
    static func getItemDefinition(by itemId: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == itemId }
    }

    /// 根据物品ID获取物品中文名称
    /// - Parameter itemId: 物品ID
    /// - Returns: 物品中文名称，如果不存在返回"未知物品"
    static func getItemName(by itemId: String) -> String {
        return getItemDefinition(by: itemId)?.name ?? "未知物品"
    }

    /// 计算背包总重量
    /// - Parameter items: 背包物品列表
    /// - Returns: 总重量（千克）
    static func calculateTotalWeight(items: [BackpackItem]) -> Double {
        return items.reduce(0) { total, item in
            let definition = getItemDefinition(by: item.itemId)
            let itemWeight = definition?.weight ?? 0
            return total + (itemWeight * Double(item.quantity))
        }
    }

    /// 计算背包总体积
    /// - Parameter items: 背包物品列表
    /// - Returns: 总体积（升）
    static func calculateTotalVolume(items: [BackpackItem]) -> Double {
        return items.reduce(0) { total, item in
            let definition = getItemDefinition(by: item.itemId)
            let itemVolume = definition?.volume ?? 0
            return total + (itemVolume * Double(item.quantity))
        }
    }

    /// 按分类统计背包物品
    /// - Parameter items: 背包物品列表
    /// - Returns: 分类字典，key为分类，value为该分类的物品数组
    static func groupItemsByCategory(items: [BackpackItem]) -> [ItemCategory: [BackpackItem]] {
        var grouped: [ItemCategory: [BackpackItem]] = [:]

        for item in items {
            if let definition = getItemDefinition(by: item.itemId) {
                if grouped[definition.category] == nil {
                    grouped[definition.category] = []
                }
                grouped[definition.category]?.append(item)
            }
        }

        return grouped
    }
}
