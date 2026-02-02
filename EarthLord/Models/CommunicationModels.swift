//
//  CommunicationModels.swift
//  EarthLord
//
//  通讯系统数据模型
//  Day 32-A: 设备类型、设备模型、导航枚举
//  Day 36-A: 添加 MessageCategory 官方频道消息分类
//

import Foundation
import SwiftUI

// MARK: - 消息分类（官方频道专用）

enum MessageCategory: String, Codable, CaseIterable {
    case survival = "survival"   // 生存指南
    case news = "news"           // 游戏资讯
    case mission = "mission"     // 任务发布
    case alert = "alert"         // 紧急广播

    var displayName: String {
        switch self {
        case .survival: return "生存指南"
        case .news: return "游戏资讯"
        case .mission: return "任务发布"
        case .alert: return "紧急广播"
        }
    }

    var color: Color {
        switch self {
        case .survival: return .green
        case .news: return .blue
        case .mission: return .orange
        case .alert: return .red
        }
    }

    var iconName: String {
        switch self {
        case .survival: return "leaf.fill"
        case .news: return "newspaper.fill"
        case .mission: return "target"
        case .alert: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - AnyCodable（用于解析动态 JSON）

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable 无法解码值")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "AnyCodable 无法编码值"))
        }
    }
}

// MARK: - 设备类型

enum DeviceType: String, Codable, CaseIterable {
    case radio = "radio"
    case walkieTalkie = "walkie_talkie"
    case campRadio = "camp_radio"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .radio: return "收音机"
        case .walkieTalkie: return "对讲机"
        case .campRadio: return "营地电台"
        case .satellite: return "卫星通讯"
        }
    }

    var iconName: String {
        switch self {
        case .radio: return "radio"
        case .walkieTalkie: return "walkie.talkie.radio"
        case .campRadio: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var description: String {
        switch self {
        case .radio: return "只能接收信号，无法发送消息"
        case .walkieTalkie: return "可在3公里范围内通讯"
        case .campRadio: return "可在30公里范围内广播"
        case .satellite: return "可在100公里+范围内联络"
        }
    }

    var range: Double {
        switch self {
        case .radio: return Double.infinity
        case .walkieTalkie: return 3.0
        case .campRadio: return 30.0
        case .satellite: return 100.0
        }
    }

    var rangeText: String {
        switch self {
        case .radio: return "无限制（仅接收）"
        case .walkieTalkie: return "3 公里"
        case .campRadio: return "30 公里"
        case .satellite: return "100+ 公里"
        }
    }

    var canSend: Bool {
        self != .radio
    }

    var unlockRequirement: String {
        switch self {
        case .radio, .walkieTalkie: return "默认拥有"
        case .campRadio: return "需建造「营地电台」建筑"
        case .satellite: return "需建造「通讯塔」建筑"
        }
    }
}

// MARK: - 设备模型

struct CommunicationDevice: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let deviceType: DeviceType
    var deviceLevel: Int
    var isUnlocked: Bool
    var isCurrent: Bool
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceType = "device_type"
        case deviceLevel = "device_level"
        case isUnlocked = "is_unlocked"
        case isCurrent = "is_current"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 频道类型

enum ChannelType: String, Codable, CaseIterable {
    case official = "official"
    case `public` = "public"
    case walkie = "walkie"
    case camp = "camp"
    case satellite = "satellite"

    var displayName: String {
        switch self {
        case .official: return "官方频道"
        case .public: return "公开频道"
        case .walkie: return "对讲频道"
        case .camp: return "营地频道"
        case .satellite: return "卫星频道"
        }
    }

    var iconName: String {
        switch self {
        case .official: return "star.fill"
        case .public: return "globe"
        case .walkie: return "walkie.talkie.radio"
        case .camp: return "antenna.radiowaves.left.and.right"
        case .satellite: return "antenna.radiowaves.left.and.right.circle"
        }
    }

    var iconColor: String {
        switch self {
        case .official: return "warning"
        case .public: return "info"
        case .walkie: return "primary"
        case .camp: return "success"
        case .satellite: return "danger"
        }
    }

    var description: String {
        switch self {
        case .official: return "系统官方频道，所有人可见"
        case .public: return "所有人可见和加入"
        case .walkie: return "对讲机范围内可用（3公里）"
        case .camp: return "营地电台范围内可用（30公里）"
        case .satellite: return "卫星通讯范围（100+公里）"
        }
    }

    /// 可由玩家创建的频道类型
    static var creatableTypes: [ChannelType] {
        [.public, .walkie, .camp, .satellite]
    }
}

// MARK: - 频道模型

struct CommunicationChannel: Codable, Identifiable {
    let id: UUID
    let creatorId: UUID
    let channelType: ChannelType
    let channelCode: String
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case channelType = "channel_type"
        case channelCode = "channel_code"
        case name
        case description
        case isActive = "is_active"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 频道订阅模型

struct ChannelSubscription: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let channelId: UUID
    let isMuted: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case channelId = "channel_id"
        case isMuted = "is_muted"
        case joinedAt = "joined_at"
    }
}

// MARK: - 已订阅频道（组合模型）

struct SubscribedChannel: Identifiable {
    let channel: CommunicationChannel
    let subscription: ChannelSubscription

    var id: UUID { channel.id }
}

// MARK: - 导航枚举

enum CommunicationSection: String, CaseIterable {
    case messages = "消息"
    case channels = "频道"
    case call = "呼叫"
    case devices = "设备"

