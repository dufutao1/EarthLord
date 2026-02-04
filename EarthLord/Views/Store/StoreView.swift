//
//  StoreView.swift
//  EarthLord
//
//  商城页面
//  Day 37: 物资包商城
//

import SwiftUI

struct StoreView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var iapManager = IAPManager.shared

    @State private var showMailbox = false
    @State private var showHistory = false
    @State private var selectedProduct: IAPProduct?

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶部工具栏
                    topToolbar

                    // 产品列表
                    if iapManager.isLoading {
                        loadingView
                    } else if iapManager.products.isEmpty {
                        emptyView
                    } else {
                        productListView
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await iapManager.loadProducts()
                    await iapManager.loadMailbox()
                }
            }
            .sheet(isPresented: $showMailbox) {
                MailboxView()
            }
            .sheet(isPresented: $showHistory) {
                PurchaseHistoryView()
            }
            .sheet(item: $selectedProduct) { product in
                ProductDetailSheet(product: product)
            }
            .fullScreenCover(isPresented: $iapManager.showUnboxing) {
                if let product = iapManager.currentUnboxingProduct {
                    UnboxingAnimationView(
                        product: product,
                        items: iapManager.unboxedItems
                    )
                }
            }
        }
    }

    // MARK: - 顶部工具栏

    private var topToolbar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Text("末日商店")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 邮箱按钮
            Button(action: { showMailbox = true }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.primary)

                    // 未读数量
                    if iapManager.unclaimedCount > 0 {
                        Text("\(iapManager.unclaimedCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }
            }

            // 购买历史
            Button(action: { showHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.leading, 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 加载中

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - 空状态

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bag.fill")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)
            Text("暂无商品")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Spacer()
        }
    }

    // MARK: - 产品列表

    private var productListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 横幅提示
                bannerView

                // 产品网格
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(iapManager.products) { product in
                        ProductCard(product: product) {
                            selectedProduct = product
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - 横幅提示

    private var bannerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("末日物资补给站")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("购买物资包，助你在末日中生存")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [ApocalypseTheme.primary.opacity(0.2), ApocalypseTheme.cardBackground],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
    }
}

// MARK: - 产品卡片

struct ProductCard: View {
    let product: IAPProduct
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(product.tierColor.opacity(0.15))
                        .frame(width: 70, height: 70)

                    Image(systemName: product.tierIcon)
                        .font(.system(size: 32))
                        .foregroundColor(product.tierColor)
                }

                // 名称
                Text(product.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                // 物品数量
                Text("\(product.contents.reduce(0) { $0 + $1.quantity }) 个物品")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                // 价格按钮
                Text(product.formattedPrice)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(product.tierColor)
                    .cornerRadius(8)
            }
            .padding(12)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(product.tierColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 产品详情弹窗

struct ProductDetailSheet: View {
    let product: IAPProduct
    @Environment(\.dismiss) private var dismiss
    @StateObject private var iapManager = IAPManager.shared
    @StateObject private var inventoryManager = InventoryManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 产品图标
                        ZStack {
                            Circle()
                                .fill(product.tierColor.opacity(0.15))
                                .frame(width: 100, height: 100)

                            Image(systemName: product.tierIcon)
                                .font(.system(size: 45))
                                .foregroundColor(product.tierColor)
                        }
                        .padding(.top, 20)

                        // 产品名称
                        Text(product.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        // 产品描述
                        if let desc = product.description {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        // 固定内容
                        contentSection

                        // 随机奖励
                        if let randomRewards = product.randomRewards, !randomRewards.isEmpty {
                            randomRewardSection(randomRewards)
                        }

                        // 购买按钮
                        purchaseButton
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("产品详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 固定内容

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("包含内容")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .padding(.horizontal, 16)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(product.contents) { item in
                    ItemPreviewCell(itemId: item.itemId, quantity: item.quantity)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - 随机奖励

    private func randomRewardSection(_ rewards: [RandomReward]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("随机奖励")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("抽取 \(product.randomPickCount) 个")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(rewards) { reward in
                    VStack(spacing: 4) {
                        ItemPreviewCell(itemId: reward.itemId, quantity: reward.quantity)
                        Text(reward.formattedProbability)
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.warning)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - 购买按钮

    private var purchaseButton: some View {
        Button(action: {
            Task {
                let success = await iapManager.purchase(product)
                if success {
                    dismiss()
                }
            }
        }) {
            HStack {
                if iapManager.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "cart.fill")
                    Text("购买 \(product.formattedPrice)")
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(iapManager.isPurchasing ? Color.gray : product.tierColor)
            .cornerRadius(12)
        }
        .disabled(iapManager.isPurchasing)
        .padding(.horizontal, 16)
    }
}

// MARK: - 物品预览单元格

struct ItemPreviewCell: View {
    let itemId: String
    let quantity: Int

    @StateObject private var inventoryManager = InventoryManager.shared

    private var itemDefinition: ItemDefinitionDB? {
        inventoryManager.getItemDefinition(by: itemId)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ApocalypseTheme.background)
                    .frame(width: 50, height: 50)

                if let def = itemDefinition {
                    Text(def.icon)
                        .font(.system(size: 24))
                }
            }

            if let def = itemDefinition {
                Text(def.name)
                    .font(.system(size: 10))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(1)
            }

            Text("x\(quantity)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(8)
    }
}

#Preview {
    StoreView()
}
