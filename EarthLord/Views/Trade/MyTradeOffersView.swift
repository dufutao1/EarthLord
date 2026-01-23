//
//  MyTradeOffersView.swift
//  EarthLord
//
//  我的交易挂单页面
//  显示和管理自己发布的挂单
//

import SwiftUI

struct MyTradeOffersView: View {

    @Binding var showCreateOffer: Bool

    @StateObject private var tradeManager = TradeManager.shared

    /// 显示取消确认弹窗
    @State private var showCancelAlert = false
    @State private var offerToCancel: TradeOffer?

    /// 操作中状态
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 发布新挂单按钮
                createOfferButton

                // 挂单列表
                if tradeManager.isLoading && tradeManager.myOffers.isEmpty {
                    loadingView
                } else if tradeManager.myOffers.isEmpty {
                    emptyView
                } else {
                    offersList
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            await tradeManager.loadMyOffers()
        }
        .alert("取消挂单", isPresented: $showCancelAlert) {
            Button("取消", role: .cancel) {}
            Button("确认取消", role: .destructive) {
                if let offer = offerToCancel {
                    cancelOffer(offer)
                }
            }
        } message: {
            Text("确定要取消这个挂单吗？物品将退还到你的背包。")
        }
    }

    // MARK: - 发布新挂单按钮

    private var createOfferButton: some View {
        Button(action: { showCreateOffer = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("发布新挂单")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载中...")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 空状态视图

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag.slash")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有发布过挂单")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("点击上方按钮发布你的第一个交易挂单")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 挂单列表

    private var offersList: some View {
        LazyVStack(spacing: 12) {
            ForEach(tradeManager.myOffers) { offer in
                TradeOfferCard(
                    offer: offer,
                    isOwn: true,
                    onCancel: {
                        offerToCancel = offer
                        showCancelAlert = true
                    }
                )
                .opacity(isProcessing && offerToCancel?.id == offer.id ? 0.5 : 1)
            }
        }
    }

    // MARK: - 取消挂单

    private func cancelOffer(_ offer: TradeOffer) {
        isProcessing = true

        Task {
            do {
                try await tradeManager.cancelTradeOffer(offerId: offer.id)
            } catch {
                print("❌ 取消挂单失败: \(error)")
            }

            isProcessing = false
            offerToCancel = nil
        }
    }
}

#Preview {
    MyTradeOffersView(showCreateOffer: .constant(false))
        .background(ApocalypseTheme.background)
}
