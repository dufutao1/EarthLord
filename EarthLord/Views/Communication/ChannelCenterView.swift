//
//  ChannelCenterView.swift
//  EarthLord
//
//  频道中心页面
//  Day 33: 我的频道 + 发现频道 Tab 切换
//

import SwiftUI
import Supabase

struct ChannelCenterView: View {

    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            topBar

            // Tab 切换栏
            tabSelector

            // 内容区域
            if selectedTab == 0 {
                myChannelsView
            } else {
                discoverChannelsView
            }
        }
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateChannelSheet(onCreated: {
                loadData()
            })
        }
        .sheet(item: $selectedChannel) { channel in
            ChannelDetailView(channel: channel, onChanged: {
                loadData()
            })
        }
    }

    // MARK: - 加载数据

    private func loadData() {
        if let userId = supabase.auth.currentUser?.id {
            Task {
                await communicationManager.loadPublicChannels()
                await communicationManager.loadSubscribedChannels(userId: userId)
            }
        }
    }

    // MARK: - 顶部操作栏

    private var topBar: some View {
        HStack {
            Text("频道中心")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Button(action: { showCreateSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("创建")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Tab 切换栏

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "我的频道", index: 0)
            tabButton(title: "发现频道", index: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                Rectangle()
                    .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 我的频道

    private var myChannelsView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 官方频道区域
                officialChannelsSection

                // 已订阅的玩家频道
                if communicationManager.subscribedChannels.isEmpty {
                    emptyStateView(
                        icon: "person.2.slash",
                        title: "暂无订阅频道",
                        subtitle: "去「发现频道」看看，或创建自己的频道"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("已订阅")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .padding(.leading, 4)

                        ForEach(communicationManager.subscribedChannels) { sub in
                            channelRow(channel: sub.channel, isSubscribed: true)
                                .onTapGesture {
                                    selectedChannel = sub.channel
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            loadData()
        }
    }

    // MARK: - 发现频道

    private var discoverChannelsView: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)

                TextField("搜索频道...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // 频道列表
            ScrollView {
                VStack(spacing: 10) {
                    let filtered = filteredChannels
                    if filtered.isEmpty {
                        emptyStateView(
                            icon: "dot.radiowaves.left.and.right",
                            title: "暂无频道",
                            subtitle: "成为第一个创建频道的人吧"
                        )
                    } else {
                        ForEach(filtered) { channel in
                            channelRow(
                                channel: channel,
                                isSubscribed: communicationManager.isSubscribed(channelId: channel.id)
                            )
                            .onTapGesture {
                                selectedChannel = channel
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .refreshable {
                loadData()
            }
        }
    }

    private var filteredChannels: [CommunicationChannel] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return communicationManager.channels
        }
        let query = searchText.lowercased()
        return communicationManager.channels.filter {
            $0.name.lowercased().contains(query) ||
            $0.channelCode.lowercased().contains(query) ||
            ($0.description?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: - 官方频道区域

    private var officialChannelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.warning)
                Text("官方频道")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.leading, 4)

            NavigationLink(destination: OfficialChannelDetailView(channelName: "全区广播", channelIcon: "megaphone.fill")) {
                officialChannelRow(name: "全区广播", icon: "megaphone.fill", color: .orange)
            }

            NavigationLink(destination: OfficialChannelDetailView(channelName: "交易频道", channelIcon: "arrow.left.arrow.right")) {
                officialChannelRow(name: "交易频道", icon: "arrow.left.arrow.right", color: .green)
            }

            NavigationLink(destination: OfficialChannelDetailView(channelName: "求助频道", channelIcon: "exclamationmark.triangle.fill")) {
                officialChannelRow(name: "求助频道", icon: "exclamationmark.triangle.fill", color: .red)
            }
        }
    }

    private func officialChannelRow(name: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("官方")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.warning)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(10)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    // MARK: - 频道行

    private func channelRow(channel: CommunicationChannel, isSubscribed: Bool) -> some View {
        HStack(spacing: 12) {
            // 频道图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(channelIconColor(channel.channelType).opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(channelIconColor(channel.channelType))
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(channel.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if isSubscribed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.success)
                    }
                }

                HStack(spacing: 8) {
                    Text(channel.channelCode)
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("·")
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text("\(channel.memberCount) 人")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    // MARK: - 空状态

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - 辅助

    private func channelIconColor(_ type: ChannelType) -> Color {
        switch type {
        case .official: return ApocalypseTheme.warning
        case .public: return ApocalypseTheme.info
        case .walkie: return ApocalypseTheme.primary
        case .camp: return ApocalypseTheme.success
        case .satellite: return ApocalypseTheme.danger
        }
    }
}

#Preview {
    NavigationStack {
        ChannelCenterView()
            .background(ApocalypseTheme.background)
    }
}
