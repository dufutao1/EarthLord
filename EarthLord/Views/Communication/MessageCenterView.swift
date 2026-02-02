//
//  MessageCenterView.swift
//  EarthLord
//
//  消息中心页面
//  Day 36-C: 显示所有订阅频道的消息聚合
//

import SwiftUI
import Auth

struct MessageCenterView: View {
    @StateObject private var communicationManager = CommunicationManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var isLoading = true
    @State private var selectedChannel: CommunicationChannel?
    @State private var showingChat = false
    @State private var showingOfficialChannel = false

    private var summaries: [CommunicationManager.ChannelSummary] {
        communicationManager.getChannelSummaries()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 标题栏
                    headerView

                    // 内容区
                    if isLoading {
                        loadingView
                    } else if summaries.isEmpty {
                        emptyStateView
                    } else {
                        messageListView
                    }
                }
            }
            .onAppear {
                loadData()
            }
            .navigationDestination(isPresented: $showingChat) {
                if let channel = selectedChannel {
                    ChannelChatView(channel: channel)
                }
            }
            .navigationDestination(isPresented: $showingOfficialChannel) {
                if let channel = selectedChannel {
                    OfficialChannelDetailView(channel: channel)
                }
            }
        }
    }

    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            Text("消息中心")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.text)

            Spacer()

            // 刷新按钮
            Button(action: { loadData() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 加载中
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.secondaryText)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.secondaryText.opacity(0.5))

            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.text)

            Text("订阅频道后，消息会显示在这里")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.secondaryText)

            Spacer()
        }
    }

    // MARK: - 消息列表
    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(summaries) { summary in
                    Button(action: {
                        selectedChannel = summary.channel
                        // 根据频道类型选择不同的详情页
                        if summary.channel.channelType == .official {
                            showingOfficialChannel = true
                        } else {
                            showingChat = true
                        }
                    }) {
                        MessageRowView(summary: summary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 方法
    private func loadData() {
        isLoading = true

        Task {
            if let userId = authManager.currentUser?.id {
                await communicationManager.loadSubscribedChannels(userId: userId)
                await communicationManager.loadAllChannelLatestMessages()
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }
}
