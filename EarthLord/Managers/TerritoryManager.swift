//
//  TerritoryManager.swift
//  EarthLord
//
//  领地管理器
//  负责领地数据的上传和拉取
//

import Foundation
import CoreLocation
import Supabase

/// 领地上传数据模型
struct TerritoryUpload: Encodable {
    let userId: String
    let path: [[String: Double]]
    let polygon: String
    let bboxMinLat: Double
    let bboxMaxLat: Double
    let bboxMinLon: Double
    let bboxMaxLon: Double
    let area: Double
    let pointCount: Int
    let startedAt: String
    let completedAt: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case path
        case polygon
        case bboxMinLat = "bbox_min_lat"
        case bboxMaxLat = "bbox_max_lat"
        case bboxMinLon = "bbox_min_lon"
        case bboxMaxLon = "bbox_max_lon"
        case area
        case pointCount = "point_count"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case isActive = "is_active"
    }
}

/// 领地管理器
final class TerritoryManager {

    // MARK: - 单例

    static let shared = TerritoryManager()

    private init() {}

    // MARK: - 坐标转换方法

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: JSON 格式的路径数组 [{"lat": x, "lon": y}, ...]
    func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标数组转换为 WKT 格式（用于 PostGIS）
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT 格式字符串
    /// - Note: WKT 格式是「经度在前，纬度在后」，多边形必须闭合
    func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else {
            return ""
        }

        // 确保多边形闭合（首尾相同）
        var closedCoords = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                closedCoords.append(first)
            }
        }

        // WKT 格式：经度在前，纬度在后
        let pointsString = closedCoords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }.joined(separator: ", ")

        return "SRID=4326;POLYGON((\(pointsString)))"
    }

    /// 计算坐标数组的边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        guard !coordinates.isEmpty else {
            return nil
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传方法

    /// 上传领地到数据库
    /// - Parameters:
    ///   - coordinates: 领地坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始圈地时间
    /// - Throws: 上传失败时抛出错误
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        // 获取当前用户 ID
        guard let userId = supabase.auth.currentUser?.id else {
            throw TerritoryError.notAuthenticated
        }

        // 转换坐标格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)

        // 计算边界框
        guard let bbox = calculateBoundingBox(coordinates) else {
            throw TerritoryError.invalidCoordinates
        }

        // ISO8601 时间格式
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 构建上传数据
        let territoryData = TerritoryUpload(
            userId: userId.uuidString,
            path: pathJSON,
            polygon: wktPolygon,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            area: area,
            pointCount: coordinates.count,
            startedAt: iso8601Formatter.string(from: startTime),
            completedAt: iso8601Formatter.string(from: Date()),
            isActive: true
        )

        // 执行上传
        print("📤 [领地] 开始上传领地，面积: \(String(format: "%.0f", area))m²，点数: \(coordinates.count)")

        try await supabase
            .from("territories")
            .insert(territoryData)
            .execute()

        print("📤 [领地] ✅ 领地上传成功！")
        TerritoryLogger.shared.log("领地上传成功！面积: \(String(format: "%.0f", area))m²", type: .success)
    }

    // MARK: - 查询方法

    /// 加载所有激活的领地
    /// - Returns: 领地数组
    func loadAllTerritories() async throws -> [Territory] {
        print("📥 [领地] 开始加载所有领地...")

        let response: [Territory] = try await supabase
            .from("territories")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value

        print("📥 [领地] ✅ 加载完成，共 \(response.count) 个领地")
        return response
    }

    /// 加载当前用户的领地
    /// - Returns: 当前用户的领地数组
    func loadMyTerritories() async throws -> [Territory] {
        guard let userId = supabase.auth.currentUser?.id else {
            throw TerritoryError.notAuthenticated
        }

        print("📥 [领地] 开始加载我的领地...")

        let response: [Territory] = try await supabase
            .from("territories")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value

        print("📥 [领地] ✅ 加载完成，共 \(response.count) 个领地")
        return response
    }

    // MARK: - 删除方法

    /// 删除领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    func deleteTerritory(territoryId: String) async -> Bool {
        print("🗑️ [领地] 开始删除领地: \(territoryId)")

        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()

            print("🗑️ [领地] ✅ 领地删除成功")
            return true
        } catch {
            print("🗑️ [领地] ❌ 领地删除失败: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - 错误类型

enum TerritoryError: LocalizedError {
    case notAuthenticated
    case invalidCoordinates
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .invalidCoordinates:
            return "无效的坐标数据"
        case .uploadFailed(let message):
            return "上传失败: \(message)"
        }
    }
}
