//
//  AuthView.swift
//  EarthLord
//
//  Created by taozi on 2025/12/26.
//

import SwiftUI

/// 认证页面
/// 包含登录、注册、忘记密码功能
struct AuthView: View {

    // MARK: - 状态管理

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 当前选中的Tab（0=登录，1=注册）
    @State private var selectedTab = 0

    /// 是否显示忘记密码弹窗
    @State private var showForgotPassword = false

    /// 显示Toast消息
    @State private var toastMessage: String?

    // MARK: - 登录表单状态

    @State private var loginEmail = ""
    @State private var loginPassword = ""

    // MARK: - 注册表单状态

    @State private var registerEmail = ""
    @State private var registerOTP = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""

    /// 注册步骤（1=邮箱，2=验证码，3=密码）
    @State private var registerStep = 1

    /// 重发验证码倒计时
    @State private var resendCountdown = 0
    @State private var resendTimer: Timer?

    // MARK: - 忘记密码表单状态

    @State private var resetEmail = ""
    @State private var resetOTP = ""
    @State private var resetPassword = ""
    @State private var resetConfirmPassword = ""
    @State private var resetStep = 1
    @State private var resetResendCountdown = 0

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            ScrollView {
                VStack(spacing: 30) {
                    // Logo 和标题
                    logoSection

                    // Tab 切换
                    tabSelector

                    // 内容区域
                    if selectedTab == 0 {
                        loginView
                    } else {
                        registerView
                    }

                    // 分隔线
                    dividerSection

                    // 第三方登录
                    socialLoginSection

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }

            // 加载遮罩
            if authManager.isLoading {
                loadingOverlay
            }

            // Toast 消息
            if let message = toastMessage {
                toastView(message: message)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.otpVerified) { _, verified in
            // OTP 验证成功后自动进入第三步
            if verified && authManager.needsPasswordSetup {
                if selectedTab == 1 {
                    registerStep = 3
                }
            }
        }
        .onChange(of: authManager.otpSent) { _, sent in
            // 验证码发送成功后开始倒计时
            if sent {
                startResendCountdown()
            }
        }
    }

