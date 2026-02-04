//
//  UnboxingAnimationView.swift
//  EarthLord
//
//  开箱动画页面
//  Day 37: 购买后的开箱展示
//

import SwiftUI

struct UnboxingAnimationView: View {
    let product: IAPProduct
    let items: [UnboxedItem]

    @StateObject private var iapManager = IAPManager.shared

    @State private var phase: AnimationPhase = .boxAppear
    @State private var currentItemIndex = 0
    @State private var showAllItems = false

    enum AnimationPhase {
        case boxAppear      // 箱子出现
        case boxOpen        // 箱子打开
        case itemsReveal    // 物品展示
        case summary        // 结算页面
    }

    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // 根据阶段显示不同内容
                switch phase {
                case .boxAppear, .boxOpen:
                    boxView

                case .itemsReveal:
                    itemRevealView

                case .summary:
                    summaryView
                }

                Spacer()

                // 跳过/确认按钮
                bottomButton
            }
            .padding(20)
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - 箱子视图

    private var boxView: some View {
        VStack(spacing: 20) {
            ZStack {
                // 光效背景
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [product.tierColor.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .scaleEffect(phase == .boxOpen ? 1.5 : 1)
                    .animation(.easeInOut(duration: 0.5), value: phase)

                // 箱子图标
                Image(systemName: phase == .boxOpen ? "shippingbox.and.arrow.backward.fill" : product.tierIcon)
                    .font(.system(size: 100))
                    .foregroundColor(product.tierColor)
                    .scaleEffect(phase == .boxAppear ? 0.5 : 1)
                    .opacity(phase == .boxAppear ? 0 : 1)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: phase)
            }

            Text(product.name)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .opacity(phase == .boxAppear ? 0 : 1)
                .animation(.easeIn(duration: 0.3), value: phase)
        }
    }

    // MARK: - 物品展示视图

    private var itemRevealView: some View {
        VStack(spacing: 20) {
            // 当前展示的物品
            if currentItemIndex < items.count {
                let item = items[currentItemIndex]

                VStack(spacing: 16) {
                    // 光效
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [item.rarityColor.opacity(0.4), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)

                        // 物品图标
                        Text(item.itemIcon)
                            .font(.system(size: 80))
                    }

                    // 物品名称
                    Text(item.itemName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    // 数量
                    Text("x\(item.quantity)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(item.rarityColor)

                    // 稀有度标签
                    Text(item.rarity.rawValue.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(item.rarityColor)
                        .cornerRadius(4)
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
            }

            // 进度指示
            HStack(spacing: 4) {
                ForEach(0..<items.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentItemIndex ? product.tierColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)
        }
    }

    // MARK: - 结算视图

    private var summaryView: some View {
        VStack(spacing: 20) {
            Text("恭喜获得!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // 物品网格
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(items) { item in
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(item.rarityColor.opacity(0.2))
                                    .frame(width: 70, height: 70)

                                Text(item.itemIcon)
                                    .font(.system(size: 32))
                            }

                            Text(item.itemName)
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text("x\(item.quantity)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(item.rarityColor)
                        }
                    }
                }
            }
            .frame(maxHeight: 400)

            // 提示
            Text("物品已发送到邮箱，请前往领取")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    // MARK: - 底部按钮

    private var bottomButton: some View {
        Button(action: handleButtonTap) {
            Text(buttonText)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(product.tierColor)
                .cornerRadius(12)
        }
    }

    private var buttonText: String {
        switch phase {
        case .boxAppear, .boxOpen:
            return "跳过"
        case .itemsReveal:
            return currentItemIndex < items.count - 1 ? "下一个" : "查看全部"
        case .summary:
            return "确认"
        }
    }

    // MARK: - 动画控制

    private func startAnimation() {
        // 箱子出现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                phase = .boxOpen
            }
        }

        // 箱子打开
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                phase = .itemsReveal
            }
            startItemReveal()
        }
    }

    private func startItemReveal() {
        guard currentItemIndex < items.count else {
            withAnimation {
                phase = .summary
            }
            return
        }

        let item = items[currentItemIndex]
        let delay = item.animationDelay

        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.5) {
            // 自动下一个（如果是普通物品）
            if item.rarity == .common && currentItemIndex < items.count - 1 {
                withAnimation {
                    currentItemIndex += 1
                }
                startItemReveal()
            }
        }
    }

    private func handleButtonTap() {
        switch phase {
        case .boxAppear, .boxOpen:
            // 跳过到结算
            withAnimation {
                phase = .summary
            }

        case .itemsReveal:
            if currentItemIndex < items.count - 1 {
                withAnimation {
                    currentItemIndex += 1
                }
                startItemReveal()
            } else {
                withAnimation {
                    phase = .summary
                }
            }

        case .summary:
            // 关闭
            iapManager.closeUnboxing()
        }
    }
}

#Preview {
    UnboxingAnimationView(
        product: IAPProduct(
            id: "test",
            name: "测试物资包",
            description: "测试",
            tier: 2,
            priceCny: 18,
            priceUsd: 2.99,
            iconName: nil,
            contents: [],
            randomRewards: nil,
            randomPickCount: 0,
            firstPurchaseBonus: nil,
            isActive: true,
            sortOrder: 0
        ),
        items: [
            UnboxedItem(itemId: "test1", itemName: "罐头", itemIcon: "🥫", quantity: 5, rarity: ItemRarity.common),
            UnboxedItem(itemId: "test2", itemName: "医疗包", itemIcon: "💊", quantity: 2, rarity: ItemRarity.rare),
            UnboxedItem(itemId: "test3", itemName: "太阳能充电器", itemIcon: "🔋", quantity: 1, rarity: ItemRarity.epic)
        ]
    )
}
