//
//  MessageRowView.swift
//  EarthLord
//
//  消息行组件（用于消息中心）
//  Day 36-C: 显示频道摘要信息
//

import SwiftUI

struct MessageRowView: View {
    let summary: CommunicationManager.ChannelSummary

    private var isOfficial: Bool {
        summary.channel.channelType == .official
    }

    var body: some View {
        HStack(spacing: 12) {
            // 频道图标
            channelIcon

            // 频道信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(summary.channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.text)

                    if isOfficial {
                        Text("官方")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }

                    Spacer()

                    // 时间
                    if let lastMessage = summary.lastMessage {
                        Text(lastMessage.timeAgo)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.secondaryText)
                    }
                }

                // 最新消息预览
                HStack {
                    if let lastMessage = summary.lastMessage {
                        if let callsign = lastMessage.senderCallsign {
                            Text("\(callsign): ")
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.primary)
                        }
                        Text(lastMessage.content)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.secondaryText)
                            .lineLimit(1)
                    } else {
                        Text("暂无消息")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.secondaryText)
                            .italic()
                    }

                    Spacer()

                    // 未读数
                    if summary.unreadCount > 0 {
                        Text("\(summary.unreadCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(ApocalypseTheme.primary)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(12)
        .background(isOfficial ? ApocalypseTheme.primary.opacity(0.1) : ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private var channelIcon: some View {
        ZStack {
            Circle()
                .fill(channelIconColor.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: channelIconName)
                .font(.system(size: 22))
                .foregroundColor(channelIconColor)
        }
    }

    private var channelIconName: String {
        switch summary.channel.channelType {
        case .official: return "megaphone.fill"
        case .public: return "antenna.radiowaves.left.and.right"
        case .walkie: return "person.wave.2.fill"
        case .camp: return "radio.fill"
        case .satellite: return "antenna.radiowaves.left.and.right.circle.fill"
        }
    }

    private var channelIconColor: Color {
        switch summary.channel.channelType {
        case .official: return .red
        case .public: return .blue
        case .walkie: return ApocalypseTheme.primary
        case .camp: return .purple
        case .satellite: return .cyan
        }
    }
}
