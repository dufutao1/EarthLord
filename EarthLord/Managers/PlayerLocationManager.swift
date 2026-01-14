//
//  PlayerLocationManager.swift
//  EarthLord
//
//  玩家位置管理器
//  负责：
//  1. 定期上报位置到服务器（每30秒 / 移动50米）
//  2. 查询附近在线玩家数量
//  3. 根据玩家密度计算 POI 显示建议
//  4. 管理在线/离线状态
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 玩家位置管理器
@MainActor
final class PlayerLocationManager: ObservableObject {

    // MARK: - 单例

    static let shared = PlayerLocationManager()

    // MARK: - 常量

    /// 位置上报间隔（秒）
    private let reportInterval: TimeInterval = 30

    /// 显著移动距离（米）- 移动超过此距离立即上报
    private let significantDistance: Double = 50

    /// 搜索半径（米）- 查询附近玩家的范围
    private let searchRadius: Double = 1000

    /// 在线超时时间（分钟）- 超过此时间未上报视为离线
    private let onlineTimeout: Int = 5

    // MARK: - Published 属性

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 是否在线
    @Published var isOnline: Bool = false

    /// 最后上报时间
    @Published var lastReportTime: Date?

    /// 上报状态消息（用于调试）
    @Published var statusMessage: String = ""

    // MARK: - 私有属性

    /// 定时上报定时器
    private var reportTimer: Timer?

    /// 上次上报的位置
    private var lastReportedLocation: CLLocationCoordinate2D?

    /// 探索日志记录器
    private let logger = ExplorationLogger.shared

    // MARK: - 密度等级

    /// 玩家密度等级
    enum DensityLevel: String {
        case alone = "独行者"      // 0人
        case low = "低密度"        // 1-5人
        case medium = "中密度"     // 6-20人
        case high = "高密度"       // 20+人

        /// 根据附近玩家数量判断密度等级
        static func from(playerCount: Int) -> DensityLevel {
            switch playerCount {
            case 0:
                return .alone
            case 1...5:
                return .low
            case 6...20:
                return .medium
            default:
                return .high
            }
        }
    }

    // MARK: - 初始化

    private init() {
        log("PlayerLocationManager 初始化完成")
    }

    // MARK: - 位置上报

    /// 上报当前位置到服务器
    /// - Parameter coordinate: 要上报的坐标（WGS-84）
    /// - Returns: 是否上报成功
    @discardableResult
    func reportLocation(_ coordinate: CLLocationCoordinate2D) async -> Bool {
        log("📡 正在上报位置: (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))")

        do {
            // 调用 RPC 函数上报位置
            try await supabase.rpc(
                "report_player_location",
                params: [
                    "p_lat": coordinate.latitude,
                    "p_lng": coordinate.longitude
                ]
            ).execute()

            // 更新状态
            lastReportedLocation = coordinate
            lastReportTime = Date()
            isOnline = true
            statusMessage = "位置已上报"

            log("✅ 位置上报成功", type: .success)
            return true

        } catch {
            log("❌ 位置上报失败: \(error.localizedDescription)", type: .error)
            statusMessage = "上报失败: \(error.localizedDescription)"
            return false
        }
    }

    /// 检查是否需要上报（距离上次上报位置超过50米）
    /// - Parameter currentLocation: 当前位置
    /// - Returns: 是否需要上报
    func shouldReport(currentLocation: CLLocationCoordinate2D) -> Bool {
        guard let lastLocation = lastReportedLocation else {
            // 从未上报过，需要上报
            return true
        }

        // 计算与上次上报位置的距离
        let lastCLLocation = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
        let currentCLLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let distance = currentCLLocation.distance(from: lastCLLocation)

        return distance >= significantDistance
    }

    // MARK: - 在线/离线状态

