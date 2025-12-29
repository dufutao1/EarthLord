//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by taozi on 2025/12/23.
//

import SwiftUI
import Supabase
import Auth

struct ProfileTabView: View {
    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 是否显示登出确认弹窗
    @State private var showLogoutAlert = false

    /// 是否正在登出
    @State private var isLoggingOut = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 用户信息卡片
                        userInfoCard

                        // 功能菜单
                        menuSection

                        // 退出登录按钮
                        logoutButton

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("退出登录", role: .destructive) {
                    performLogout()
                }
            } message: {
                Text("确定要退出当前账号吗？")
            }
        }
    }

    // MARK: - 用户信息卡片

    private var userInfoCard: some View {
        VStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 10)

                // 用户名首字母或默认图标
                if let email = authManager.currentUser?.email,
                   let firstChar = email.first {
                    Text(String(firstChar).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }

            // 用户名/邮箱
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let email = authManager.currentUser?.email {
                    Text(email)
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 用户 ID（可选显示）
            if let userId = authManager.currentUser?.id {
                Text("ID: \(userId.uuidString.prefix(8))...")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 功能菜单

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuItem(icon: "gearshape.fill", title: "设置", subtitle: "账号与隐私设置")
            Divider().background(ApocalypseTheme.textMuted.opacity(0.3))

            menuItem(icon: "bell.fill", title: "通知", subtitle: "消息提醒设置")
            Divider().background(ApocalypseTheme.textMuted.opacity(0.3))

            menuItem(icon: "shield.fill", title: "安全", subtitle: "密码与登录安全")
            Divider().background(ApocalypseTheme.textMuted.opacity(0.3))

            menuItem(icon: "questionmark.circle.fill", title: "帮助", subtitle: "常见问题与反馈")
            Divider().background(ApocalypseTheme.textMuted.opacity(0.3))

            menuItem(icon: "info.circle.fill", title: "关于", subtitle: "版本信息")
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    private func menuItem(icon: String, title: String, subtitle: String) -> some View {
        Button {
            // TODO: 导航到对应页面
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - 退出登录按钮

    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack {
                if isLoggingOut {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("退出登录")
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.danger)
            .cornerRadius(12)
        }
        .disabled(isLoggingOut)
    }

    // MARK: - 辅助属性

    /// 显示名称
    private var displayName: String {
        if let user = authManager.currentUser {
            // 使用邮箱前缀作为显示名称
            if let email = user.email {
                return String(email.split(separator: "@").first ?? "用户")
            }
        }
        return "幸存者"
    }

    // MARK: - 方法

    /// 执行登出
    private func performLogout() {
        isLoggingOut = true

        Task {
            await authManager.signOut()

            await MainActor.run {
                isLoggingOut = false
            }
        }
    }
}

#Preview {
    ProfileTabView()
}
