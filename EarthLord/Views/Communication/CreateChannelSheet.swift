//
//  CreateChannelSheet.swift
//  EarthLord
//
//  创建频道弹窗
//  Day 33: 频道类型选择 + 表单验证 + 创建逻辑
//

import SwiftUI
import Supabase

struct CreateChannelSheet: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared

    var onCreated: (() -> Void)?

    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var selectedType: ChannelType = .public
    @State private var isCreating = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 频道类型选择
                    typeSelectionSection

                    // 频道名称
                    nameSection

                    // 频道描述
                    descriptionSection

                    // 创建按钮
                    createButton
                }
                .padding(20)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 频道类型选择

    private var typeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("频道类型")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(ChannelType.creatableTypes, id: \.self) { type in
                    Button(action: { selectedType = type }) {
                        HStack(spacing: 12) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 18))
                                .foregroundColor(selectedType == type ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                Text(type.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(ApocalypseTheme.textMuted)
                            }

                            Spacer()

                            if selectedType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(ApocalypseTheme.primary)
                            } else {
                                Image(systemName: "circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(ApocalypseTheme.textMuted)
                            }
                        }
                        .padding(12)
                        .background(
                            selectedType == type
                                ? ApocalypseTheme.primary.opacity(0.08)
                                : ApocalypseTheme.cardBackground
                        )
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    selectedType == type ? ApocalypseTheme.primary.opacity(0.3) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - 频道名称

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道名称")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                Text("\(channelName.count)/50")
                    .font(.system(size: 11))
                    .foregroundColor(
                        channelName.count > 50 ? ApocalypseTheme.danger : ApocalypseTheme.textMuted
                    )
            }

            TextField("输入频道名称（2-50字符）", text: $channelName)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)

            if !nameValidation.isValid && !channelName.isEmpty {
                Text(nameValidation.message)
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.danger)
            }
        }
    }

    // MARK: - 频道描述

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("频道描述（可选）")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("描述频道用途...", text: $channelDescription, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(3...5)
                .padding(12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
        }
    }

    // MARK: - 创建按钮

    private var createButton: some View {
        Button(action: createChannel) {
            HStack(spacing: 8) {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                }
                Text(isCreating ? "创建中..." : "创建频道")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canCreate ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            .cornerRadius(12)
        }
        .disabled(!canCreate || isCreating)
    }

    // MARK: - 验证

    private var nameValidation: (isValid: Bool, message: String) {
        let trimmed = channelName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return (false, "请输入频道名称")
        } else if trimmed.count < 2 {
            return (false, "名称至少2个字符")
        } else if trimmed.count > 50 {
            return (false, "名称最多50个字符")
        }
        return (true, "")
    }

    private var canCreate: Bool {
        nameValidation.isValid
    }

    // MARK: - 创建频道

    private func createChannel() {
        guard let userId = supabase.auth.currentUser?.id else { return }
        guard canCreate else { return }

        isCreating = true

        let trimmedName = channelName.trimmingCharacters(in: .whitespaces)
        let trimmedDesc = channelDescription.trimmingCharacters(in: .whitespaces)

        Task {
            let success = await communicationManager.createChannel(
                userId: userId,
                type: selectedType,
                name: trimmedName,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc
            )

            isCreating = false

            if success {
                onCreated?()
                dismiss()
            }
        }
    }
}

#Preview {
    CreateChannelSheet()
}
