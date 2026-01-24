//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI 物品生成器
//  调用 Supabase Edge Function 生成独特的搜刮物品
//

import Foundation
import Combine
import Supabase

// MARK: - AI 生成的物品

/// AI 生成的物品
struct AIGeneratedItem: Codable, Identifiable {
    let id: UUID
    let name: String
    let category: String
    let rarity: String
    let story: String

    init(name: String, category: String, rarity: String, story: String) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.rarity = rarity
        self.story = story
    }

    /// 稀有度显示名称
    var rarityDisplayName: String {
        switch rarity {
        case "legendary": return "传奇"
        case "epic": return "史诗"
        case "rare": return "稀有"
        case "uncommon": return "优秀"
        default: return "普通"
        }
    }

    /// 稀有度颜色名称（用于 UI）
    var rarityColorName: String {
        switch rarity {
        case "legendary": return "yellow"
        case "epic": return "purple"
        case "rare": return "blue"
        case "uncommon": return "green"
        default: return "gray"
        }
    }

    /// 物品图标
    var icon: String {
        switch category {
        case "医疗": return "cross.case.fill"
        case "食物": return "takeoutbag.and.cup.and.straw.fill"
        case "工具": return "wrench.and.screwdriver.fill"
        case "武器": return "shield.fill"
        case "材料": return "shippingbox.fill"
        default: return "questionmark.circle.fill"
        }
    }
}

// MARK: - 请求/响应模型

/// 请求中的 POI 信息
private struct POIInfo: Codable {
    let name: String
    let type: String
    let dangerLevel: Int
}

/// 生成请求
private struct GenerateRequest: Codable {
    let poi: POIInfo
    let itemCount: Int
}

/// 生成响应
private struct GenerateResponse: Codable {
    let success: Bool
    let items: [AIGeneratedItemDTO]?
    let error: String?
}

/// AI 返回的物品 DTO
private struct AIGeneratedItemDTO: Codable {
    let name: String
    let category: String
    let rarity: String
    let story: String
}

// MARK: - AI 物品生成器

/// AI 物品生成器（单例）
@MainActor
final class AIItemGenerator: ObservableObject {

    // MARK: - 单例

    static let shared = AIItemGenerator()

    // MARK: - 状态

    /// 是否正在生成
    @Published var isGenerating: Bool = false

    /// 最后一次错误
    @Published var lastError: String?

    // MARK: - 日志

    private let logger = ExplorationLogger.shared

    private func log(_ message: String, type: LogType = .info) {
        logger.log("[AI生成] \(message)", type: type)
        print("🤖 [AIItemGenerator] \(message)")
    }

    // MARK: - 初始化

    private init() {
        log("AIItemGenerator 初始化完成")
    }

    // MARK: - 公开方法

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: 搜刮的 POI
    ///   - count: 生成数量（默认 3）
    /// - Returns: 生成的物品列表，失败返回 nil
    func generateItems(for poi: SearchedPOI, count: Int = 3) async -> [AIGeneratedItem]? {
        isGenerating = true
        lastError = nil

        log("开始为 \(poi.name) 生成 \(count) 个物品...")

        // 获取危险等级
        let dangerLevel = poi.category.dangerLevel

        let request = GenerateRequest(
            poi: POIInfo(
                name: poi.name,
                type: poi.category.rawValue,
                dangerLevel: dangerLevel
            ),
            itemCount: count
        )

        do {
            // 调用 Edge Function
            let response: GenerateResponse = try await supabase.functions
                .invoke("generate-ai-item", options: .init(body: request))

            isGenerating = false

            if response.success, let items = response.items {
                let generatedItems = items.map { dto in
                    AIGeneratedItem(
                        name: dto.name,
                        category: dto.category,
                        rarity: dto.rarity,
                        story: dto.story
                    )
                }

                log("成功生成 \(generatedItems.count) 个物品", type: .success)
                for item in generatedItems {
                    log("  - [\(item.rarityDisplayName)] \(item.name)")
                }

                return generatedItems
            } else {
                let errorMsg = response.error ?? "未知错误"
                log("AI 生成失败: \(errorMsg)", type: .error)
                lastError = errorMsg
                return nil
            }

        } catch {
            isGenerating = false
            log("调用 Edge Function 失败: \(error.localizedDescription)", type: .error)
            lastError = error.localizedDescription
            return nil
        }
    }

    /// 生成降级物品（当 AI 服务不可用时使用）
    /// - Parameters:
    ///   - poi: 搜刮的 POI
    ///   - count: 生成数量
    /// - Returns: 预设物品列表
    func generateFallbackItems(for poi: SearchedPOI, count: Int = 3) -> [AIGeneratedItem] {
        log("使用降级方案生成物品", type: .warning)

        let fallbackItems: [(name: String, category: String, rarity: String, story: String)] = [
            ("过期的能量棒", "食物", "common", "包装已经破损，但里面的能量棒看起来还能吃..."),
            ("旧绷带", "医疗", "common", "有些发黄，但总比没有强。"),
            ("生锈的螺丝刀", "工具", "common", "虽然旧了，但还能用。"),
            ("半瓶矿泉水", "食物", "uncommon", "水还是清澈的，应该没问题。"),
            ("止痛药", "医疗", "uncommon", "还在保质期内，真是幸运。"),
            ("手电筒", "工具", "rare", "电池还有电，在黑暗中这就是希望。"),
        ]

        var result: [AIGeneratedItem] = []
        for _ in 0..<count {
            if let item = fallbackItems.randomElement() {
                result.append(AIGeneratedItem(
                    name: item.name,
                    category: item.category,
                    rarity: item.rarity,
                    story: item.story
                ))
            }
        }

        return result
    }
}
