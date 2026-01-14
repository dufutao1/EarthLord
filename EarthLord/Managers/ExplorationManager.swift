//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器
//  负责管理探索状态、GPS追踪、距离计算、时长计时
//

import Foundation
import CoreLocation
import Combine
import Supabase

// MARK: - 数据库模型

/// 探索会话插入模型
struct ExplorationSessionInsert: Encodable {
    let user_id: String
    let start_time: String
    let start_lat: Double?
    let start_lng: Double?
    let status: String
}

/// 探索会话更新模型
struct ExplorationSessionUpdate: Encodable {
    let end_time: String
    let duration_seconds: Int
    let total_distance: Double
    let reward_tier: String
    let items_rewarded: String  // JSON字符串
    let status: String
    let end_lat: Double?
    let end_lng: Double?
}

// MARK: - 探索结束原因

/// 探索结束的原因
enum ExplorationEndReason {
    case userStopped      // 用户主动结束
    case speedViolation   // 超速被强制结束
    case cancelled        // 用户取消
}

// MARK: - 探索管理器

/// 探索管理器（单例）
/// 管理探索状态、GPS追踪、距离计算
class ExplorationManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = ExplorationManager()

    // MARK: - 发布的状态

    /// 是否正在探索
    @Published var isExploring: Bool = false

    /// 当前累计行走距离（米）
    @Published var currentDistance: Double = 0

    /// 当前探索时长（秒）
    @Published var currentDuration: TimeInterval = 0

    /// 探索状态文本
    @Published var statusText: String = "准备探索"

    /// 当前位置
    @Published var currentLocation: CLLocation?

    /// 当前速度（km/h）
    @Published var currentSpeed: Double = 0

    /// 是否显示超速警告
    @Published var showSpeedWarning: Bool = false

    /// 超速警告倒计时（秒）
    @Published var speedWarningCountdown: Int = 0

    /// 探索是否因超速失败
    @Published var explorationFailedDueToSpeed: Bool = false

    // MARK: - POI 相关状态

    /// 附近的 POI 列表
    @Published var nearbyPOIs: [SearchedPOI] = []

    /// 是否显示 POI 接近弹窗
    @Published var showPOIPopup: Bool = false

    /// 当前接近的 POI（触发弹窗的）
    @Published var currentProximityPOI: SearchedPOI?

    /// 是否正在加载 POI
    @Published var isLoadingPOIs: Bool = false

    /// 已搜刮的 POI ID 集合
    @Published var scavengedPOIIds: Set<String> = []

    /// 待处理的 POI 队列（用于处理同时在多个围栏内的情况）
    private var pendingPOIQueue: [SearchedPOI] = []

    /// 搜刮结果（用于显示结果视图）
    @Published var scavengeResult: [RewardItem]?

    /// 是否显示搜刮结果
    @Published var showScavengeResult: Bool = false

    /// 搜刮的 POI 名称（用于结果显示）
    @Published var scavengedPOIName: String = ""

    // MARK: - 内部状态

    /// 位置管理器
    private var locationManager: CLLocationManager?

    /// 上一个有效位置（用于计算距离）
    private var lastValidLocation: CLLocation?

    /// 探索开始时间
    private var startTime: Date?

    /// 开始位置
    private var startLocation: CLLocation?

    /// 计时器
    private var durationTimer: Timer?

    /// 超速检测计时器
    private var speedViolationTimer: Timer?

    /// 超速开始时间
    private var speedViolationStartTime: Date?

    /// 当前探索会话ID
    private var currentSessionId: UUID?

    // MARK: - 常量

    /// 最大可接受的水平精度（米）
    private let maxAcceptableAccuracy: CLLocationAccuracy = 50

    /// 最大单次移动距离（米），超过视为GPS跳点
    private let maxSingleMoveDistance: CLLocationDistance = 100

    /// 最小位置更新间隔（秒）
    private let minUpdateInterval: TimeInterval = 1

    /// 最小有效距离（米），低于200米无奖励
    private let minRewardDistance: Double = 200

    /// 最大允许速度（km/h）- 行走/跑步速度上限
    private let maxAllowedSpeedKmh: Double = 30.0

    /// 超速容忍时间（秒）
    private let speedViolationToleranceSeconds: Int = 10

    /// POI 接近触发半径（米）
    private let poiProximityRadius: CLLocationDistance = 50

    /// POI 地理围栏标识符前缀
    private let poiRegionPrefix = "poi_"

    // MARK: - 初始化

    private override init() {
        super.init()
        setupLocationManager()
        log("🚀 ExplorationManager 初始化完成")
    }

    /// 配置位置管理器
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = 5 // 每移动5米更新一次
        locationManager?.allowsBackgroundLocationUpdates = true  // 允许后台定位
        locationManager?.pausesLocationUpdatesAutomatically = false
        log("📍 位置管理器配置完成")
    }

    // MARK: - 日志方法

    /// 日志管理器引用
    private let logger = ExplorationLogger.shared

    /// 打印日志（同时输出到 App 内日志界面和控制台）
    private func log(_ message: String, type: LogType = .info) {
        logger.log(message, type: type)
    }

    // MARK: - 公开方法

    /// 开始探索
    func startExploration() {
        guard !isExploring else {
            log("⚠️ 已经在探索中，忽略重复调用")
            return
        }

        log("🔍 ========== 开始探索 ==========", type: .success)

        // 重置状态
        currentDistance = 0
        currentDuration = 0
        currentSpeed = 0
        lastValidLocation = nil
        startTime = Date()
        currentSessionId = UUID()
        showSpeedWarning = false
        speedWarningCountdown = 0
        explorationFailedDueToSpeed = false
        speedViolationStartTime = nil

        log("📊 状态已重置: 距离=0, 时长=0, 速度=0")

        // 开始位置追踪
        locationManager?.startUpdatingLocation()
        log("📍 开始GPS位置追踪")

        // 启动玩家位置定时上报（每30秒上报一次）
        PlayerLocationManager.shared.startPeriodicReporting { [weak self] in
            return self?.currentLocation?.coordinate
        }
        log("📡 玩家位置定时上报已启动")

        // 开始计时
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
        log("⏱️ 计时器已启动")

        isExploring = true
        statusText = "搜索附近地点..."

        // 重置 POI 状态
        nearbyPOIs = []
        scavengedPOIIds = []
        pendingPOIQueue.removeAll()
        showPOIPopup = false
        currentProximityPOI = nil

        // 创建数据库记录
        Task {
            await createExplorationSession()
        }

        // 搜索附近 POI 并设置地理围栏
        Task {
            await searchAndSetupPOIs()
        }
    }

    /// 结束探索
    /// - Parameter reason: 结束原因
    /// - Returns: 探索结果
    func stopExploration(reason: ExplorationEndReason = .userStopped) async -> ExplorationResult? {
        guard isExploring else {
            log("⚠️ 当前没有进行探索，无法结束")
            return nil
        }

        log("🏁 ========== 结束探索 ==========", type: .success)
        log("📊 结束原因: \(reason)")
        log("📊 最终距离: \(String(format: "%.1f", currentDistance))m")
        log("📊 探索时长: \(String(format: "%.0f", currentDuration))秒")

        // 停止位置追踪
        locationManager?.stopUpdatingLocation()
        log("📍 GPS位置追踪已停止")

        // 停止玩家位置定时上报
        PlayerLocationManager.shared.stopPeriodicReporting()
        log("📡 玩家位置定时上报已停止")

        // 上报最终位置
        if let location = currentLocation?.coordinate {
            await PlayerLocationManager.shared.reportLocation(location)
            log("📡 已上报最终位置")
        }

        // 停止计时
        durationTimer?.invalidate()
        durationTimer = nil
        log("⏱️ 计时器已停止")

        // 停止超速检测计时器
        speedViolationTimer?.invalidate()
        speedViolationTimer = nil

        isExploring = false
        showSpeedWarning = false
        speedWarningCountdown = 0

        // 停止所有 POI 地理围栏监控
        stopAllPOIMonitoring()

        // 清理 POI 状态
        pendingPOIQueue.removeAll()
        await MainActor.run {
            nearbyPOIs = []
            showPOIPopup = false
            currentProximityPOI = nil
        }

        // 根据结束原因处理
        switch reason {
        case .speedViolation:
            log("❌ 探索因超速被强制结束，无奖励")
            explorationFailedDueToSpeed = true
            statusText = "探索失败（超速）"
            await updateSessionStatus(status: "failed_speed")
            return nil

        case .cancelled:
            log("❌ 探索被用户取消，无奖励")
            statusText = "探索已取消"
            await updateSessionStatus(status: "cancelled")
            return nil

        case .userStopped:
            statusText = "探索完成"
            // 生成奖励
            let rewards = RewardGenerator.shared.generateReward(distance: currentDistance)
            let rewardTier = RewardGenerator.shared.calculateTier(distance: currentDistance)

            log("🎁 奖励等级: \(rewardTier.displayName)")
            log("🎁 获得物品: \(rewards.map { "\($0.itemId) x\($0.quantity)" }.joined(separator: ", "))")

            // 构建探索结果
            let result = buildExplorationResult(rewards: rewards, tier: rewardTier)

            // 存入背包并更新数据库
            await saveExplorationData(rewards: rewards, tier: rewardTier)

            return result
        }
    }

    /// 取消探索（不生成奖励）
    func cancelExploration() {
        guard isExploring else { return }

        log("❌ 用户取消探索")

        Task {
            _ = await stopExploration(reason: .cancelled)
        }
    }

    // MARK: - 私有方法

    /// 更新探索时长
    private func updateDuration() {
        guard let startTime = startTime else { return }
        currentDuration = Date().timeIntervalSince(startTime)

        // 更新状态文本
        let minutes = Int(currentDuration) / 60
        let seconds = Int(currentDuration) % 60

        if showSpeedWarning {
            statusText = String(format: "⚠️ 超速警告 %d秒 | %.0fm", speedWarningCountdown, currentDistance)
        } else {
            statusText = String(format: "探索中 %d:%02d | %.0fm | %.1fkm/h", minutes, seconds, currentDistance, currentSpeed)
        }
    }

    /// 处理新的位置更新
    private func processLocationUpdate(_ location: CLLocation) {
        // 检查精度
        guard location.horizontalAccuracy <= maxAcceptableAccuracy else {
            log("📍 忽略低精度位置: 精度=\(String(format: "%.1f", location.horizontalAccuracy))m (阈值: \(maxAcceptableAccuracy)m)")
            return
        }

        // 更新当前位置
        currentLocation = location

        // 计算速度（m/s 转 km/h）
        // 注意：location.speed 可能为负数表示无效，需要处理
        let speedMps = location.speed
        if speedMps >= 0 {
            currentSpeed = speedMps * 3.6 // 转换为 km/h
        }
        // 如果速度无效（<0），保持上一次的速度值

        log("📍 位置更新: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))) 精度=\(String(format: "%.1f", location.horizontalAccuracy))m, 速度=\(String(format: "%.1f", currentSpeed))km/h (原始:\(String(format: "%.1f", speedMps))m/s)")

        // 检查速度是否超限（放在前面，确保每次都检查）
        checkSpeedLimit()

        // 第一个点
        guard let lastLocation = lastValidLocation else {
            lastValidLocation = location
            startLocation = location
            log("📍 记录起始点: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))")
            return
        }

        // 检查时间间隔
        let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
        guard timeInterval >= minUpdateInterval else {
            return
        }

        // 计算距离
        let distance = location.distance(from: lastLocation)

        // 检查是否为GPS跳点
        guard distance <= maxSingleMoveDistance else {
            log("📍 忽略GPS跳点: 距离=\(String(format: "%.1f", distance))m (阈值: \(maxSingleMoveDistance)m)")
            return
        }

        // 累加距离
        currentDistance += distance
        lastValidLocation = location

        log("📍 有效移动: +\(String(format: "%.1f", distance))m → 累计: \(String(format: "%.1f", currentDistance))m")
    }

    /// 检查速度限制
    private func checkSpeedLimit() {
        if currentSpeed > maxAllowedSpeedKmh {
            // 超速了
            if !showSpeedWarning {
                // 第一次检测到超速，开始倒计时
                log("⚠️ 检测到超速! 当前速度: \(String(format: "%.1f", currentSpeed))km/h > \(maxAllowedSpeedKmh)km/h", type: .warning)
                showSpeedWarning = true
                speedViolationStartTime = Date()
                speedWarningCountdown = speedViolationToleranceSeconds

                // 启动超速倒计时
                speedViolationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    self?.updateSpeedViolationCountdown()
                }
            }
        } else {
            // 速度恢复正常
            if showSpeedWarning {
                log("✅ 速度恢复正常: \(String(format: "%.1f", currentSpeed))km/h")
                showSpeedWarning = false
                speedWarningCountdown = 0
                speedViolationStartTime = nil
                speedViolationTimer?.invalidate()
                speedViolationTimer = nil
            }
        }
    }

    /// 更新超速倒计时
    private func updateSpeedViolationCountdown() {
        guard let startTime = speedViolationStartTime else { return }

        let elapsed = Int(Date().timeIntervalSince(startTime))
        speedWarningCountdown = max(0, speedViolationToleranceSeconds - elapsed)

        log("⚠️ 超速倒计时: \(speedWarningCountdown)秒", type: .warning)

        if speedWarningCountdown <= 0 {
            // 倒计时结束，强制停止探索
            log("❌ 超速时间超过\(speedViolationToleranceSeconds)秒，强制结束探索!", type: .error)
            speedViolationTimer?.invalidate()
            speedViolationTimer = nil

            Task {
                _ = await stopExploration(reason: .speedViolation)
            }
        }
    }

    /// 构建探索结果
    private func buildExplorationResult(rewards: [RewardItem], tier: RewardTier) -> ExplorationResult {
        let now = Date()
        let startTimeValue = startTime ?? now

        // 构建统计数据（只保留行走相关的）
        let stats = ExplorationStats(
            walkDistance: currentDistance,
            totalWalkDistance: currentDistance, // TODO: 从数据库获取累计
            walkDistanceRank: 0, // TODO: 从数据库计算排名
            exploredArea: 0,  // 行走探索不计算面积
            totalExploredArea: 0,
            exploredAreaRank: 0,
            duration: currentDuration,
            startTime: startTimeValue,
            endTime: now
        )

        // 转换奖励物品格式
        let loot = rewards.map { reward in
            ExplorationLoot(
                itemId: reward.itemId,
                quantity: reward.quantity,
                quality: nil
            )
        }

        log("📦 构建探索结果: 距离=\(String(format: "%.1f", currentDistance))m, 时长=\(String(format: "%.0f", currentDuration))秒, 物品数=\(loot.count)")

        return ExplorationResult(
            id: currentSessionId?.uuidString ?? UUID().uuidString,
            userId: supabase.auth.currentUser?.id.uuidString ?? "",
            stats: stats,
            loot: loot,
            discoveredPOIs: [],
            visitedPOIs: []
        )
    }

    /// 创建探索会话记录
    private func createExplorationSession() async {
        guard let userId = supabase.auth.currentUser?.id else {
            log("❌ 无法创建数据库会话：用户未登录")
            return
        }

        // ISO8601 时间格式
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let session = ExplorationSessionInsert(
            user_id: userId.uuidString,
            start_time: iso8601Formatter.string(from: startTime ?? Date()),
            start_lat: startLocation?.coordinate.latitude,
            start_lng: startLocation?.coordinate.longitude,
            status: "active"
        )

        do {
            try await supabase
                .from("exploration_sessions")
                .insert(session)
                .execute()

            log("✅ 数据库会话创建成功")
        } catch {
            log("❌ 数据库会话创建失败: \(error.localizedDescription)")
        }
    }

    /// 更新会话状态
    private func updateSessionStatus(status: String) async {
        guard let sessionId = currentSessionId else {
            log("⚠️ 无法更新会话状态：会话ID为空")
            return
        }

        do {
            try await supabase
                .from("exploration_sessions")
                .update(["status": status])
                .eq("id", value: sessionId.uuidString)
                .execute()

            log("✅ 数据库会话状态更新为: \(status)")
        } catch {
            log("❌ 数据库会话状态更新失败: \(error.localizedDescription)")
        }
    }

    /// 保存探索数据（更新会话记录，存入背包）
    private func saveExplorationData(rewards: [RewardItem], tier: RewardTier) async {
        log("💾 开始保存探索数据...")

        // 1. 更新探索会话记录
        if let sessionId = currentSessionId {
            // ISO8601 时间格式
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            // 将奖励转为JSON字符串
            let rewardsJson: String
            do {
                let jsonData = try JSONEncoder().encode(rewards)
                rewardsJson = String(data: jsonData, encoding: .utf8) ?? "[]"
            } catch {
                rewardsJson = "[]"
                log("⚠️ 奖励JSON编码失败: \(error.localizedDescription)")
            }

            let updateData = ExplorationSessionUpdate(
                end_time: iso8601Formatter.string(from: Date()),
                duration_seconds: Int(currentDuration),
                total_distance: currentDistance,
                reward_tier: tier.rawValue,
                items_rewarded: rewardsJson,
                status: "completed",
                end_lat: currentLocation?.coordinate.latitude,
                end_lng: currentLocation?.coordinate.longitude
            )

            do {
                try await supabase
                    .from("exploration_sessions")
                    .update(updateData)
                    .eq("id", value: sessionId.uuidString)
                    .execute()

                log("✅ 数据库探索记录更新成功")
            } catch {
                log("❌ 数据库探索记录更新失败: \(error.localizedDescription)")
            }
        }

        // 2. 将奖励物品存入背包
        log("🎒 开始存入背包，共 \(rewards.count) 个物品...")
        for reward in rewards {
            await InventoryManager.shared.addItem(
                itemId: reward.itemId,
                quantity: reward.quantity
            )
            log("🎒 存入: \(reward.itemId) x\(reward.quantity)")
        }

        log("✅ 探索数据保存完成")
    }

    // MARK: - POI 相关方法

    /// 搜索附近 POI 并设置地理围栏
    @MainActor
    private func searchAndSetupPOIs() async {
        guard let location = currentLocation?.coordinate ?? startLocation?.coordinate else {
            log("⚠️ 无法搜索 POI：没有位置信息，2秒后重试...")
            // 等待位置更新后再尝试
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                Task {
                    await self?.searchAndSetupPOIs()
                }
            }
            return
        }

        isLoadingPOIs = true
        log("🔍 ========== 开始搜索附近 POI ==========")
        log("🔍 搜索中心点(GCJ-02): (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))")

        // 1. 上报当前位置（确保自己被计入在线玩家）
        log("📡 上报当前位置...")
        await PlayerLocationManager.shared.reportLocation(location)

        // 2. 查询附近玩家数量
        log("👥 查询附近玩家...")
        let playerCount = await PlayerLocationManager.shared.countNearbyPlayers(around: location)
        let density = PlayerLocationManager.DensityLevel.from(playerCount: playerCount)
        log("👥 附近玩家: \(playerCount) 人 (\(density.rawValue))")

        // 3. 根据密度计算 POI 数量上限
        let maxPOIs = PlayerLocationManager.shared.calculatePOILimit(playerCount: playerCount)
        log("📍 根据密度建议 POI 数量: \(maxPOIs)")

        // 4. 搜索 POI（返回的坐标是 GCJ-02）
        let pois = await POISearchManager.shared.searchNearbyPOIs(around: location, maxResults: maxPOIs)

        // 更新列表
        nearbyPOIs = pois
        isLoadingPOIs = false

        log("📍 找到 \(pois.count) 个 POI，开始设置地理围栏...")

        // 为每个 POI 设置地理围栏
        // ⚠️ 关键：POI 坐标是 GCJ-02，但系统围栏用 WGS-84 判断
        // 所以需要把 POI 坐标转换为 WGS-84
        var successCount = 0
        for poi in pois {
            if startPOIMonitoring(for: poi) {
                successCount += 1
            }
        }

        statusText = "探索中..."
        log("✅ POI 搜索完成，成功设置 \(successCount)/\(pois.count) 个地理围栏", type: .success)
    }

    /// 开始监控单个 POI 的地理围栏
    /// - Returns: 是否成功设置
    private func startPOIMonitoring(for poi: SearchedPOI) -> Bool {
        // ⚠️ 关键修复：POI 坐标是 GCJ-02，系统用 WGS-84 判断用户位置
        // 必须把 POI 坐标从 GCJ-02 转换为 WGS-84，围栏才会在正确位置触发
        let wgs84Coordinate = CoordinateConverter.gcj02ToWgs84(poi.coordinate)

        log("🎯 设置围栏: \(poi.name)")
        log("   GCJ-02: (\(String(format: "%.6f", poi.coordinate.latitude)), \(String(format: "%.6f", poi.coordinate.longitude)))")
        log("   WGS-84: (\(String(format: "%.6f", wgs84Coordinate.latitude)), \(String(format: "%.6f", wgs84Coordinate.longitude)))")

        let region = CLCircularRegion(
            center: wgs84Coordinate,  // 使用转换后的 WGS-84 坐标
            radius: poiProximityRadius,
            identifier: "\(poiRegionPrefix)\(poi.id)"
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false

        locationManager?.startMonitoring(for: region)
        return true
    }

    /// 停止所有 POI 地理围栏监控
    private func stopAllPOIMonitoring() {
        guard let manager = locationManager else { return }

        var count = 0
        for region in manager.monitoredRegions {
            if region.identifier.hasPrefix(poiRegionPrefix) {
                manager.stopMonitoring(for: region)
                count += 1
            }
        }

        log("🛑 已停止 \(count) 个 POI 围栏监控")
    }

    /// 处理进入 POI 范围（地理围栏回调）
    private func handlePOIEntry(poiId: String) {
        // 移除前缀获取真实 ID
        let realId = String(poiId.dropFirst(poiRegionPrefix.count))

        log("🎯 ========== 进入围栏 ==========")
        log("🎯 围栏ID: \(poiId)")
        log("🎯 POI ID: \(realId)")

        // 查找对应的 POI
        guard let poi = nearbyPOIs.first(where: { $0.id == realId }) else {
            log("⚠️ 未找到对应的 POI，可能已被移除")
            return
        }

        log("🎯 POI 名称: \(poi.name)")

        // 检查是否已搜刮
        if scavengedPOIIds.contains(poi.id) {
            log("ℹ️ 该 POI 已搜刮过，跳过")
            return
        }

        // 检查是否已在队列中
        if pendingPOIQueue.contains(where: { $0.id == poi.id }) {
            log("ℹ️ 该 POI 已在队列中，跳过")
            return
        }

        // 如果已有弹窗显示，加入队列等待
        if showPOIPopup {
            log("ℹ️ 已有弹窗显示，加入队列等待: \(poi.name)")
            pendingPOIQueue.append(poi)
            log("📋 当前队列: \(pendingPOIQueue.count) 个待处理")
            return
        }

        log("🏪 触发搜刮弹窗: \(poi.name)", type: .success)

        // 显示弹窗
        DispatchQueue.main.async { [weak self] in
            self?.currentProximityPOI = poi
            self?.showPOIPopup = true
        }
    }

    /// 显示队列中的下一个 POI 弹窗
    private func showNextPOIPopup() {
        // 从队列中取出下一个未搜刮的 POI
        while !pendingPOIQueue.isEmpty {
            let nextPOI = pendingPOIQueue.removeFirst()

            // 跳过已搜刮的
            if scavengedPOIIds.contains(nextPOI.id) {
                log("📋 队列中的 \(nextPOI.name) 已搜刮，跳过")
                continue
            }

            log("📋 从队列取出下一个 POI: \(nextPOI.name)")
            log("📋 剩余队列: \(pendingPOIQueue.count) 个")

            DispatchQueue.main.async { [weak self] in
                self?.currentProximityPOI = nextPOI
                self?.showPOIPopup = true
            }
            return
        }

        log("📋 队列已清空，无更多 POI")
    }

    /// 搜刮当前 POI
    @MainActor
    func scavengePOI() async {
        guard let poi = currentProximityPOI else {
            log("⚠️ 没有可搜刮的 POI")
            return
        }

        log("🔎 开始搜刮: \(poi.name)")

        // 关闭弹窗
        showPOIPopup = false

        // 生成随机物品（1-3件）
        let itemCount = Int.random(in: 1...3)
        var rewards: [RewardItem] = []

        // 从物品定义中随机选择
        let definitions = Array(InventoryManager.shared.itemDefinitions.values)
        guard !definitions.isEmpty else {
            log("⚠️ 物品定义为空，无法生成奖励")
            return
        }

        for _ in 0..<itemCount {
            let randomItem = definitions.randomElement()!
            let quantity = Int.random(in: 1...3)
            // 根据物品稀有度设置
            let rarity: ItemRarityLevel
            switch randomItem.rarity {
            case "epic": rarity = .epic
            case "rare": rarity = .rare
            default: rarity = .common
            }
            rewards.append(RewardItem(itemId: randomItem.id, quantity: quantity, rarity: rarity))
        }

        // 合并相同物品（保留稀有度信息）
        var mergedRewards: [String: (quantity: Int, rarity: ItemRarityLevel)] = [:]
        for reward in rewards {
            if let existing = mergedRewards[reward.itemId] {
                mergedRewards[reward.itemId] = (existing.quantity + reward.quantity, existing.rarity)
            } else {
                mergedRewards[reward.itemId] = (reward.quantity, reward.rarity)
            }
        }
        let finalRewards = mergedRewards.map { RewardItem(itemId: $0.key, quantity: $0.value.quantity, rarity: $0.value.rarity) }

        log("🎁 生成 \(finalRewards.count) 种物品")

        // 存入背包
        for reward in finalRewards {
            await InventoryManager.shared.addItem(itemId: reward.itemId, quantity: reward.quantity)
            log("🎒 存入: \(reward.itemId) x\(reward.quantity)")
        }

        // 标记为已搜刮
        scavengedPOIIds.insert(poi.id)

        // 更新 POI 列表中的状态
        if let index = nearbyPOIs.firstIndex(where: { $0.id == poi.id }) {
            nearbyPOIs[index].isScavenged = true
        }

        // 保存搜刮结果用于显示
        scavengeResult = finalRewards
        scavengedPOIName = poi.name

        // 清除当前 POI
        currentProximityPOI = nil

        // 显示结果视图
        showScavengeResult = true

        log("✅ 搜刮完成: \(poi.name)", type: .success)
    }

    /// 关闭 POI 弹窗（稍后再说）
    @MainActor
    func dismissPOIPopup() {
        log("👋 用户选择稍后搜刮: \(currentProximityPOI?.name ?? "未知")")
        showPOIPopup = false
        currentProximityPOI = nil

        // 显示队列中的下一个 POI
        showNextPOIPopup()
    }

    /// 关闭搜刮结果视图
    @MainActor
    func dismissScavengeResult() {
        showScavengeResult = false
        scavengeResult = nil

        // 搜刮结果关闭后，显示队列中的下一个 POI
        showNextPOIPopup()
    }
}

