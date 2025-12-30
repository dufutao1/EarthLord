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

    /// 是否显示删除账户确认弹窗
    @State private var showDeleteAccountSheet = false

    /// 删除确认输入框内容
    @State private var deleteConfirmText = ""

    /// 是否正在删除账户
    @State private var isDeletingAccount = false

    /// 删除结果提示
    @State private var deleteResultMessage: String?
    @State private var showDeleteResult = false

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

                        // 删除账户按钮
                        deleteAccountButton

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            // 退出登录确认弹窗
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("退出登录", role: .destructive) {
                    performLogout()
                }
            } message: {
                Text("确定要退出当前账号吗？")
            }
            // 删除结果提示
            .alert(deleteResultMessage ?? "", isPresented: $showDeleteResult) {
                Button("确定", role: .cancel) { }
            }
            // 删除账户确认弹窗
            .sheet(isPresented: $showDeleteAccountSheet) {
                deleteAccountConfirmSheet
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
            print("🚪 [个人中心] 用户点击退出登录按钮")
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

    // MARK: - 删除账户按钮

    private var deleteAccountButton: some View {
        Button {
            print("⚠️ [个人中心] 用户点击删除账户按钮")
            deleteConfirmText = ""
            showDeleteAccountSheet = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("删除账户")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(ApocalypseTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.danger.opacity(0.5), lineWidth: 1)
            )
        }
    }

    // MARK: - 删除账户确认弹窗

    private var deleteAccountConfirmSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(ApocalypseTheme.danger)
                        .padding(.top, 20)

                    // 警告标题
                    Text("确定要删除账户吗？")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 警告说明
                    VStack(spacing: 12) {
                        Text("此操作不可撤销！删除账户后：")
                            .font(.system(size: 15))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        VStack(alignment: .leading, spacing: 8) {
                            warningItem("您的所有数据将被永久删除")
                            warningItem("您将无法恢复此账户")
                            warningItem("所有领地记录将被清除")
                        }
                        .padding(.horizontal, 20)
                    }

                    // 确认输入框
                    VStack(alignment: .leading, spacing: 8) {
                        Text("请输入「删除」以确认：")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        TextField("", text: $deleteConfirmText)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(12)
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        deleteConfirmText == "删除" ?
                                        ApocalypseTheme.danger : ApocalypseTheme.textMuted.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    // 按钮区域
                    VStack(spacing: 12) {
                        // 确认删除按钮
                        Button {
                            print("🗑️ [个人中心] 用户确认删除账户")
                            performDeleteAccount()
                        } label: {
                            HStack {
                                if isDeletingAccount {
                                    ProgressView()
                                        .tint(.white)
                                    Text("正在删除...")
                                } else {
                                    Image(systemName: "trash.fill")
                                    Text("确认删除账户")
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                deleteConfirmText == "删除" ?
                                ApocalypseTheme.danger : ApocalypseTheme.danger.opacity(0.3)
                            )
                            .cornerRadius(12)
                        }
                        .disabled(deleteConfirmText != "删除" || isDeletingAccount)

                        // 取消按钮
                        Button {
                            print("↩️ [个人中心] 用户取消删除账户")
                            showDeleteAccountSheet = false
                        } label: {
                            Text("取消")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .disabled(isDeletingAccount)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("删除账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showDeleteAccountSheet = false
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .disabled(isDeletingAccount)
                }
            }
            .interactiveDismissDisabled(isDeletingAccount)
        }
        .presentationDetents([.medium, .large])
    }

    // 警告项
    private func warningItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(ApocalypseTheme.danger)
                .font(.system(size: 14))

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()
        }
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
        print("🚪 [个人中心] 开始执行退出登录...")
        isLoggingOut = true

        Task {
            await authManager.signOut()

            await MainActor.run {
                isLoggingOut = false
                print("✅ [个人中心] 退出登录完成")
            }
        }
    }

    /// 执行删除账户
    private func performDeleteAccount() {
        print("🗑️ [个人中心] 开始执行删除账户...")
        isDeletingAccount = true

        Task {
            let success = await authManager.deleteAccount()

            await MainActor.run {
                isDeletingAccount = false
                showDeleteAccountSheet = false

                if success {
                    print("✅ [个人中心] 账户删除成功")
                    deleteResultMessage = "账户已成功删除"
                } else {
                    print("❌ [个人中心] 账户删除失败")
                    deleteResultMessage = authManager.errorMessage ?? "删除账户失败，请稍后重试"
                }
                showDeleteResult = true
            }
        }
    }
}

#Preview {
    ProfileTabView()
}
