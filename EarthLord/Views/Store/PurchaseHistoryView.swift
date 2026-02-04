//
//  PurchaseHistoryView.swift
//  EarthLord
//
//  购买历史页面
//  Day 37: 查看购买记录
//

import SwiftUI

struct PurchaseHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var iapManager = IAPManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    if iapManager.purchaseHistory.isEmpty {
                        emptyView
                    } else {
                        historyListView
                    }
                }
            }
            .navigationTitle("购买历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .onAppear {
                Task {
                    await iapManager.loadPurchaseHistory()
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("暂无购买记录")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("购买物资包后，记录会显示在这里")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
    }

    // MARK: - 历史列表

    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(iapManager.purchaseHistory) { record in
                    PurchaseHistoryRow(record: record)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - 购买历史行

struct PurchaseHistoryRow: View {
    let record: PurchaseHistory

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // 主内容
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 14) {
                    // 图标
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ApocalypseTheme.success.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ApocalypseTheme.success)
                    }

                    // 内容
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.productName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text(record.formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    Spacer()

                    // 价格
                    Text(record.formattedPrice)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)

                    // 展开箭头
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(14)
            }
            .buttonStyle(PlainButtonStyle())

            // 展开的物品列表
            if isExpanded {
                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                VStack(alignment: .leading, spacing: 8) {
                    Text("获得物品")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(record.itemsReceived) { item in
                            ItemPreviewCell(itemId: item.itemId, quantity: item.quantity)
                        }
                    }
                }
                .padding(14)
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    PurchaseHistoryView()
}
