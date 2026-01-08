//
//  Territory.swift
//  EarthLord
//
//  领地数据模型
//  用于解析数据库返回的领地数据
//

import Foundation
import CoreLocation

/// 领地数据模型
struct Territory: Codable, Identifiable {
    /// 领地唯一标识
    let id: String

    /// 所属用户 ID
    let userId: String

    /// 领地名称（可选，数据库允许为空）
    let name: String?

    /// 路径坐标数组，格式：[{"lat": x, "lon": y}]
    let path: [[String: Double]]

    /// 领地面积（平方米）
    let area: Double

    /// 坐标点数量（可选）
    let pointCount: Int?

    /// 是否激活（可选）
    let isActive: Bool?

    /// 创建时间（可选）
    let createdAt: String?

    /// 开始圈地时间（可选）
    let startedAt: String?

    /// 完成圈地时间（可选）
    let completedAt: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }

    // MARK: - 方法

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    /// - Returns: 坐标数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    // MARK: - 计算属性

    /// 格式化面积显示
    var formattedArea: String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    /// 显示名称（如果没有名称则显示默认值）
    var displayName: String {
        return name ?? "未命名领地"
    }

    /// 格式化创建时间
    var formattedDate: String {
        guard let dateStr = completedAt ?? createdAt else {
            return "未知时间"
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return displayFormatter.string(from: date)
        }

        return dateStr
    }
}
