//
//  CommunicationManager.swift
//  EarthLord
//
//  通讯系统管理器
//  Day 32-A: 设备加载、切换、解锁
//

import Foundation
import Combine
import Supabase
import CoreLocation

@MainActor
final class CommunicationManager: ObservableObject {
    static let shared = CommunicationManager()

    // MARK: - 官方频道（Day 36）
    /// 官方频道固定 UUID
    static let officialChannelId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @Published private(set) var devices: [CommunicationDevice] = []
    @Published private(set) var currentDevice: CommunicationDevice?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 频道相关属性
    @Published private(set) var channels: [CommunicationChannel] = []
    @Published private(set) var subscribedChannels: [SubscribedChannel] = []
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    // MARK: - 消息相关属性
    @Published var channelMessages: [UUID: [ChannelMessage]] = [:]
    @Published var isSendingMessage = false

    // MARK: - 消息距离缓存（收到消息时计算一次，不再变化）
    private(set) var messageDistanceCache: [UUID: Double] = [:]  // messageId -> 距离(km)

    // MARK: - Realtime 相关属性
    private var realtimeChannel: RealtimeChannelV2?
    private var messageSubscriptionTask: Task<Void, Never>?
    @Published var subscribedChannelIds: Set<UUID> = []

    private let client = supabase

    private init() {}

