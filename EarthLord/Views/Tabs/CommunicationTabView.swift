//
//  CommunicationTabView.swift
//  EarthLord
//
//  通讯中心主页面
//  Day 32-B: 包含消息/频道/呼叫/设备四个子导航
//

import SwiftUI
import Supabase

struct CommunicationTabView: View {

    // MARK: - 状态

    @StateObject private var communicationManager = CommunicationManager.shared
    @State private var selectedSection: CommunicationSection = .messages

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 当前设备指示条
                    currentDeviceBanner

                    // 子导航选择器
                    sectionSelector

                    // 内容区域
                    contentView
                }
            }
            .navigationTitle("通讯")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            if let userId = supabase.auth.currentUser?.id {
                Task {
                    await communicationManager.loadDevices(userId: userId)
                }
            }
        }
    }

    // MARK: - 当前设备指示条

    private var currentDeviceBanner: some View {
        let deviceType = communicationManager.getCurrentDeviceType()

        return HStack(spacing: 8) {
            Image(systemName: deviceType.iconName)
                .font(.system(size: 14))
            Text("当前设备：\(deviceType.displayName)")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Text(deviceType.rangeText)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .foregroundColor(ApocalypseTheme.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ApocalypseTheme.primary.opacity(0.1))
    }

    // MARK: - 子导航选择器

    private var sectionSelector: some View {
        HStack(spacing: 0) {
            ForEach(CommunicationSection.allCases, id: \.self) { section in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: section.iconName)
                            .font(.system(size: 18))
                        Text(section.rawValue)
                            .font(.system(size: 11, weight: selectedSection == section ? .semibold : .medium))
                    }
                    .foregroundColor(
                        selectedSection == section
                            ? ApocalypseTheme.primary
                            : ApocalypseTheme.textSecondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedSection == section
                            ? ApocalypseTheme.primary.opacity(0.15)
                            : Color.clear
                    )
                    .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .messages:
            MessageCenterView()
        case .channels:
            ChannelCenterView()
        case .call:
            PTTCallView()
        case .devices:
            DeviceManagementView()
        }
    }
}

#Preview {
    CommunicationTabView()
}
