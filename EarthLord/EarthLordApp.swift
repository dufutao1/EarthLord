//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 刘文骏 on 2025/12/23.
//

import SwiftUI
import GoogleSignIn

@main
struct EarthLordApp: App {
    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 语言管理器
    @StateObject private var languageManager = LanguageManager.shared

    /// 定位管理器
    @StateObject private var locationManager = LocationManager.shared

    /// App 生命周期阶段
    @Environment(\.scenePhase) private var scenePhase

    /// 是否显示启动页
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    // 1. 启动页
                    SplashView(
                        isFinished: $showSplash,
                        onCheckSession: {
                            // 启动时检查会话状态
                            await authManager.checkSession()
                        }
                    )
                    .transition(.opacity)
                } else if !authManager.isAuthenticated || authManager.needsPasswordSetup {
                    // 2. 未登录或需要设置密码 → 认证页面
                    AuthView()
                        .transition(.opacity)
                } else {
                    // 3. 已登录 → 主界面
                    ContentView()
                        .transition(.opacity)
                }
            }
            .id(languageManager.languageRefreshID)
            .animation(.easeInOut(duration: 0.3), value: showSplash)
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.needsPasswordSetup)
            .task {
                // 监听认证状态变化
                await authManager.startAuthStateListener()
            }
            .onOpenURL { url in
                // 处理 Google Sign-In 回调
                print("🔗 [App] 收到 URL 回调: \(url)")
                GIDSignIn.sharedInstance.handle(url)
            }
            .environment(\.locale, languageManager.currentLanguage == .system
                ? Locale.current
                : Locale(identifier: languageManager.currentLanguage.rawValue))
            .environmentObject(locationManager)
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

    // MARK: - 生命周期处理

    /// 处理 App 生命周期变化
    /// - Parameter phase: 新的生命周期阶段
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App 进入前台：标记在线，恢复定时上报（如果正在探索）
            print("📱 [App] 进入前台 (active)")
            Task {
                await PlayerLocationManager.shared.markOnline()
            }

        case .background:
            // App 进入后台：标记离线，停止定时上报
            print("📱 [App] 进入后台 (background)")
            Task {
                await PlayerLocationManager.shared.markOffline()
                PlayerLocationManager.shared.stopPeriodicReporting()
            }

        case .inactive:
            // App 处于非活跃状态（如接电话、下拉通知栏）
            print("📱 [App] 非活跃状态 (inactive)")

        @unknown default:
            print("📱 [App] 未知生命周期状态")
        }
    }
}
