//
//  BuildingManager.swift
//  EarthLord
//
//  建筑管理器
//  负责建筑模板加载、建造、升级等核心业务逻辑
//

import Foundation
import Combine
import Supabase
import CoreLocation

// MARK: - 建筑管理器

/// 建筑管理器（单例）
/// 管理建筑的建造、升级、查询等操作
@MainActor
class BuildingManager: ObservableObject {

    // MARK: - 单例

    static let shared = BuildingManager()

    // MARK: - 发布的状态

    /// 所有建筑模板
    @Published var buildingTemplates: [BuildingTemplate] = []

    /// 当前领地的建筑列表
    @Published var playerBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// 建造计时器
    private var buildingTimers: [UUID: Timer] = [:]

    // MARK: - 初始化

    private init() {
        loadTemplates()
    }

    // MARK: - 模板加载

    /// 从 JSON 文件加载建筑模板
    func loadTemplates() {
        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("❌ [BuildingManager] 找不到 building_templates.json")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let templatesData = try decoder.decode(BuildingTemplatesData.self, from: data)
            self.buildingTemplates = templatesData.templates
            print("✅ [BuildingManager] 成功加载 \(templatesData.templates.count) 个建筑模板")
        } catch {
            print("❌ [BuildingManager] 解析模板失败: \(error)")
        }
    }

    // MARK: - 建造检查

    /// 检查是否可以建造
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地ID
    ///   - playerResources: 玩家拥有的资源
    /// - Returns: 是否可以建造，以及错误原因
    func canBuild(
        template: BuildingTemplate,
        territoryId: String,
        playerResources: [String: Int]
    ) -> (canBuild: Bool, error: BuildingError?) {

        // 1. 检查资源是否足够
        var insufficientResources: [String: Int] = [:]
        for (resource, required) in template.requiredResources {
            let available = playerResources[resource] ?? 0
            if available < required {
                insufficientResources[resource] = required - available
            }
        }
        if !insufficientResources.isEmpty {
            return (false, .insufficientResources(insufficientResources))
        }

        // 2. 检查数量是否达到上限
        let existingCount = playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == template.templateId
        }.count
        if existingCount >= template.maxPerTerritory {
            return (false, .maxBuildingsReached(template.maxPerTerritory))
        }

        // 3. 全部通过
        return (true, nil)
    }

    // MARK: - 开始建造

    /// 开始建造建筑
    /// - Parameters:
    ///   - templateId: 模板ID
    ///   - territoryId: 领地ID
    ///   - location: 建筑位置（可选）
    /// - Returns: 建造结果
    func startConstruction(
        templateId: String,
        territoryId: String,
        location: CLLocationCoordinate2D? = nil
    ) async -> Result<PlayerBuilding, BuildingError> {

        // 1. 检查登录状态
        guard let userId = supabase.auth.currentUser?.id else {
            return .failure(.notAuthenticated)
        }

        // 2. 查找模板
        guard let template = buildingTemplates.first(where: { $0.templateId == templateId }) else {
            return .failure(.templateNotFound)
        }

        // 3. 扣除资源
        for (resourceId, amount) in template.requiredResources {
            await InventoryManager.shared.removeItem(itemId: resourceId, quantity: amount)
        }

        // 4. 创建建筑记录
        let now = Date()
        let completedAt = now.addingTimeInterval(Double(template.buildTimeSeconds))

        let newBuilding = PlayerBuilding(
            id: UUID(),
            userId: userId,
            territoryId: territoryId,
            templateId: templateId,
            buildingName: template.name,
            status: .constructing,
            level: 1,
            locationLat: location?.latitude,
            locationLon: location?.longitude,
            buildStartedAt: now,
            buildCompletedAt: completedAt,
            createdAt: now,
            updatedAt: now
        )

        // 5. 插入数据库
        do {
            let insertData: [String: AnyJSON] = [
                "id": .string(newBuilding.id.uuidString),
                "user_id": .string(userId.uuidString),
                "territory_id": .string(territoryId),
                "template_id": .string(templateId),
                "building_name": .string(template.name),
                "status": .string(BuildingStatus.constructing.rawValue),
                "level": .integer(1),
                "location_lat": location != nil ? .double(location!.latitude) : .null,
                "location_lon": location != nil ? .double(location!.longitude) : .null,
                "build_started_at": .string(ISO8601DateFormatter().string(from: now)),
                "build_completed_at": .string(ISO8601DateFormatter().string(from: completedAt))
            ]

            try await supabase
                .from("player_buildings")
                .insert(insertData)
                .execute()

            // 更新本地状态
            playerBuildings.append(newBuilding)

            // 6. 启动倒计时
            startBuildingTimer(building: newBuilding)

            print("✅ [BuildingManager] 开始建造: \(template.name)")
            return .success(newBuilding)

        } catch {
            print("❌ [BuildingManager] 创建建筑失败: \(error)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }

    // MARK: - 完成建造

    /// 完成建造（将状态更新为 active）
    /// - Parameter buildingId: 建筑ID
    func completeConstruction(buildingId: UUID) async {
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            print("⚠️ [BuildingManager] 找不到建筑: \(buildingId)")
            return
        }

        do {
            try await supabase
                .from("player_buildings")
                .update(["status": BuildingStatus.active.rawValue])
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 更新本地状态
            playerBuildings[index].status = .active

            // 移除计时器
            buildingTimers[buildingId]?.invalidate()
            buildingTimers.removeValue(forKey: buildingId)

            print("✅ [BuildingManager] 建造完成: \(playerBuildings[index].buildingName)")
        } catch {
            print("❌ [BuildingManager] 更新状态失败: \(error)")
        }
    }

    // MARK: - 升级建筑

    /// 升级建筑
    /// - Parameter buildingId: 建筑ID
    /// - Returns: 升级结果
    func upgradeBuilding(buildingId: UUID) async -> Result<PlayerBuilding, BuildingError> {
        // 1. 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            return .failure(.templateNotFound)
        }

        let building = playerBuildings[index]

        // 2. 检查状态：只有 active 才能升级
        guard building.status == .active else {
            return .failure(.invalidStatus)
        }

        // 3. 检查是否已达最大等级
        guard let template = buildingTemplates.first(where: { $0.templateId == building.templateId }),
              building.level < template.maxLevel else {
            return .failure(.maxLevelReached)
        }

        let newLevel = building.level + 1

        // 4. 更新数据库
        do {
            try await supabase
                .from("player_buildings")
                .update(["level": newLevel])
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 更新本地状态
            playerBuildings[index].level = newLevel

            print("✅ [BuildingManager] 升级成功: \(building.buildingName) Lv.\(newLevel)")
            return .success(playerBuildings[index])
        } catch {
            print("❌ [BuildingManager] 升级失败: \(error)")
            return .failure(.databaseError(error.localizedDescription))
        }
    }

    // MARK: - 拆除建筑

    /// 拆除建筑
    /// - Parameter buildingId: 建筑ID
    /// - Returns: 是否拆除成功
    func demolishBuilding(buildingId: UUID) async -> Bool {
        // 1. 查找建筑
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            print("⚠️ [BuildingManager] 找不到建筑: \(buildingId)")
            return false
        }

        let building = playerBuildings[index]

        // 2. 删除数据库记录
        do {
            try await supabase
                .from("player_buildings")
                .delete()
                .eq("id", value: buildingId.uuidString)
                .execute()

            // 3. 更新本地状态
            playerBuildings.remove(at: index)

            // 4. 移除计时器（如果有）
            buildingTimers[buildingId]?.invalidate()
            buildingTimers.removeValue(forKey: buildingId)

            print("✅ [BuildingManager] 拆除成功: \(building.buildingName)")
            return true
        } catch {
            print("❌ [BuildingManager] 拆除失败: \(error)")
            return false
        }
    }

    // MARK: - 获取建筑列表

    /// 获取指定领地的建筑列表
    /// - Parameter territoryId: 领地ID
    func fetchPlayerBuildings(territoryId: String) async {
        guard let userId = supabase.auth.currentUser?.id else {
            print("⚠️ [BuildingManager] 用户未登录")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let buildings: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("territory_id", value: territoryId)
                .execute()
                .value

            self.playerBuildings = buildings

            // 恢复进行中的建造计时器
            for building in buildings where building.status == .constructing {
                startBuildingTimer(building: building)
            }

            print("✅ [BuildingManager] 加载了 \(buildings.count) 个建筑")
        } catch {
            print("❌ [BuildingManager] 加载建筑失败: \(error)")
            self.errorMessage = "加载建筑失败"
        }

        isLoading = false
    }

    // MARK: - 辅助方法

    /// 获取指定模板
    func getTemplate(for templateId: String) -> BuildingTemplate? {
        buildingTemplates.first { $0.templateId == templateId }
    }

    /// 按分类获取模板列表
    func getTemplatesByCategory(_ category: BuildingCategory) -> [BuildingTemplate] {
        buildingTemplates.filter { $0.category == category }
    }

    /// 按 Tier 获取模板列表
    func getTemplatesByTier(_ tier: Int) -> [BuildingTemplate] {
        buildingTemplates.filter { $0.tier == tier }
    }

    /// 获取剩余建造时间
    func getRemainingBuildTime(for building: PlayerBuilding) -> TimeInterval {
        guard let completedAt = building.buildCompletedAt else { return 0 }
        return max(0, completedAt.timeIntervalSinceNow)
    }

    /// 检查建造是否已完成
    func isBuildingComplete(_ building: PlayerBuilding) -> Bool {
        guard let completedAt = building.buildCompletedAt else { return true }
        return Date() >= completedAt
    }

    // MARK: - 私有方法

    /// 启动建造计时器
    private func startBuildingTimer(building: PlayerBuilding) {
        guard let completedAt = building.buildCompletedAt else { return }

        let remaining = completedAt.timeIntervalSinceNow
        if remaining <= 0 {
            // 已经完成，立即更新
            Task {
                await completeConstruction(buildingId: building.id)
            }
            return
        }

        // 设置定时器
        let timer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.completeConstruction(buildingId: building.id)
            }
        }
        buildingTimers[building.id] = timer

        print("⏱️ [BuildingManager] 设置建造计时器: \(building.buildingName), 剩余 \(Int(remaining)) 秒")
    }

    /// 取消所有计时器
    func cancelAllTimers() {
        for (_, timer) in buildingTimers {
            timer.invalidate()
        }
        buildingTimers.removeAll()
        print("🛑 [BuildingManager] 已取消所有建造计时器")
    }
}

// MARK: - 便捷扩展

extension BuildingManager {

    /// 获取玩家当前资源（从 InventoryManager）
    func getPlayerResources() -> [String: Int] {
        var resources: [String: Int] = [:]
        for item in InventoryManager.shared.items {
            resources[item.item_id] = item.quantity
        }
        return resources
    }

    /// 快速检查是否可以建造某个模板
    func canBuildTemplate(_ templateId: String, in territoryId: String) -> (canBuild: Bool, error: BuildingError?) {
        guard let template = getTemplate(for: templateId) else {
            return (false, .templateNotFound)
        }
        let resources = getPlayerResources()
        return canBuild(template: template, territoryId: territoryId, playerResources: resources)
    }
}
