//
//  RootView.swift
//  EarthLord
//
//  Created by taozi on 2025/12/23.
//

import SwiftUI

/// 根视图：控制启动页、认证页与主界面的切换
struct RootView: View {
    /// 启动页是否完成
    @State private var splashFinished = false

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        ZStack {
            if !splashFinished {
                // 1. 启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if authManager.isLoading {
                // 2. 正在检查登录状态
                loadingView
                    .transition(.opacity)
            } else if !authManager.isAuthenticated {
                // 3. 未登录 → 显示认证页面
                AuthView()
                    .transition(.opacity)
            } else if authManager.needsPasswordSetup {
                // 4. 需要设置密码（OTP验证后）
                AuthView()
                    .transition(.opacity)
            } else {
                // 5. 已登录 → 显示主界面
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authManager.needsPasswordSetup)
    }

    /// 加载中视图
    private var loadingView: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ApocalypseTheme.primary)

                Text("正在检查登录状态...")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }
}

#Preview {
    RootView()
}
