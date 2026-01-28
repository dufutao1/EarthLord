//
//  ChannelDetailView.swift
//  EarthLord
//
//  频道详情页
//  Day 33: 频道信息 + 订阅/取消订阅 + 删除（创建者）
//

import SwiftUI
import Supabase

struct ChannelDetailView: View {

    let channel: CommunicationChannel
    var onChanged: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var isProcessing = false
    @State private var showDeleteConfirm = false

    private var currentUserId: UUID? {
        supabase.auth.currentUser?.id
    }

    private var isCreator: Bool {
        currentUserId == channel.creatorId
    }

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 频道头像 + 名称
                    headerSection

                    // 频道信息卡片
                    infoCard

                    // 频道描述
                    if let desc = channel.description, !desc.isEmpty {
                        descriptionSection(desc)
                    }

                    // 操作按钮
                    actionSection

                    // 删除按钮（仅创建者）
                    if isCreator {
                        deleteSection
                    }
                }
                .padding(20)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("频道详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteChannel()
                }
            } message: {
                Text("删除后无法恢复，频道内所有消息也将被删除。确定要删除「\(channel.name)」吗？")
            }
        }
    }

    // MARK: - 频道头像 + 名称

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(channelIconColor.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 30))
                    .foregroundColor(channelIconColor)
            }

            Text(channel.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 频道码
            Text(channel.channelCode)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 订阅状态标签
            if isSubscribed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("已订阅")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.success)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.success.opacity(0.15))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 信息卡片

    private var infoCard: some View {
        VStack(spacing: 12) {
            infoRow(label: "类型", value: channel.channelType.displayName, icon: "tag.fill")
            Divider().background(ApocalypseTheme.textMuted.opacity(0.3))
            infoRow(label: "成员", value: "\(channel.memberCount) 人", icon: "person.2.fill")
            Divider().background(ApocalypseTheme.textMuted.opacity(0.3))
            infoRow(label: "创建时间", value: formatDate(channel.createdAt), icon: "calendar")
            if isCreator {
                Divider().background(ApocalypseTheme.textMuted.opacity(0.3))
                infoRow(label: "身份", value: "创建者", icon: "crown.fill")
            }
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - 描述

    private func descriptionSection(_ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("频道介绍")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(desc)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 操作按钮

    private var actionSection: some View {
        Group {
            if isSubscribed {
                // 已订阅 → 取消订阅
                Button(action: unsubscribe) {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView().tint(ApocalypseTheme.textPrimary)
                        } else {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 16))
                        }
                        Text(isProcessing ? "处理中..." : "取消订阅")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(isProcessing)
            } else {
                // 未订阅 → 订阅
                Button(action: subscribe) {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16))
                        }
                        Text(isProcessing ? "处理中..." : "订阅频道")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
            }
        }
    }

    // MARK: - 删除区域

    private var deleteSection: some View {
        VStack(spacing: 8) {
            Divider().background(ApocalypseTheme.textMuted.opacity(0.3))

            Button(action: { showDeleteConfirm = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                    Text("删除频道")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 操作方法

    private func subscribe() {
        guard let userId = currentUserId else { return }
        isProcessing = true
        Task {
            let success = await communicationManager.subscribeToChannel(userId: userId, channelId: channel.id)
            isProcessing = false
            if success {
                onChanged?()
            }
        }
    }

    private func unsubscribe() {
        guard let userId = currentUserId else { return }
        isProcessing = true
        Task {
            let success = await communicationManager.unsubscribeFromChannel(userId: userId, channelId: channel.id)
            isProcessing = false
            if success {
                onChanged?()
            }
        }
    }

    private func deleteChannel() {
        guard let userId = currentUserId else { return }
        isProcessing = true
        Task {
            let success = await communicationManager.deleteChannel(userId: userId, channelId: channel.id)
            isProcessing = false
            if success {
                onChanged?()
                dismiss()
            }
        }
    }

    // MARK: - 辅助

    private var channelIconColor: Color {
        switch channel.channelType {
        case .official: return ApocalypseTheme.warning
        case .public: return ApocalypseTheme.info
        case .walkie: return ApocalypseTheme.primary
        case .camp: return ApocalypseTheme.success
        case .satellite: return ApocalypseTheme.danger
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ChannelDetailView(
        channel: CommunicationChannel(
            id: UUID(),
            creatorId: UUID(),
            channelType: .public,
            channelCode: "PUB-A3F2K9",
            name: "测试频道",
            description: "这是一个测试频道",
            isActive: true,
            memberCount: 5,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
