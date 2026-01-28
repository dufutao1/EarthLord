//
//  MessageCenterView.swift
//  EarthLord
//
//  消息中心页面
//  Day 32-B: 显示系统公告和玩家消息
//

import SwiftUI

struct MessageCenterView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 系统公告区域
                systemAnnouncementSection

                // 消息列表占位
                emptyMessageView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - 系统公告

    private var systemAnnouncementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.warning)
                Text("系统公告")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("欢迎来到末日世界！")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("通讯系统已上线，使用对讲机与附近的幸存者联络。建造营地电台可扩大通讯范围。")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                Text("刚刚")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ApocalypseTheme.warning.opacity(0.08))
            .cornerRadius(10)
        }
    }

    // MARK: - 空消息

    private var emptyMessageView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无新消息")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("当有附近的幸存者联络你时\n消息会出现在这里")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    MessageCenterView()
        .background(ApocalypseTheme.background)
}
