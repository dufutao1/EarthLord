//
//  AuthManager.swift
//  EarthLord
//
//  Created by taozi on 2025/12/26.
//

import Foundation
import Combine
import Supabase
import Auth

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
    /// TODO: 实现 Sign in with Google
    func signInWithGoogle() async {
        // TODO: 实现 Google 登录
        // 1. 使用 Google Sign-In SDK 获取 ID token
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        print("⚠️ Google 登录尚未实现")
        errorMessage = "Google 登录功能即将上线"
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
