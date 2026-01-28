//
//  OfficialChannelDetailView.swift
//  EarthLord
//
//  官方频道详情页
//  Day 32-B: 显示官方频道的消息流（只读或可发送）
//

import SwiftUI

struct OfficialChannelDetailView: View {

    let channelName: String
    let channelIcon: String

    @State private var messageText = ""
    @StateObject private var communicationManager = CommunicationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // 频道信息横幅
            channelBanner

            // 消息列表
            ScrollView {
                VStack(spacing: 12) {
                    // 示例系统消息
                    officialMessage(
                        sender: "系统",
                        content: "欢迎加入「\(channelName)」频道",
                        time: "刚刚"
                    )

                    officialMessage(
                        sender: "管理员",
                        content: sampleMessage(for: channelName),
                        time: "5分钟前"
                    )
                }
                .padding(16)
            }

            // 输入框（仅当设备支持发送时显示）
            if communicationManager.canSendMessage() {
                inputBar
            } else {
                readOnlyBanner
            }
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(channelName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 频道横幅

    private var channelBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: channelIcon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.warning)

            Text(channelName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Text("官方")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ApocalypseTheme.warning)
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.warning.opacity(0.08))
    }

    // MARK: - 官方消息气泡

    private func officialMessage(sender: String, content: String, time: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(sender)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.primary)
                Text(time)
                    .font(.system(size: 10))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Text(content)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ApocalypseTheme.cardBackground.opacity(0.8))
    }

    // MARK: - 只读提示

    private var readOnlyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
            Text("当前设备仅能接收消息，切换到对讲机以发送")
                .font(.system(size: 12))
        }
        .foregroundColor(ApocalypseTheme.textMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 示例消息

    private func sampleMessage(for channel: String) -> String {
        switch channel {
        case "全区广播": return "注意：北区发现物资补给点，坐标已标记在地图上。请附近的幸存者前往查看。"
        case "交易频道": return "出木材30换金属10，有意者对讲机联系。"
        case "求助频道": return "有人在东区吗？我受伤了，需要医疗物资援助。"
        default: return "欢迎加入频道。"
        }
    }
}

#Preview {
    NavigationStack {
        OfficialChannelDetailView(channelName: "全区广播", channelIcon: "megaphone.fill")
    }
}
