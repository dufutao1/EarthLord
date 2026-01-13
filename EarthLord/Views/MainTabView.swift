//
//  MainTabView.swift
//  EarthLord
//
//  Created by taozi on 2025/12/23.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    init() {
        // 配置 TabBar 外观（深色半透明毛玻璃效果）
        configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("地图")
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text("领地")
                }
                .tag(1)

            ResourcesTabView()
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("资源")
                }
                .tag(2)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("个人")
                }
                .tag(3)

            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("更多")
                }
                .tag(4)
        }
        .tint(ApocalypseTheme.primary)
    }

    /// 配置 TabBar 外观（深色半透明毛玻璃效果）
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()

        // 关键！使用透明背景 + 毛玻璃效果
        appearance.configureWithTransparentBackground()

        // 只设置毛玻璃效果，不设置 backgroundColor（否则会覆盖毛玻璃）
        appearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialDark)

        // 设置一个非常淡的背景色叠加（不会完全覆盖毛玻璃）
        appearance.backgroundColor = UIColor(white: 0.0, alpha: 0.2)

        // 顶部分隔线 - 细微的白色高光
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)

        // 选中状态 - 橙色
        let selectedColor = UIColor(ApocalypseTheme.primary)
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        // 未选中状态 - 浅灰色
        let normalColor = UIColor(white: 0.65, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        // 应用外观
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // 关键！必须设置为半透明
        UITabBar.appearance().isTranslucent = true

        // 清除默认背景图片（确保毛玻璃效果可见）
        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().shadowImage = UIImage()
    }
}

#Preview {
    MainTabView()
}