    var iconName: String {
        switch self {
        case .messages: return "bell.fill"
        case .channels: return "dot.radiowaves.left.and.right"
        case .call: return "phone.fill"
        case .devices: return "gearshape.fill"
        }
    }
}

// MARK: - 位置点模型（用于解析 PostGIS POINT）

struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double

    // 从 PostGIS WKT 格式解析：POINT(经度 纬度)
    static func fromPostGIS(_ wkt: String) -> LocationPoint? {
        let pattern = #"POINT\(([0-9.-]+)\s+([0-9.-]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: wkt, range: NSRange(wkt.startIndex..., in: wkt)),
              let lonRange = Range(match.range(at: 1), in: wkt),
              let latRange = Range(match.range(at: 2), in: wkt),
              let longitude = Double(wkt[lonRange]),
              let latitude = Double(wkt[latRange]) else {
            return nil
        }
        return LocationPoint(latitude: latitude, longitude: longitude)
    }

    // 从 GeoJSON 格式解析：{"type":"Point","coordinates":[经度, 纬度]}
    static func fromGeoJSON(_ data: Data) -> LocationPoint? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              type == "Point",
              let coordinates = json["coordinates"] as? [Double],
              coordinates.count >= 2 else {
            return nil
        }
        return LocationPoint(latitude: coordinates[1], longitude: coordinates[0])
    }

    // 从 GeoJSON 字典解析
    static func fromGeoJSON(_ dict: [String: Any]) -> LocationPoint? {
        guard let type = dict["type"] as? String,
              type == "Point",
              let coordinates = dict["coordinates"] as? [Double],
              coordinates.count >= 2 else {
            return nil
        }
        return LocationPoint(latitude: coordinates[1], longitude: coordinates[0])
    }
}

// MARK: - 消息元数据

struct MessageMetadata: Codable {
    let deviceType: String?
    let category: String?  // Day 36: 消息分类（官方频道使用）

    enum CodingKeys: String, CodingKey {
        case deviceType = "device_type"
        case category
    }
}

// MARK: - 频道消息模型

struct ChannelMessage: Codable, Identifiable {
    let messageId: UUID
    let channelId: UUID
    let senderId: UUID?
    let senderCallsign: String?
    let content: String
    let senderLocation: LocationPoint?
    let metadata: MessageMetadata?
    let createdAt: Date
    let senderDeviceType: DeviceType?  // Day 35: 发送者设备类型（用于距离过滤）

    var id: UUID { messageId }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case channelId = "channel_id"
        case senderId = "sender_id"
        case senderCallsign = "sender_callsign"
        case content
        case senderLocation = "sender_location"
        case metadata
        case createdAt = "created_at"
        case senderDeviceType = "sender_device_type"
    }

    // 自定义解码（处理 PostGIS POINT 格式 + 多种日期格式）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        messageId = try container.decode(UUID.self, forKey: .messageId)
        channelId = try container.decode(UUID.self, forKey: .channelId)
        senderId = try container.decodeIfPresent(UUID.self, forKey: .senderId)
        senderCallsign = try container.decodeIfPresent(String.self, forKey: .senderCallsign)
        content = try container.decode(String.self, forKey: .content)
        metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)

        // 解析位置（支持多种格式：GeoJSON 字符串、WKT 字符串、GeoJSON 对象、普通对象）
        if let locationString = try? container.decode(String.self, forKey: .senderLocation) {
            // 格式1: GeoJSON 字符串 "{\"type\":\"Point\",\"coordinates\":[经度, 纬度]}"
            if locationString.contains("coordinates"),
               let data = locationString.data(using: .utf8) {
                senderLocation = LocationPoint.fromGeoJSON(data)
            }
            // 格式2: PostGIS WKT 字符串 "POINT(经度 纬度)"
            else if locationString.hasPrefix("POINT") {
                senderLocation = LocationPoint.fromPostGIS(locationString)
            }
            // 其他字符串格式，无法解析
            else {
                senderLocation = nil
            }
        } else if let locationDict = try? container.decode([String: AnyCodable].self, forKey: .senderLocation) {
            // 格式3: GeoJSON 对象 {"type":"Point","coordinates":[经度, 纬度]}
            var dict: [String: Any] = [:]
            for (key, value) in locationDict {
                dict[key] = value.value
            }
            senderLocation = LocationPoint.fromGeoJSON(dict)
        } else {
            // 格式4: 普通 LocationPoint 对象
            senderLocation = try container.decodeIfPresent(LocationPoint.self, forKey: .senderLocation)
        }

        // 解析日期（支持多种格式）
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ChannelMessage.parseDate(dateString) ?? Date()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }

        // Day 35: 解析发送者设备类型（优先从独立字段，其次从 metadata）
        if let deviceTypeString = try? container.decode(String.self, forKey: .senderDeviceType),
           let deviceType = DeviceType(rawValue: deviceTypeString) {
            senderDeviceType = deviceType
        } else if let deviceTypeValue = metadata?.deviceType,
                  let deviceType = DeviceType(rawValue: deviceTypeValue) {
            senderDeviceType = deviceType
        } else {
            senderDeviceType = nil  // 向后兼容：老消息没有设备类型
        }
    }

    // 日期解析辅助方法
    private static func parseDate(_ string: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    // 显示用计算属性
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: createdAt)
        }
    }

    // 格式化时间
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: createdAt)
    }

    // 获取设备类型
    var deviceType: String? {
        metadata?.deviceType
    }

    // Day 36: 获取消息分类（官方频道使用）
    var category: MessageCategory? {
        guard let categoryString = metadata?.category else { return nil }
        return MessageCategory(rawValue: categoryString)
    }
}
