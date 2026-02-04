//
//  MailboxView.swift
//  EarthLord
//
//  邮箱页面
//  Day 37: 领取购买的物资
//

import SwiftUI

struct MailboxView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var iapManager = IAPManager.shared

    @State private var isClaimingAll = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    if iapManager.mailboxItems.isEmpty {
                        emptyView
                    } else {
                        mailboxListView
                    }
                }
            }
            .navigationTitle("邮箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !iapManager.mailboxItems.isEmpty {
                        Button("全部领取") {
                            claimAll()
                        }
                        .foregroundColor(ApocalypseTheme.primary)
                        .disabled(isClaimingAll)
                    }
                }
            }
            .onAppear {
                Task {
                    await iapManager.loadMailbox()
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("邮箱空空如也")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("购买物资包后，物品会发送到这里")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - 邮箱列表

    private var mailboxListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(iapManager.mailboxItems) { item in
                    MailboxItemRow(item: item)
                }
            }
            .padding(16)
        }
    }

    // MARK: - 全部领取

    private func claimAll() {
        isClaimingAll = true

        Task {
            for item in iapManager.mailboxItems {
                let _ = await iapManager.claimMailboxItem(item)
            }
            isClaimingAll = false
        }
    }
}

// MARK: - 邮箱物品行

struct MailboxItemRow: View {
    let item: MailboxItem
    @StateObject private var iapManager = IAPManager.shared

    @State private var isClaiming = false
    @State private var showError = false

    var body: some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.primary.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: sourceIcon)
                    .font(.system(size: 22))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("包含 \(item.totalItemCount) 个物品")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(item.formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            // 领取按钮
            Button(action: claim) {
                if isClaiming {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 60, height: 32)
                } else {
                    Text("领取")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 32)
                }
            }
            .background(ApocalypseTheme.primary)
            .cornerRadius(8)
            .disabled(isClaiming)
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .alert("领取失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(iapManager.errorMessage ?? "请稍后重试")
        }
    }

    private var sourceIcon: String {
        switch item.sourceType {
        case "iap_purchase": return "shippingbox.fill"
        case "system_reward": return "gift.fill"
        case "event": return "star.fill"
        default: return "envelope.fill"
        }
    }

    private func claim() {
        isClaiming = true

        Task {
            let success = await iapManager.claimMailboxItem(item)
            isClaiming = false

            if !success {
                showError = true
            }
        }
    }
}

#Preview {
    MailboxView()
}
