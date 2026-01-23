//
//  TradeHistoryView.swift
//  EarthLord
//
//  交易历史页面
//  查看已完成的交易记录和评价
//

import SwiftUI
import Supabase

struct TradeHistoryView: View {

    @StateObject private var tradeManager = TradeManager.shared

    /// 显示评价弹窗
    @State private var showRatingSheet = false
    @State private var historyToRate: TradeHistory?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if tradeManager.isLoading && tradeManager.tradeHistory.isEmpty {
                    loadingView
                } else if tradeManager.tradeHistory.isEmpty {
                    emptyView
                } else {
                    historyList
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            await tradeManager.loadTradeHistory()
        }
        .onAppear {
            Task {
                await tradeManager.loadTradeHistory()
            }
        }
        .sheet(isPresented: $showRatingSheet) {
            if let history = historyToRate {
                RatingSheetView(history: history)
            }
        }
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载交易历史...")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 空状态视图

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有交易记录")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("完成交易后会在这里显示记录")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 历史列表

    private var historyList: some View {
        LazyVStack(spacing: 12) {
            ForEach(tradeManager.tradeHistory) { history in
                TradeHistoryCard(
                    history: history,
                    onRate: {
                        historyToRate = history
                        showRatingSheet = true
                    }
                )
            }
        }
    }
}

// MARK: - 交易历史卡片

struct TradeHistoryCard: View {

    let history: TradeHistory
    var onRate: (() -> Void)?

    @StateObject private var inventoryManager = InventoryManager.shared

    /// 当前用户ID
    private var currentUserId: UUID? {
        supabase.auth.currentUser?.id
    }

    /// 用户在交易中的角色
    private var myRole: TradeRole? {
        guard let userId = currentUserId else { return nil }
        return history.role(for: userId)
    }

    /// 对方用户名
    private var counterpartyName: String {
        guard let userId = currentUserId else { return "未知" }
        return history.counterpartyUsername(for: userId) ?? "未知用户"
    }

    /// 我是否已评价
    private var hasRated: Bool {
        guard let userId = currentUserId else { return true }
        return history.hasRated(userId: userId)
    }

    /// 我给出的物品
    private var myGivenItems: [TradeItem] {
        if myRole == .seller {
            return history.items_exchanged.offered
        } else {
            return history.items_exchanged.requested
        }
    }

    /// 我获得的物品
    private var myReceivedItems: [TradeItem] {
        if myRole == .seller {
            return history.items_exchanged.requested
        } else {
            return history.items_exchanged.offered
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：对方信息 + 完成时间
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 14))
                    Text("与 @\(counterpartyName) 的交易")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text(formatDate(history.completed_at))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 交易内容
            VStack(alignment: .leading, spacing: 8) {
                // 我给出的
                HStack(alignment: .top, spacing: 8) {
                    Text("你给出")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.danger)
                        .frame(width: 44, alignment: .leading)

                    FlowLayout(spacing: 6) {
                        ForEach(myGivenItems) { item in
                            ItemBadge(item: item)
                        }
                    }
                }

                // 我获得的
                HStack(alignment: .top, spacing: 8) {
                    Text("你获得")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.success)
                        .frame(width: 44, alignment: .leading)

                    FlowLayout(spacing: 6) {
                        ForEach(myReceivedItems) { item in
                            ItemBadge(item: item)
                        }
                    }
                }
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 评价区域
            ratingsSection
        }
        .padding(14)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 评价区域

    private var ratingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 我的评价
            if hasRated {
                let myRating = myRole == .seller ? history.seller_rating : history.buyer_rating
                let myComment = myRole == .seller ? history.seller_comment : history.buyer_comment

                HStack(spacing: 6) {
                    Text("你的评价：")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    starRating(myRating ?? 0)

                    if let comment = myComment {
                        Text("「\(comment)」")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .lineLimit(1)
                    }
                }
            } else {
                Button(action: { onRate?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "star")
                            .font(.system(size: 12))
                        Text("去评价")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.primary.opacity(0.1))
                    .cornerRadius(6)
                }
            }

            // 对方评价
            let theirRating = myRole == .seller ? history.buyer_rating : history.seller_rating
            let theirComment = myRole == .seller ? history.buyer_comment : history.seller_comment

            if let rating = theirRating {
                HStack(spacing: 6) {
                    Text("对方评价：")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    starRating(rating)

                    if let comment = theirComment {
                        Text("「\(comment)」")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("对方尚未评价")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }

    // MARK: - 星星评分

    private func starRating(_ rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundColor(star <= rating ? .yellow : ApocalypseTheme.textMuted)
            }
        }
    }

    // MARK: - 格式化日期

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 评价弹窗

struct RatingSheetView: View {

    let history: TradeHistory

    @Environment(\.dismiss) private var dismiss
    @StateObject private var tradeManager = TradeManager.shared

    @State private var rating: Int = 0
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    /// 对方用户名
    private var counterpartyName: String {
        guard let userId = supabase.auth.currentUser?.id else { return "未知" }
        return history.counterpartyUsername(for: userId) ?? "未知用户"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 标题
                Text("评价与 @\(counterpartyName) 的交易")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 星星选择
                VStack(spacing: 12) {
                    Text("请给这次交易打分")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Button(action: { rating = star }) {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 32))
                                    .foregroundColor(star <= rating ? .yellow : ApocalypseTheme.textMuted)
                            }
                        }
                    }
                }

                // 评语输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("评语（可选）")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    TextField("写下你的评价...", text: $comment, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(8)
                        .lineLimit(3...5)
                }

                Spacer()

                // 提交按钮
                Button(action: submitRating) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(isSubmitting ? "提交中..." : "提交评价")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(rating > 0 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .cornerRadius(12)
                }
                .disabled(rating == 0 || isSubmitting)
            }
            .padding(20)
            .background(ApocalypseTheme.background)
            .navigationTitle("评价交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("评价失败", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 提交评价

    private func submitRating() {
        isSubmitting = true

        Task {
            do {
                try await tradeManager.rateTrade(
                    historyId: history.id,
                    rating: rating,
                    comment: comment.isEmpty ? nil : comment
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }

            isSubmitting = false
        }
    }
}

#Preview {
    TradeHistoryView()
        .background(ApocalypseTheme.background)
}
