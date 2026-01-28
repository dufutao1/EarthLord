//
//  ChannelChatView.swift
//  EarthLord
//
//  频道聊天页面
//  Day 32-B: 频道内的聊天消息流
//

import SwiftUI

struct ChannelChatView: View {

    let channelName: String

    @State private var messageText = ""
    @StateObject private var communicationManager = CommunicationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollView {
                VStack(spacing: 12) {
                    // 系统消息
                    systemMessage("频道已创建")

                    // 占位提示
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
                .padding(16)
            }

            // 输入框
            inputBar
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(channelName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 系统消息

    private func systemMessage(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(ApocalypseTheme.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ApocalypseTheme.textMuted.opacity(0.1))
            .cornerRadius(10)
            .frame(maxWidth: .infinity)
    }

    // MARK: - 输入框

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("输入消息...", text: $messageText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)

            Button(action: {
                guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                // TODO: 发送消息
                messageText = ""
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundColor(
                        messageText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? ApocalypseTheme.textMuted
                            : ApocalypseTheme.primary
                    )
            }
            .disabled(!communicationManager.canSendMessage())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground.opacity(0.8))
    }
}

#Preview {
    NavigationStack {
        ChannelChatView(channelName: "测试频道")
    }
}
