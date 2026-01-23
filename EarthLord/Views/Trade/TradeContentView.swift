//
//  TradeContentView.swift
//  EarthLord
//
//  交易系统主内容视图
//  包含我的挂单、交易市场、交易历史三个分页
//

import SwiftUI

/// 交易分页类型
enum TradeTab: Int, CaseIterable {
    case myOffers = 0    // 我的挂单
    case market = 1      // 交易市场
    case history = 2     // 交易历史

    var title: String {
        switch self {
        case .myOffers: return "我的挂单"
        case .market: return "市场"
        case .history: return "历史"
        }
    }

    var icon: String {
        switch self {
        case .myOffers: return "tag.fill"
        case .market: return "storefront.fill"
        case .history: return "clock.fill"
        }
    }
}

struct TradeContentView: View {

    // MARK: - 状态

    @StateObject private var tradeManager = TradeManager.shared

    /// 当前选中的分页
    @State private var selectedTab: TradeTab = .myOffers

    /// 显示发布挂单页面
    @State private var showCreateOffer = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部分页选择器
            tabSelector

            // 内容区域
            TabView(selection: $selectedTab) {
                // 我的挂单
                MyTradeOffersView(showCreateOffer: $showCreateOffer)
                    .tag(TradeTab.myOffers)

                // 交易市场
                TradeMarketView()
                    .tag(TradeTab.market)

                // 交易历史
                TradeHistoryView()
                    .tag(TradeTab.history)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .sheet(isPresented: $showCreateOffer) {
            CreateTradeOfferView()
        }
        .onAppear {
            Task {
                await tradeManager.loadMyOffers()
            }
        }
    }

    // MARK: - 分页选择器

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(TradeTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        Text(tab.title)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                    }
                    .foregroundColor(
                        selectedTab == tab
                            ? ApocalypseTheme.textPrimary
                            : ApocalypseTheme.textSecondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab
                            ? ApocalypseTheme.primary.opacity(0.2)
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
}

#Preview {
    TradeContentView()
}