    // MARK: - 加载设备

    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationDevice] = try await client
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })

            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 初始化设备

    func initializeDevices(userId: UUID) async {
        do {
            try await client.rpc("initialize_user_devices", params: ["p_user_id": userId.uuidString]).execute()
            await loadDevices(userId: userId)
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 切换设备

    func switchDevice(userId: UUID, to deviceType: DeviceType) async {
        guard let device = devices.first(where: { $0.deviceType == deviceType }), device.isUnlocked else {
            errorMessage = "设备未解锁"
            return
        }

        if device.isCurrent { return }

        isLoading = true

        do {
            try await client.rpc("switch_current_device", params: [
                "p_user_id": userId.uuidString,
                "p_device_type": deviceType.rawValue
            ]).execute()

            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })
        } catch {
            errorMessage = "切换失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 解锁设备（由建造系统调用）

    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            let updateData = DeviceUnlockUpdate(
                isUnlocked: true,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await client
                .from("communication_devices")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }
        } catch {
            errorMessage = "解锁失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 便捷查询方法

    func getCurrentDeviceType() -> DeviceType { currentDevice?.deviceType ?? .walkieTalkie }
    func canSendMessage() -> Bool { currentDevice?.deviceType.canSend ?? false }
    func getCurrentRange() -> Double { currentDevice?.deviceType.range ?? 3.0 }
    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    // MARK: - 加载公开频道（发现页）

    func loadPublicChannels() async {
        do {
            let response: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            channels = response
        } catch {
            errorMessage = "加载频道失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 加载已订阅频道（我的频道）

    func loadSubscribedChannels(userId: UUID) async {
        do {
            // 1. 查询订阅
            let subscriptions: [ChannelSubscription] = try await client
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            mySubscriptions = subscriptions

            guard !subscriptions.isEmpty else {
                subscribedChannels = []
                return
            }

            // 2. 查询频道详情
            let channelIds = subscriptions.map { $0.channelId.uuidString }
            let channelList: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .in("id", values: channelIds)
                .execute()
                .value

            // 3. 组合
            subscribedChannels = subscriptions.compactMap { sub in
                guard let channel = channelList.first(where: { $0.id == sub.channelId }) else { return nil }
                return SubscribedChannel(channel: channel, subscription: sub)
            }
        } catch {
            errorMessage = "加载订阅频道失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 官方频道相关（Day 36）

    /// 确保用户订阅了官方频道（强制订阅）
    func ensureOfficialChannelSubscribed(userId: UUID) async {
        let officialId = CommunicationManager.officialChannelId

        // 检查是否已订阅
        if subscribedChannels.contains(where: { $0.channel.id == officialId }) {
            print("✅ [官方频道] 已订阅")
            return
        }

        // 强制订阅官方频道
        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId.uuidString),
                "p_channel_id": .string(officialId.uuidString)
            ]

            try await client.rpc("subscribe_to_channel", params: params).execute()

            // 刷新订阅列表
            await loadSubscribedChannels(userId: userId)
            print("✅ [官方频道] 已自动订阅")
        } catch {
            print("❌ [官方频道] 订阅失败: \(error)")
        }
    }

    /// 检查是否是官方频道
    func isOfficialChannel(_ channelId: UUID) -> Bool {
        return channelId == CommunicationManager.officialChannelId
    }

    // MARK: - 创建频道

    func createChannel(
        userId: UUID,
        type: ChannelType,
        name: String,
        description: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let params: [String: AnyJSON] = [
                "p_creator_id": .string(userId.uuidString),
                "p_channel_type": .string(type.rawValue),
                "p_name": .string(name),
                "p_description": description.map { .string($0) } ?? .null,
                "p_latitude": latitude.map { .double($0) } ?? .null,
                "p_longitude": longitude.map { .double($0) } ?? .null
            ]

            try await client
                .rpc("create_channel_with_subscription", params: params)
                .execute()

            // 刷新数据
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            return true
        } catch {
            errorMessage = "创建频道失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 订阅频道

    func subscribeToChannel(userId: UUID, channelId: UUID) async -> Bool {
        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId.uuidString),
                "p_channel_id": .string(channelId.uuidString)
            ]

            try await client
                .rpc("subscribe_to_channel", params: params)
                .execute()

            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            return true
        } catch {
            errorMessage = "订阅失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 取消订阅

    func unsubscribeFromChannel(userId: UUID, channelId: UUID) async -> Bool {
        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId.uuidString),
                "p_channel_id": .string(channelId.uuidString)
            ]

            try await client
                .rpc("unsubscribe_from_channel", params: params)
                .execute()

            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            return true
        } catch {
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 检查是否已订阅

    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains { $0.channelId == channelId }
    }

    // MARK: - 删除频道

    func deleteChannel(userId: UUID, channelId: UUID) async -> Bool {
        do {
            let params: [String: AnyJSON] = [
                "p_user_id": .string(userId.uuidString),
                "p_channel_id": .string(channelId.uuidString)
            ]

            try await client
                .rpc("delete_channel", params: params)
                .execute()

            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)

            return true
        } catch {
            errorMessage = "删除频道失败: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 加载频道历史消息

    func loadChannelMessages(channelId: UUID) async {
        do {
            let messages: [ChannelMessage] = try await client
                .from("channel_messages_view")  // 使用视图获取 GeoJSON 格式的位置
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(50)
                .execute()
                .value

            channelMessages[channelId] = messages

            // 缓存每条消息的距离（加载时计算一次）
            for message in messages {
                cacheMessageDistance(message)
            }
        } catch {
            errorMessage = "加载消息失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 发送频道消息

    func sendChannelMessage(
        channelId: UUID,
        content: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        deviceType: String? = nil
    ) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "消息内容不能为空"
            return false
        }

        isSendingMessage = true

        do {
            let params: [String: AnyJSON] = [
                "p_channel_id": .string(channelId.uuidString),
                "p_content": .string(content),
                "p_latitude": latitude.map { .double($0) } ?? .null,
                "p_longitude": longitude.map { .double($0) } ?? .null,
                "p_device_type": deviceType.map { .string($0) } ?? .null
            ]

            let _: UUID = try await client
                .rpc("send_channel_message", params: params)
                .execute()
                .value

            isSendingMessage = false
            return true
        } catch {
            errorMessage = "发送失败: \(error.localizedDescription)"
            isSendingMessage = false
            return false
        }
    }

    // MARK: - 启动 Realtime 消息订阅

    func startRealtimeSubscription() async {
        // 如果已经订阅，先停止
        await stopRealtimeSubscription()

        // 创建 Realtime 频道
        realtimeChannel = await client.realtimeV2.channel("channel_messages_realtime")

        guard let channel = realtimeChannel else { return }

        // 订阅 INSERT 事件
        let insertions = await channel.postgresChange(
            InsertAction.self,
            table: "channel_messages"
        )

        // 启动监听任务
        messageSubscriptionTask = Task { [weak self] in
            for await insertion in insertions {
                await self?.handleNewMessage(insertion: insertion)
            }
        }

        // 开始订阅
        await channel.subscribe()

        print("[Realtime] 消息订阅已启动")
    }

    // MARK: - 停止 Realtime 订阅

    func stopRealtimeSubscription() async {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil

        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }

        print("[Realtime] 消息订阅已停止")
    }

    // MARK: - 处理新消息

    private func handleNewMessage(insertion: InsertAction) async {
        do {
            // 先解码基本信息（用于过滤判断）
            let basicMessage = try insertion.decodeRecord(as: ChannelMessage.self, decoder: JSONDecoder())

            // 第一关：检查是否是已订阅频道的消息
            guard subscribedChannelIds.contains(basicMessage.channelId) else {
                print("[Realtime] 忽略未订阅频道的消息: \(basicMessage.channelId)")
                return
            }

            // 从视图重新获取完整消息（包含正确格式的位置信息）
            let fullMessages: [ChannelMessage] = try await client
                .from("channel_messages_view")
                .select()
                .eq("message_id", value: basicMessage.messageId.uuidString)
                .execute()
                .value

            guard let message = fullMessages.first else {
                print("[Realtime] 无法从视图获取消息")
                return
            }

            // 第二关：距离过滤（Day 35）
            guard shouldReceiveMessage(message) else {
                print("[Realtime] 距离过滤丢弃消息")
                return
            }

            // 缓存距离（收到时计算一次，之后不变）
            cacheMessageDistance(message)

            // 添加到消息列表
            if channelMessages[message.channelId] != nil {
                channelMessages[message.channelId]?.append(message)
            } else {
                channelMessages[message.channelId] = [message]
            }

            print("[Realtime] 收到新消息: \(message.content.prefix(20))...")
        } catch {
            print("[Realtime] 解析消息失败: \(error)")
        }
    }

    // MARK: - 订阅频道消息（添加到订阅列表）

    func subscribeToChannelMessages(channelId: UUID) {
        subscribedChannelIds.insert(channelId)

        // 如果 Realtime 未启动，启动它
        if realtimeChannel == nil {
            Task {
                await startRealtimeSubscription()
            }
        }
    }

    // MARK: - 取消订阅频道消息

    func unsubscribeFromChannelMessages(channelId: UUID) {
        subscribedChannelIds.remove(channelId)
        channelMessages.removeValue(forKey: channelId)

        // 如果没有订阅任何频道，停止 Realtime
        if subscribedChannelIds.isEmpty {
            Task {
                await stopRealtimeSubscription()
            }
        }
    }

    // MARK: - 获取频道消息列表

    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    /// 获取消息的缓存距离（公里），如果没有缓存则返回 nil
    func getCachedDistance(for messageId: UUID) -> Double? {
        messageDistanceCache[messageId]
    }

    // MARK: - 消息聚合相关（Day 36-C）

    /// 频道摘要（用于消息聚合页）
    struct ChannelSummary: Identifiable {
        let channel: CommunicationChannel
        let lastMessage: ChannelMessage?
        let unreadCount: Int

        var id: UUID { channel.id }
    }

    /// 获取所有订阅频道的摘要（最新消息 + 未读数）
    func getChannelSummaries() -> [ChannelSummary] {
        return subscribedChannels.map { subscribedChannel in
            let messages = channelMessages[subscribedChannel.channel.id] ?? []
            let lastMessage = messages.last
            // 简化版：暂不计算真实未读数，后续可扩展
            let unreadCount = 0

            return ChannelSummary(
                channel: subscribedChannel.channel,
                lastMessage: lastMessage,
                unreadCount: unreadCount
            )
        }.sorted { summary1, summary2 in
            // 官方频道置顶
            if summary1.channel.channelType == .official && summary2.channel.channelType != .official {
                return true
            }
            if summary1.channel.channelType != .official && summary2.channel.channelType == .official {
                return false
            }
            // 其他按最新消息时间排序
            let time1 = summary1.lastMessage?.createdAt ?? summary1.channel.createdAt
            let time2 = summary2.lastMessage?.createdAt ?? summary2.channel.createdAt
            return time1 > time2
        }
    }

    /// 加载所有订阅频道的最新消息（用于消息聚合页初始化）
    func loadAllChannelLatestMessages() async {
        for subscribedChannel in subscribedChannels {
            let channelId = subscribedChannel.channel.id
            // 只加载最新的 1 条消息（用于预览）
            do {
                let messages: [ChannelMessage] = try await client
                    .from("channel_messages_view")
                    .select()
                    .eq("channel_id", value: channelId.uuidString)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value

                if let lastMessage = messages.first {
                    if channelMessages[channelId] == nil {
                        channelMessages[channelId] = [lastMessage]
                    } else if !channelMessages[channelId]!.contains(where: { $0.id == lastMessage.id }) {
                        channelMessages[channelId]?.append(lastMessage)
                    }
                    // 缓存距离
                    cacheMessageDistance(lastMessage)
                }
            } catch {
                print("❌ [消息聚合] 加载频道 \(channelId) 最新消息失败: \(error)")
            }
        }
    }

    /// 计算并缓存消息距离
    private func cacheMessageDistance(_ message: ChannelMessage) {
        // 已缓存则跳过
        guard messageDistanceCache[message.messageId] == nil else { return }

        // 需要发送者位置
        guard let senderLocation = message.senderLocation else { return }

        // 需要当前用户位置
        guard let myLocation = getCurrentLocation() else { return }

        // 转换为 CLLocationCoordinate2D
        let senderCoord = CLLocationCoordinate2D(
            latitude: senderLocation.latitude,
            longitude: senderLocation.longitude
        )
        let myCoord = CLLocationCoordinate2D(
            latitude: myLocation.latitude,
            longitude: myLocation.longitude
        )

        // 计算距离
        let distance = calculateDistance(from: senderCoord, to: myCoord)
        messageDistanceCache[message.messageId] = distance
    }

    // MARK: - 距离过滤逻辑（Day 35）

    /// 判断是否应该接收该消息（基于设备类型和距离）
    func shouldReceiveMessage(_ message: ChannelMessage) -> Bool {
        // 1. 获取当前用户设备类型
        guard let myDeviceType = currentDevice?.deviceType else {
            print("⚠️ [距离过滤] 无法获取当前设备，保守显示消息")
            return true  // 保守策略：无设备信息时显示
        }

        // 2. 收音机可以接收所有消息（无限距离）
        if myDeviceType == .radio {
            print("📻 [距离过滤] 收音机用户，接收所有消息")
            return true
        }

        // 3. 检查发送者设备类型
        guard let senderDevice = message.senderDeviceType else {
            print("⚠️ [距离过滤] 消息缺少设备类型，保守显示（向后兼容）")
            return true  // 向后兼容：老消息没有设备类型
        }

        // 4. 收音机不能发送消息
        if senderDevice == .radio {
            print("🚫 [距离过滤] 收音机不能发送消息")
            return false
        }

        // 5. 检查发送者位置
        guard let senderLocation = message.senderLocation else {
            print("⚠️ [距离过滤] 消息缺少位置信息，保守显示")
            return true  // 保守策略：无位置信息时显示
        }

        // 6. 获取当前用户位置
        guard let myLocation = getCurrentLocation() else {
            print("⚠️ [距离过滤] 无法获取当前位置，保守显示")
            return true  // 保守策略：无当前位置时显示
        }

        // 7. 计算距离（公里）
        let distance = calculateDistance(
            from: CLLocationCoordinate2D(
                latitude: myLocation.latitude,
                longitude: myLocation.longitude
            ),
            to: CLLocationCoordinate2D(
                latitude: senderLocation.latitude,
                longitude: senderLocation.longitude
            )
        )

        // 8. 根据设备矩阵判断
        let canReceive = canReceiveMessage(
            senderDevice: senderDevice,
            myDevice: myDeviceType,
            distance: distance
        )

        if canReceive {
            print("✅ [距离过滤] 通过: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km")
        } else {
            print("🚫 [距离过滤] 丢弃: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km (超出范围)")
        }

        return canReceive
    }

    /// 根据设备类型矩阵判断是否能接收消息
    private func canReceiveMessage(
        senderDevice: DeviceType,
        myDevice: DeviceType,
        distance: Double
    ) -> Bool {
        // 收音机接收方：无距离限制
        if myDevice == .radio {
            return true
        }

        // 收音机发送方：不能发送
        if senderDevice == .radio {
            return false
        }

        // 设备矩阵（含5%缓冲区，减少GPS抖动影响）
        switch (senderDevice, myDevice) {
        // 对讲机发送（3km覆盖）
        case (.walkieTalkie, .walkieTalkie):
            return distance <= 3.15  // 3km + 5%缓冲
        case (.walkieTalkie, .campRadio):
            return distance <= 31.5  // 30km + 5%缓冲
        case (.walkieTalkie, .satellite):
            return distance <= 105.0  // 100km + 5%缓冲

        // 营地电台发送（30km覆盖）
        case (.campRadio, .walkieTalkie):
            return distance <= 31.5
        case (.campRadio, .campRadio):
            return distance <= 31.5
        case (.campRadio, .satellite):
            return distance <= 105.0

        // 卫星通讯发送（100km覆盖）
        case (.satellite, .walkieTalkie):
            return distance <= 105.0
        case (.satellite, .campRadio):
            return distance <= 105.0
        case (.satellite, .satellite):
            return distance <= 105.0

        default:
            return false
        }
    }

    /// 计算两个坐标之间的距离（公里）
    private func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let fromLocation = CLLocation(
            latitude: from.latitude,
            longitude: from.longitude
        )
        let toLocation = CLLocation(
            latitude: to.latitude,
            longitude: to.longitude
        )
        return fromLocation.distance(from: toLocation) / 1000.0  // 转换为公里
    }

    /// 获取当前用户位置（从 LocationManager 获取真实 GPS）
    private func getCurrentLocation() -> LocationPoint? {
        guard let coordinate = LocationManager.shared.userLocation else {
            print("⚠️ [距离过滤] LocationManager 无位置数据")
            return nil
        }
        return LocationPoint(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}

// MARK: - Update Models

private struct DeviceUnlockUpdate: Encodable {
    let isUnlocked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case updatedAt = "updated_at"
    }
}
