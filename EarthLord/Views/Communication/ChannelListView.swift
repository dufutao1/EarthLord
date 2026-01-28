//
//  ChannelListView.swift
//  EarthLord
//
//  玩家频道列表
//  Day 32-B: 显示已加入的玩家创建频道
//

import SwiftUI

struct ChannelListView: View {

    var body: some View {
        VStack(spacing: 10) {
            // 占位：暂无玩家频道
            VStack(spacing: 12) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 36))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("暂无玩家频道")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("创建一个频道，邀请附近的幸存者加入")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }
}

#Preview {
    ChannelListView()
        .background(ApocalypseTheme.background)
}
