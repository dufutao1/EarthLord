//
//  TerritoryTabView.swift
//  EarthLord
//
//  领地管理页面
//  显示我的领地列表和统计信息
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - 状态

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 是否正在加载
    @State private var isLoading: Bool = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 选中的领地（用于弹出详情页）
    @State private var selectedTerritory: Territory?

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isLoading && myTerritories.isEmpty {
                    // 加载中
                    ProgressView("加载中...")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    territoryListView
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(ApocalypseTheme.background, for: .navigationBar)
            .refreshable {
                await loadMyTerritories()
            }
            .onAppear {
                Task {
                    await loadMyTerritories()
                }
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(territory: territory) {
                    // 删除成功后刷新列表
                    Task {
                        await loadMyTerritories()
                    }
                }
            }
            // 监听领地更新通知（重命名等操作后刷新列表）
            .onReceive(NotificationCenter.default.publisher(for: .territoryUpdated)) { _ in
                Task {
                    await loadMyTerritories()
                }
            }
        }
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有领地")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("去地图页面圈一块地吧！")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding()
    }

    // MARK: - 领地列表视图

    private var territoryListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 统计信息卡片
                statisticsCard

                // 领地卡片列表
                ForEach(myTerritories) { territory in
                    TerritoryCard(territory: territory)
                        .onTapGesture {
                            selectedTerritory = territory
                        }
                }
            }
            .padding()
        }
    }

    // MARK: - 统计信息卡片

    private var statisticsCard: some View {
        HStack(spacing: 20) {
            // 领地数量
            VStack(spacing: 4) {
                Text("\(myTerritories.count)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.primary)
                Text("领地数量")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)
                .background(ApocalypseTheme.textMuted)

            // 总面积
            VStack(spacing: 4) {
                Text(formattedTotalArea)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.success)
                Text("总面积")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 格式化总面积
    private var formattedTotalArea: String {
        let total = myTerritories.reduce(0) { $0 + $1.area }
        if total >= 1_000_000 {
            return String(format: "%.2f km²", total / 1_000_000)
        } else if total >= 1000 {
            return String(format: "%.1f k㎡", total / 1000)
        } else {
            return String(format: "%.0f m²", total)
        }
    }

    // MARK: - 方法

    /// 加载我的领地
    private func loadMyTerritories() async {
        isLoading = true
        errorMessage = nil

        do {
            myTerritories = try await TerritoryManager.shared.loadMyTerritories()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [领地Tab] 加载失败: \(error)")
        }

        isLoading = false
    }
}

// MARK: - 领地卡片

struct TerritoryCard: View {
    let territory: Territory

    var body: some View {
        HStack(spacing: 12) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "flag.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            // 中间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(territory.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 12) {
                    // 面积
                    Label(territory.formattedArea, systemImage: "square.dashed")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 时间
                    Label(territory.formattedDate, systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 右侧箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    TerritoryTabView()
}
