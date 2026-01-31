//
//  ChannelChatView.swift
//  EarthLord
//
//  频道聊天页面
//  Day 34: 消息列表 + 发送 + Realtime 订阅
//

import SwiftUI
import Supabase
import CoreLocation

struct ChannelChatView: View {

    let channel: CommunicationChannel

    @StateObject private var communicationManager = CommunicationManager.shared
    @State private var messageText = ""
    @State private var scrollToBottom = false

    private var currentUserId: UUID? {
        supabase.auth.currentUser?.id
    }

    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    private var canSend: Bool {
        communicationManager.canSendMessage()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            messageListView

            // 输入栏 或 收音机提示
            if canSend {
                inputBar
            } else {
                radioModeHint
            }
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                    Text("\(channel.memberCount)")
                        .font(.system(size: 12))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .onAppear {
            setupChat()
        }
        .onDisappear {
            communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
        }
    }

    // MARK: - 设置聊天

    private func setupChat() {
        // 订阅 Realtime 消息
        communicationManager.subscribeToChannelMessages(channelId: channel.id)

        // 加载历史消息
        Task {
            await communicationManager.loadChannelMessages(channelId: channel.id)
        }
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // 频道信息头部
                    channelHeader

                    if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isMe: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }

                    // 底部占位（用于滚动）
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - 频道头部信息

    private var channelHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            Text(channel.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(channel.channelCode)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textMuted)

            if let desc = channel.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有消息")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("发送第一条消息吧")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("输入消息...", text: $messageText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)

            Button(action: sendMessage) {
                Group {
                    if communicationManager.isSendingMessage {
                        ProgressView()
                            .tint(ApocalypseTheme.primary)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(
                                messageText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? ApocalypseTheme.textMuted
                                    : ApocalypseTheme.primary
                            )
                    }
                }
                .frame(width: 36, height: 36)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || communicationManager.isSendingMessage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
    }

    // MARK: - 收音机模式提示

    private var radioModeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "radio")
                .font(.system(size: 16))
            Text("收音机模式：只能收听，无法发送消息")
                .font(.system(size: 13))
        }
        .foregroundColor(ApocalypseTheme.warning)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.warning.opacity(0.1))
    }

    // MARK: - 发送消息

    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        let deviceType = communicationManager.getCurrentDeviceType().rawValue

        // Day 35-B: 从 LocationManager 获取真实 GPS 位置
        let location = LocationManager.shared.userLocation
        let latitude = location?.latitude
        let longitude = location?.longitude

        messageText = ""

        Task {
            let _ = await communicationManager.sendChannelMessage(
                channelId: channel.id,
                content: content,
                latitude: latitude,
                longitude: longitude,
                deviceType: deviceType
            )
        }
    }
}

// MARK: - 消息气泡组件

struct MessageBubbleView: View {

    let message: ChannelMessage
    let isMe: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMe {
                Spacer(minLength: 60)
                bubbleContent
            } else {
                bubbleContent
                Spacer(minLength: 60)
            }
        }
    }

    private var bubbleContent: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
            // 呼号（仅他人消息显示）
            if !isMe, let callsign = message.senderCallsign {
                HStack(spacing: 4) {
                    Text(callsign)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ApocalypseTheme.primary)

                    if let deviceType = message.deviceType {
                        Image(systemName: deviceIconName(for: deviceType))
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }

            // 消息内容
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(isMe ? .white : ApocalypseTheme.textPrimary)

                Text(message.formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(isMe ? .white.opacity(0.7) : ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isMe ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    private func deviceIconName(for deviceType: String) -> String {
        switch deviceType {
        case "radio": return "radio"
        case "walkieTalkie", "walkie_talkie": return "antenna.radiowaves.left.and.right"
        case "campRadio", "camp_radio": return "antenna.radiowaves.left.and.right"
        case "satellite": return "antenna.radiowaves.left.and.right.circle"
        default: return "iphone"
        }
    }
}

// MARK: - 简化初始化（兼容旧调用）

extension ChannelChatView {
    init(channelName: String) {
        self.init(channel: CommunicationChannel(
            id: UUID(),
            creatorId: UUID(),
            channelType: .public,
            channelCode: "TEMP",
            name: channelName,
            description: nil,
            isActive: true,
            memberCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}

#Preview {
    NavigationStack {
        ChannelChatView(channel: CommunicationChannel(
            id: UUID(),
            creatorId: UUID(),
            channelType: .public,
            channelCode: "PUB-TEST",
            name: "测试频道",
            description: "测试描述",
            isActive: true,
            memberCount: 5,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