    /// 标记为在线
    func markOnline() async {
        log("📡 标记玩家在线...")

        do {
            try await supabase.rpc("mark_player_online").execute()
            isOnline = true
            statusMessage = "已标记在线"
            log("✅ 已标记为在线", type: .success)
        } catch {
            log("❌ 标记在线失败: \(error.localizedDescription)", type: .error)
        }
    }

    /// 标记为离线
    func markOffline() async {
        log("📡 标记玩家离线...")

        do {
            try await supabase.rpc("mark_player_offline").execute()
            isOnline = false
            statusMessage = "已标记离线"
            log("✅ 已标记为离线", type: .success)
        } catch {
            log("❌ 标记离线失败: \(error.localizedDescription)", type: .error)
        }
    }

    // MARK: - 查询附近玩家

    /// 查询附近玩家数量
    /// - Parameter coordinate: 查询中心点坐标
    /// - Returns: 附近玩家数量（不含自己）
    func countNearbyPlayers(around coordinate: CLLocationCoordinate2D) async -> Int {
        log("👥 查询附近玩家: 中心点 (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))), 半径 \(Int(searchRadius))m")

        do {
            // 调用 RPC 函数查询
            let response: Int = try await supabase.rpc(
                "count_nearby_players",
                params: [
                    "p_lat": coordinate.latitude,
                    "p_lng": coordinate.longitude,
                    "p_radius_meters": searchRadius,
                    "p_timeout_minutes": Double(onlineTimeout)
                ]
            ).execute().value

            nearbyPlayerCount = response
            let density = DensityLevel.from(playerCount: response)
            log("✅ 附近玩家: \(response) 人 (\(density.rawValue))", type: .success)

            return response

        } catch {
            log("❌ 查询附近玩家失败: \(error.localizedDescription)", type: .error)
            nearbyPlayerCount = 0
            return 0
        }
    }

    // MARK: - POI 数量计算

    /// 根据附近玩家数量计算建议的 POI 显示数量
    /// - Parameter playerCount: 附近玩家数量
    /// - Returns: 建议显示的 POI 数量
    func calculatePOILimit(playerCount: Int) -> Int {
        let density = DensityLevel.from(playerCount: playerCount)

        switch density {
        case .alone:
            // 独行者：1-2个 POI（保底）
            return 2
        case .low:
            // 低密度：3-5个 POI
            return 5
        case .medium:
            // 中密度：6-10个 POI
            return 10
        case .high:
            // 高密度：15-18个 POI（接近上限）
            return 18
        }
    }

    /// 获取当前密度等级
    func getCurrentDensityLevel() -> DensityLevel {
        return DensityLevel.from(playerCount: nearbyPlayerCount)
    }

    // MARK: - 定时上报

    /// 启动定时上报
    /// - Parameter locationProvider: 提供当前位置的闭包
    func startPeriodicReporting(locationProvider: @escaping () -> CLLocationCoordinate2D?) {
        // 停止现有定时器
        stopPeriodicReporting()

        log("⏱️ 启动定时位置上报 (间隔: \(Int(reportInterval))秒)")

        // 立即上报一次
        Task {
            if let location = locationProvider() {
                await reportLocation(location)
            }
        }

        // 创建定时器
        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let location = locationProvider() {
                    // 检查是否需要上报（移动超过50米或定时上报）
                    if self.shouldReport(currentLocation: location) {
                        await self.reportLocation(location)
                    } else {
                        self.log("📍 位置变化不大，跳过本次上报")
                    }
                } else {
                    self.log("⚠️ 无法获取当前位置", type: .warning)
                }
            }
        }
    }

    /// 停止定时上报
    func stopPeriodicReporting() {
        if reportTimer != nil {
            log("⏱️ 停止定时位置上报")
            reportTimer?.invalidate()
            reportTimer = nil
        }
    }

    // MARK: - 日志

    private func log(_ message: String, type: LogType = .info) {
        logger.log("[位置] \(message)", type: type)
        print("📍 [PlayerLocation] \(message)")
    }
}