// MARK: - CLLocationManagerDelegate

extension ExplorationManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isExploring else { return }

        for location in locations {
            processLocationUpdate(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        log("❌ GPS位置更新失败: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            log("📍 位置权限: 始终允许")
        case .authorizedWhenInUse:
            log("📍 位置权限: 使用时允许")
        case .denied:
            log("⚠️ 位置权限: 被拒绝")
        case .restricted:
            log("⚠️ 位置权限: 受限")
        case .notDetermined:
            log("📍 位置权限: 未确定，请求授权...")
            manager.requestWhenInUseAuthorization()
        @unknown default:
            log("📍 位置权限: 未知状态")
        }
    }

    // MARK: - 地理围栏回调

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        log("🎯 [围栏回调] 进入区域: \(region.identifier)")

        guard isExploring else {
            log("⚠️ 当前未在探索状态，忽略围栏事件")
            return
        }

        // 检查是否是 POI 围栏
        if region.identifier.hasPrefix(poiRegionPrefix) {
            handlePOIEntry(poiId: region.identifier)
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        log("🎯 [围栏回调] 离开区域: \(region.identifier)")
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        log("✅ [围栏] 开始监控: \(region.identifier)")

        // 立即检查用户是否已在围栏内
        manager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        let stateStr: String
        switch state {
        case .inside: stateStr = "在内部"
        case .outside: stateStr = "在外部"
        case .unknown: stateStr = "未知"
        }
        log("🎯 [围栏状态] \(region.identifier): \(stateStr)")

        // 如果用户已经在围栏内，触发进入事件
        if state == .inside && isExploring && region.identifier.hasPrefix(poiRegionPrefix) {
            log("🎯 用户已在围栏内，触发进入事件")
            handlePOIEntry(poiId: region.identifier)
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        log("❌ [围栏] 监控失败: \(region?.identifier ?? "unknown") - \(error.localizedDescription)")
    }
}