    // MARK: - 背景渐变

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.10, green: 0.10, blue: 0.18),
                Color(red: 0.09, green: 0.13, blue: 0.24),
                Color(red: 0.06, green: 0.06, blue: 0.10)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Logo 区域

    private var logoSection: some View {
        VStack(spacing: 12) {
            // Logo 圆形背景
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
                    .frame(width: 80, height: 80)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 15)

                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            // 标题
            Text("地球新主")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("EARTH LORD")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .tracking(3)
        }
    }

    // MARK: - Tab 选择器

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "登录", index: 0)
            tabButton(title: "注册", index: 1)
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
                // 切换 Tab 时重置状态
                authManager.clearError()
                authManager.resetOTPState()
                registerStep = 1
            }
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(selectedTab == index ? .white : ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    selectedTab == index ?
                    ApocalypseTheme.primary : Color.clear
                )
                .cornerRadius(12)
        }
    }

    // MARK: - 登录视图

    private var loginView: some View {
        VStack(spacing: 20) {
            // 错误提示
            errorMessageView

            // 邮箱输入
            customTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入
            customSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword
            )

            // 忘记密码链接
            HStack {
                Spacer()
                Button("忘记密码？") {
                    resetStep = 1
                    resetEmail = ""
                    resetOTP = ""
                    resetPassword = ""
                    resetConfirmPassword = ""
                    showForgotPassword = true
                }
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.primary)
            }

            // 登录按钮
            primaryButton(title: "登录") {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)
        }
    }

    // MARK: - 注册视图

    private var registerView: some View {
        VStack(spacing: 20) {
            // 错误提示
            errorMessageView

            // 步骤指示器
            stepIndicator(currentStep: registerStep, totalSteps: 3)

            switch registerStep {
            case 1:
                registerStep1View
            case 2:
                registerStep2View
            case 3:
                registerStep3View
            default:
                EmptyView()
            }
        }
    }

    // 注册第一步：邮箱输入
    private var registerStep1View: some View {
        VStack(spacing: 20) {
            Text("输入您的邮箱地址")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            customTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            primaryButton(title: "发送验证码") {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        registerStep = 2
                    }
                }
            }
            .disabled(registerEmail.isEmpty || !isValidEmail(registerEmail))
        }
    }

    // 注册第二步：验证码输入
    private var registerStep2View: some View {
        VStack(spacing: 20) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证码已发送至 \(registerEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 6位验证码输入
            customTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $registerOTP,
                keyboardType: .numberPad
            )

            // 重发倒计时
            HStack {
                Spacer()
                if resendCountdown > 0 {
                    Text("\(resendCountdown)秒后可重发")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else {
                    Button("重新发送") {
                        Task {
                            await authManager.sendRegisterOTP(email: registerEmail)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }

            primaryButton(title: "验证") {
                Task {
                    await authManager.verifyRegisterOTP(email: registerEmail, code: registerOTP)
                }
            }
            .disabled(registerOTP.count != 6)

            // 返回上一步
            Button("返回修改邮箱") {
                registerStep = 1
                authManager.resetOTPState()
            }
            .font(.system(size: 14))
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // 注册第三步：设置密码
    private var registerStep3View: some View {
        VStack(spacing: 20) {
            Text("设置您的密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证成功！请设置登录密码")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.success)

            customSecureField(
                icon: "lock.fill",
                placeholder: "设置密码（至少6位）",
                text: $registerPassword
            )

            customSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword
            )

            // 密码不匹配提示
            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            primaryButton(title: "完成注册") {
                Task {
                    await authManager.completeRegistration(password: registerPassword)
                }
            }
            .disabled(
                registerPassword.count < 6 ||
                registerPassword != registerConfirmPassword
            )
        }
    }

    // MARK: - 分隔线

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 1)

            Text("或者使用以下方式登录")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
                .fixedSize()

            Rectangle()
                .fill(ApocalypseTheme.textMuted)
                .frame(height: 1)
        }
        .padding(.vertical, 10)
    }

    // MARK: - 第三方登录

    private var socialLoginSection: some View {
        VStack(spacing: 12) {
            // Apple 登录按钮
            Button {
                showToast("Apple 登录即将开放")
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20))
                    Text("使用 Apple 登录")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
            }

            // Google 登录按钮
            Button {
                showToast("Google 登录即将开放")
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 20))
                    Text("使用 Google 登录")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 忘记密码弹窗

    private var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 步骤指示器
                        stepIndicator(currentStep: resetStep, totalSteps: 3)

                        // 错误提示
                        if let error = authManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.danger)
                                .padding(.horizontal)
                        }

                        switch resetStep {
                        case 1:
                            resetStep1View
                        case 2:
                            resetStep2View
                        case 3:
                            resetStep3View
                        default:
                            EmptyView()
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showForgotPassword = false
                        authManager.resetOTPState()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // 重置密码第一步
    private var resetStep1View: some View {
        VStack(spacing: 20) {
            Text("输入注册邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            customTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $resetEmail,
                keyboardType: .emailAddress
            )

            primaryButton(title: "发送验证码") {
                Task {
                    await authManager.sendResetOTP(email: resetEmail)
                    if authManager.otpSent {
                        resetStep = 2
                        startResetResendCountdown()
                    }
                }
            }
            .disabled(resetEmail.isEmpty || !isValidEmail(resetEmail))
        }
    }

    // 重置密码第二步
    private var resetStep2View: some View {
        VStack(spacing: 20) {
            Text("输入验证码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("验证码已发送至 \(resetEmail)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            customTextField(
                icon: "number",
                placeholder: "6位验证码",
                text: $resetOTP,
                keyboardType: .numberPad
            )

            HStack {
                Spacer()
                if resetResendCountdown > 0 {
                    Text("\(resetResendCountdown)秒后可重发")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else {
                    Button("重新发送") {
                        Task {
                            await authManager.sendResetOTP(email: resetEmail)
                            startResetResendCountdown()
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }

            primaryButton(title: "验证") {
                Task {
                    await authManager.verifyResetOTP(email: resetEmail, code: resetOTP)
                    if authManager.otpVerified {
                        resetStep = 3
                    }
                }
            }
            .disabled(resetOTP.count != 6)
        }
    }

    // 重置密码第三步
    private var resetStep3View: some View {
        VStack(spacing: 20) {
            Text("设置新密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            customSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $resetPassword
            )

            customSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $resetConfirmPassword
            )

            if !resetConfirmPassword.isEmpty && resetPassword != resetConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            primaryButton(title: "重置密码") {
                Task {
                    await authManager.resetPassword(newPassword: resetPassword)
                    if authManager.isAuthenticated {
                        showForgotPassword = false
                    }
                }
            }
            .disabled(
                resetPassword.count < 6 ||
                resetPassword != resetConfirmPassword
            )
        }
    }

    // MARK: - 通用组件

    // 错误消息视图
    @ViewBuilder
    private var errorMessageView: some View {
        if let error = authManager.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.danger)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ApocalypseTheme.danger.opacity(0.1))
                .cornerRadius(8)
        }
    }

    // 步骤指示器
    private func stepIndicator(currentStep: Int, totalSteps: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 10, height: 10)

                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                        .frame(width: 30, height: 2)
                }
            }
        }
    }

    // 自定义文本输入框
    private func customTextField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // 自定义密码输入框
    private func customSecureField(
        icon: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            SecureField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // 主按钮
    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(ApocalypseTheme.primary)
                .cornerRadius(12)
        }
    }

    // 加载遮罩
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(ApocalypseTheme.primary)

                Text("请稍候...")
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }
            .padding(30)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // Toast 视图
    private func toastView(message: String) -> some View {
        VStack {
            Spacer()

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: toastMessage)
    }

    // MARK: - 辅助方法

    // 显示 Toast
    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toastMessage = nil
        }
    }

    // 验证邮箱格式
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    // 开始注册重发倒计时
    private func startResendCountdown() {
        resendCountdown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                resendTimer?.invalidate()
            }
        }
    }

    // 开始重置密码重发倒计时
    private func startResetResendCountdown() {
        resetResendCountdown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resetResendCountdown > 0 {
                resetResendCountdown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    AuthView()
}
