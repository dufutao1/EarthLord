//
//  TradeMarketView.swift
//  EarthLord
//
//  交易市场页面
//  浏览和接受其他玩家的挂单
//

import SwiftUI

struct TradeMarketView: View {

    @StateObject private var tradeManager = TradeManager.shared

    /// 选中的挂单详情
    @State private var selectedOffer: TradeOffer?

    /// 显示详情页
    @State private var showDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if tradeManager.isLoading && tradeManager.availableOffers.isEmpty {
                    loadingView
                } else if tradeManager.availableOffers.isEmpty {
                    emptyView
                } else {
                    offersList
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            await tradeManager.loadAvailableOffers()
        }
        .onAppear {
            Task {
                await tradeManager.loadAvailableOffers()
            }
        }
        .sheet(isPresented: $showDetail) {
            if let offer = selectedOffer {
                TradeOfferDetailView(offer: offer)
            }
        }
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("搜索附近的交易...")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 空状态视图

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "storefront")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无可用的交易挂单")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("附近还没有其他玩家发布挂单\n试试自己发布一个吧")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)

            Button(action: {
                Task {
                    await tradeManager.loadAvailableOffers()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                    Text("刷新")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.primary.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 挂单列表

    private var offersList: some View {
        LazyVStack(spacing: 12) {
            ForEach(tradeManager.availableOffers) { offer in
                TradeOfferCard(
                    offer: offer,
                    isOwn: false,
                    onTap: {
                        selectedOffer = offer
                        showDetail = true
                    }
                )
            }
        }
    }
}

#Preview {
    TradeMarketView()
        .background(ApocalypseTheme.background)
}
