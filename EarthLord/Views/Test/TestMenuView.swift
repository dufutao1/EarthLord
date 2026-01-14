//
//  TestMenuView.swift
//  EarthLord
//
//  测试模块入口菜单
//  提供各种测试功能的入口
//

import SwiftUI

/// 测试模块入口菜单
struct TestMenuView: View {

    var body: some View {
        List {
            // Supabase 连接测试
            NavigationLink {
                SupabaseTestView()
            } label: {
                testMenuItem(
                    icon: "server.rack",
                    title: "Supabase 连接测试",
                    description: "测试数据库连接和认证功能"
                )
            }

            // 圈地功能测试
            NavigationLink {
                TerritoryTestView()
            } label: {
                testMenuItem(
                    icon: "map.fill",
                    title: "圈地功能测试",
                    description: "查看圈地追踪的实时日志"
                )
            }

            // 探索功能测试
            NavigationLink {
                ExplorationTestView()
            } label: {
                testMenuItem(
                    icon: "figure.walk",
                    title: "探索功能测试",
                    description: "查看探索和POI搜刮的实时日志"
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("开发测试")
        .background(ApocalypseTheme.background)
        .scrollContentBackground(.hidden)
    }

    // MARK: - 菜单项

    private func testMenuItem(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 40, height: 40)
                .background(ApocalypseTheme.primary.opacity(0.15))
                .cornerRadius(8)

            // 文字
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
