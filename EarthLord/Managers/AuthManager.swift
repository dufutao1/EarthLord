//
//  AuthManager.swift
//  EarthLord
//
//  Created by taozi on 2025/12/26.
//

import Foundation
import UIKit
import Combine
import Supabase
import Auth
import Functions
import GoogleSignIn

/// 认证管理器
/// 负责处理用户注册、登录、密码重置等认证相关操作
@MainActor
class AuthManager: ObservableObject {

    // MARK: - 单例
    static let shared = AuthManager()

    // MARK: - 发布属性

    /// 是否已完成认证（已登录且完成所有流程）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP验证后需要设置密码）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// OTP验证码是否已发送
    @Published var otpSent: Bool = false

    /// OTP验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - 私有属性

    /// 当前操作的邮箱（用于验证流程）
    private var currentEmail: String?

    // MARK: - 初始化

    private init() {
        // 初始化时不自动检查会话
        // 会话检查由 SplashView 在启动时调用
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 调用 Supabase 发送 OTP 验证码
            // shouldCreateUser: true 表示如果用户不存在则创建
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            currentEmail = email
            otpSent = true
            print("✅ 注册验证码已发送到: \(email)")

        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册OTP验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP 验证码
            // type: .email 用于注册/登录验证
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功后用户已登录，但需要设置密码
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true
            // 注意：isAuthenticated 保持 false，必须设置密码后才能进入主页

            print("✅ 注册验证码验证成功，用户已登录，等待设置密码")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户设置的密码
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: password))

            // 密码设置成功，完成注册流程
            needsPasswordSetup = false
            isAuthenticated = true
            otpSent = false
            otpVerified = false

            print("✅ 密码设置成功，注册完成")

        } catch {
            errorMessage = "密码设置失败: \(error.localizedDescription)"
            print("❌ 设置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录方法

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 直接使用邮箱密码登录
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = session.user
            isAuthenticated = true

            print("✅ 登录成功: \(email)")

        } catch {
            errorMessage = "登录失败: \(error.localizedDescription)"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送密码重置验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送密码重置邮件
            // 这会触发 Supabase 的 Reset Password 邮件模板
            try await supabase.auth.resetPasswordForEmail(email)

            currentEmail = email
            otpSent = true
            print("✅ 密码重置验证码已发送到: \(email)")

        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证密码重置OTP验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP 验证码
            // ⚠️ 注意：找回密码使用 .recovery 类型，不是 .email
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功后用户已登录，等待设置新密码
            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true

            print("✅ 重置验证码验证成功，等待设置新密码")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(user: UserAttributes(password: newPassword))

            // 密码重置成功
            needsPasswordSetup = false
            isAuthenticated = true
            otpSent = false
            otpVerified = false

            print("✅ 密码重置成功")

        } catch {
            errorMessage = "密码重置失败: \(error.localizedDescription)"
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// TODO: 实现 Sign in with Apple
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        // 1. 使用 AuthenticationServices 获取 Apple ID credential
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        print("⚠️ Apple 登录尚未实现")
        errorMessage = "Apple 登录功能即将上线"
    }

    /// Google 登录
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        print("🔵 [Google登录] 开始 Google 登录流程...")

        do {
            // 1. 获取当前窗口的 rootViewController
            guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = await windowScene.windows.first?.rootViewController else {
                print("❌ [Google登录] 无法获取 rootViewController")
                errorMessage = "无法启动 Google 登录"
                isLoading = false
                return
            }

            print("📱 [Google登录] 已获取 rootViewController")

            // 2. 调用 Google Sign-In
            print("🔄 [Google登录] 正在调用 Google Sign-In SDK...")
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            print("✅ [Google登录] Google 授权成功")
            print("👤 [Google登录] 用户: \(result.user.profile?.name ?? "未知")")
            print("📧 [Google登录] 邮箱: \(result.user.profile?.email ?? "未知")")

            // 3. 获取 ID Token
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ [Google登录] 无法获取 ID Token")
                errorMessage = "Google 登录失败：无法获取令牌"
                isLoading = false
                return
            }

            print("🎫 [Google登录] 已获取 ID Token (长度: \(idToken.count))")

            // 4. 获取 Access Token
            let accessToken = result.user.accessToken.tokenString
            print("🔑 [Google登录] 已获取 Access Token")

            // 5. 使用 Supabase 登录
            print("📡 [Google登录] 正在调用 Supabase 登录...")
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )

            // 6. 登录成功
            currentUser = session.user
            isAuthenticated = true

            print("✅ [Google登录] Supabase 登录成功!")
            print("👤 [Google登录] 用户ID: \(session.user.id)")
            print("📧 [Google登录] 邮箱: \(session.user.email ?? "未知")")

        } catch let error as GIDSignInError {
            // Google Sign-In 特定错误
            switch error.code {
            case .canceled:
                print("⚠️ [Google登录] 用户取消了登录")
                errorMessage = nil // 用户取消不显示错误
            case .hasNoAuthInKeychain:
                print("❌ [Google登录] 没有保存的登录信息")
                errorMessage = "请重新登录 Google 账号"
            default:
                print("❌ [Google登录] Google 登录错误: \(error.localizedDescription)")
                errorMessage = "Google 登录失败: \(error.localizedDescription)"
            }
        } catch {
            print("❌ [Google登录] 登录失败: \(error)")
            print("❌ [Google登录] 错误详情: \(error.localizedDescription)")
            errorMessage = "登录失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 其他方法

    /// 退出登录
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 重置所有状态
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            currentEmail = nil

            print("✅ 已退出登录")

        } catch {
            errorMessage = "退出登录失败: \(error.localizedDescription)"
            print("❌ 退出登录失败: \(error)")
        }

        isLoading = false
    }

    /// 删除账户
    /// 调用边缘函数删除用户账户及所有相关数据
    func deleteAccount() async -> Bool {
        isLoading = true
        errorMessage = nil

        print("🗑️ [删除账户] 开始删除账户流程...")

        do {
            // 1. 检查用户是否已登录
            guard let user = currentUser else {
                print("❌ [删除账户] 失败：用户未登录")
                errorMessage = "请先登录"
                isLoading = false
                return false
            }

            print("👤 [删除账户] 当前用户: \(user.email ?? "未知邮箱")")
            print("🔑 [删除账户] 用户ID: \(user.id)")

            // 2. 获取当前会话的 access token
            let session = try await supabase.auth.session
            let accessToken = session.accessToken
            print("🎫 [删除账户] 已获取 access token")

            // 3. 调用边缘函数删除账户（显式传递 Authorization header）
            print("📡 [删除账户] 正在调用边缘函数 delete-account...")

            try await supabase.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    method: .post,
                    headers: ["Authorization": "Bearer \(accessToken)"]
                )
            )

            print("✅ [删除账户] 边缘函数调用成功")

            // 3. 清空本地状态
            print("🧹 [删除账户] 正在清理本地状态...")
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            currentEmail = nil

            print("✅ [删除账户] 账户删除成功！")
            isLoading = false
            return true

        } catch {
            print("❌ [删除账户] 删除失败: \(error)")
            print("❌ [删除账户] 错误详情: \(error.localizedDescription)")
            errorMessage = "删除账户失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    /// 检查当前会话状态
    /// 用于应用启动时恢复登录状态
    func checkSession() async {
        isLoading = true

        do {
            // 获取当前会话
            let session = try await supabase.auth.session
            currentUser = session.user

            // 检查用户是否有密码（通过 identities 判断）
            // 如果用户只有 email identity 且没有密码，需要设置密码
            if let identities = session.user.identities,
               identities.contains(where: { $0.provider == "email" }) {
                // 用户有 email identity，检查是否需要设置密码
                // 这里简化处理：如果能获取到 session，认为用户已完成注册
                isAuthenticated = true
                needsPasswordSetup = false
            } else {
                isAuthenticated = true
                needsPasswordSetup = false
            }

            print("✅ 会话恢复成功: \(session.user.email ?? "unknown")")

        } catch {
            // 没有有效会话，用户需要登录
            currentUser = nil
            isAuthenticated = false
            print("ℹ️ 没有有效会话，需要登录")
        }

        isLoading = false
    }

    /// 启动认证状态监听器
    /// 监听 Supabase 认证状态变化，自动更新 UI
    func startAuthStateListener() async {
        // 使用 for-await-in 循环监听认证状态变化
        for await (event, session) in supabase.auth.authStateChanges {
            print("🔔 认证状态变化: \(event)")

            switch event {
            case .initialSession:
                // 初始会话状态
                if let session = session {
                    currentUser = session.user
                    isAuthenticated = true
                    print("📱 初始会话: \(session.user.email ?? "unknown")")
                } else {
                    currentUser = nil
                    isAuthenticated = false
                    print("📱 无初始会话")
                }

            case .signedIn:
                // 用户登录
                if let session = session {
                    currentUser = session.user
                    // 注意：如果是 OTP 验证后登录，可能还需要设置密码
                    // needsPasswordSetup 由具体的登录方法控制
                    if !needsPasswordSetup {
                        isAuthenticated = true
                    }
                    print("✅ 用户已登录: \(session.user.email ?? "unknown")")
                }

            case .signedOut:
                // 用户登出
                currentUser = nil
                isAuthenticated = false
                needsPasswordSetup = false
                otpSent = false
                otpVerified = false
                currentEmail = nil
                print("👋 用户已登出")

            case .userUpdated:
                // 用户信息更新（如密码更新）
                if let session = session {
                    currentUser = session.user
                    print("🔄 用户信息已更新: \(session.user.email ?? "unknown")")
                }

            case .passwordRecovery:
                // 密码恢复流程
                print("🔑 密码恢复流程")
                needsPasswordSetup = true

            case .tokenRefreshed:
                // Token 刷新
                if let session = session {
                    currentUser = session.user
                    print("🔄 Token 已刷新")
                }

            case .mfaChallengeVerified:
                // MFA 验证完成
                print("🔐 MFA 验证完成")

            @unknown default:
                print("⚠️ 未知认证事件: \(event)")
            }
        }
    }

    // MARK: - 辅助方法

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 重置所有OTP相关状态
    func resetOTPState() {
        otpSent = false
        otpVerified = false
        currentEmail = nil
    }
}
