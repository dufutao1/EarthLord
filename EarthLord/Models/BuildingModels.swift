//
//  BuildingModels.swift
//  EarthLord
//
//  建造系统数据模型
//  包含建筑分类、状态、模板和玩家建筑
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - 建筑分类

/// 建筑分类枚举
enum BuildingCategory: String, Codable, CaseIterable {
    case survival = "survival"       // 生存
    case storage = "storage"         // 储存
    case production = "production"   // 生产
    case energy = "energy"           // 能源

    /// 显示名称
    var displayName: String {
        switch self {
        case .survival: return "生存"
        case .storage: return "储存"
        case .production: return "生产"
        case .energy: return "能源"
        }
    }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .survival: return "house.fill"
        case .storage: return "archivebox.fill"
        case .production: return "hammer.fill"
        case .energy: return "bolt.fill"
        }
    }

    /// 分类颜色
    var color: Color {
        switch self {
        case .survival: return .orange
        case .storage: return .brown
        case .production: return .green
        case .energy: return .yellow
        }
    }
}

// MARK: - 建筑状态（状态机）

/// 建筑状态枚举
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case active = "active"              // 运行中

    /// 显示名称
    var displayName: String {
        switch self {
        case .constructing: return "建造中"
        case .active: return "运行中"
        }
    }

    /// 状态颜色
    var color: Color {
        switch self {
        case .constructing: return .blue
        case .active: return .green
        }
    }
}

// MARK: - 建筑模板

/// 建筑模板（定义可建造的建筑类型）
struct BuildingTemplate: Codable, Identifiable {
    let id: UUID
    let templateId: String          // 模板ID，如 "campfire"
    let name: String                // 显示名称，如 "篝火"
    let category: BuildingCategory  // 分类
    let tier: Int                   // 等级：1/2/3
    let description: String         // 描述文字
    let icon: String                // SF Symbol 图标名
    let requiredResources: [String: Int]  // 所需资源，如 {"wood": 30, "stone": 20}
    let buildTimeSeconds: Int       // 建造时间（秒）
    let maxPerTerritory: Int        // 每个领地最多建几个
    let maxLevel: Int               // 最高可升级到几级

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case name, category, tier, description, icon
        case requiredResources = "required_resources"
        case buildTimeSeconds = "build_time_seconds"
        case maxPerTerritory = "max_per_territory"
        case maxLevel = "max_level"
    }
}

/// JSON 文件包装结构
struct BuildingTemplatesData: Codable {
    let version: String
    let templates: [BuildingTemplate]
}

// MARK: - 玩家建筑

/// 玩家建筑（记录玩家已建造的建筑）
struct PlayerBuilding: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    var status: BuildingStatus
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date
    var buildCompletedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status, level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 初始化方法（用于创建新建筑）
    init(
        id: UUID = UUID(),
        userId: UUID,
        territoryId: String,
        templateId: String,
        buildingName: String,
        status: BuildingStatus = .constructing,
        level: Int = 1,
        locationLat: Double? = nil,
        locationLon: Double? = nil,
        buildStartedAt: Date = Date(),
        buildCompletedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.territoryId = territoryId
        self.templateId = templateId
        self.buildingName = buildingName
        self.status = status
        self.level = level
        self.locationLat = locationLat
        self.locationLon = locationLon
        self.buildStartedAt = buildStartedAt
        self.buildCompletedAt = buildCompletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 建筑错误

/// 建造相关错误
enum BuildingError: LocalizedError {
    case insufficientResources([String: Int])  // 资源不足，附带缺少的资源
    case maxBuildingsReached(Int)              // 达到上限
    case templateNotFound                       // 模板不存在
    case invalidStatus                          // 状态不对（如建造中不能升级）
    case maxLevelReached                        // 已达最大等级
    case notAuthenticated                       // 未登录
    case databaseError(String)                  // 数据库错误

    var errorDescription: String? {
        switch self {
        case .insufficientResources(let missing):
            let items = missing.map { "\($0.key) ×\($0.value)" }.joined(separator: ", ")
            return "资源不足，还需要: \(items)"
        case .maxBuildingsReached(let max):
            return "该建筑已达上限（最多 \(max) 个）"
        case .templateNotFound:
            return "找不到建筑模板"
        case .invalidStatus:
            return "只能升级运行中的建筑"
        case .maxLevelReached:
            return "建筑已达最高等级"
        case .notAuthenticated:
            return "请先登录"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        }
    }
}

// MARK: - 建筑模板扩展

extension BuildingTemplate {
    /// 获取资源需求的显示文本
    func resourcesText() -> String {
        requiredResources.map { "\($0.key) ×\($0.value)" }.joined(separator: ", ")
    }

    /// 获取建造时间的显示文本
    func buildTimeText() -> String {
        if buildTimeSeconds < 60 {
            return "\(buildTimeSeconds)秒"
        } else {
            let minutes = buildTimeSeconds / 60
            let seconds = buildTimeSeconds % 60
            if seconds == 0 {
                return "\(minutes)分钟"
            } else {
                return "\(minutes)分\(seconds)秒"
            }
        }
    }

    /// Tier 显示文本
    var tierText: String {
        switch tier {
        case 1: return "Tier 1 · 基础"
        case 2: return "Tier 2 · 进阶"
        case 3: return "Tier 3 · 高级"
        default: return "Tier \(tier)"
        }
    }
}

// MARK: - 玩家建筑扩展

extension PlayerBuilding {
    /// 获取建筑坐标
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lon = locationLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// 获取建筑模板（需要在主线程调用）
    @MainActor
    var template: BuildingTemplate? {
        BuildingManager.shared.getTemplate(for: templateId)
    }

    /// 计算剩余建造时间（秒）
    func remainingBuildTime() -> TimeInterval {
        guard let completedAt = buildCompletedAt else { return 0 }
        return max(0, completedAt.timeIntervalSinceNow)
    }

    /// 剩余时间显示文本
    func remainingTimeText() -> String {
        let remaining = Int(remainingBuildTime())
        if remaining <= 0 {
            return "即将完成"
        } else if remaining < 60 {
            return "\(remaining)秒"
        } else {
            let minutes = remaining / 60
            let seconds = remaining % 60
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
    }

    /// 建造进度（0.0 ~ 1.0）
    func buildProgress() -> Double {
        guard let completedAt = buildCompletedAt else { return 1.0 }
        let totalTime = completedAt.timeIntervalSince(buildStartedAt)
        let elapsed = Date().timeIntervalSince(buildStartedAt)
        return min(1.0, max(0.0, elapsed / totalTime))
    }
}
