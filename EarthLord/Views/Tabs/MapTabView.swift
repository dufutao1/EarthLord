//
//  MapTabView.swift
//  EarthLord
//
//  地图页面
//  显示末世风格的卫星地图，包含用户定位功能
//

import SwiftUI
import MapKit
import Supabase

struct MapTabView: View {

    // MARK: - 状态

    /// 定位管理器
    @StateObject private var locationManager = LocationManager.shared

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser: Bool = false

    /// 地图中心坐标（用于手动居中）
    @State private var centerCoordinate: CLLocationCoordinate2D?

    /// 是否显示坐标信息
    @State private var showCoordinateInfo: Bool = true

    /// 是否正在上传领地
    @State private var isUploading: Bool = false

    /// 上传结果消息
    @State private var uploadMessage: String? = nil

    /// 是否显示上传结果
    @State private var showUploadResult: Bool = false

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    // MARK: - Day 19: 碰撞检测状态

    /// 碰撞检测定时器
    @State private var collisionCheckTimer: Timer?

    /// 碰撞警告消息
    @State private var collisionWarning: String?

    /// 是否显示碰撞警告
    @State private var showCollisionWarning = false

    /// 碰撞警告级别
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - 探索功能状态

    /// 探索管理器
    @StateObject private var explorationManager = ExplorationManager.shared

    /// 是否显示探索结果
    @State private var showExplorationResult: Bool = false

    /// 探索结果数据
    @State private var explorationResult: ExplorationResult?

    /// 是否显示超速失败提示
    @State private var showSpeedFailureAlert: Bool = false

    // MARK: - 计算属性

    /// 当前用户 ID
    private var currentUserId: String? {
        supabase.auth.currentUser?.id.uuidString
    }

    var body: some View {
        ZStack {
            // 地图层
            mapLayer

            // 覆盖层（坐标信息、按钮等）
            overlayLayer

            // 权限被拒绝时显示提示
            if locationManager.isDenied {
                permissionDeniedView
            }
        }
        .onAppear {
            // 页面出现时检查并请求权限
            locationManager.checkAndRequestPermission()

            // 加载领地
            Task {
                await loadTerritories()
            }
        }
    }

    // MARK: - 地图层

    private var mapLayer: some View {
        MapViewRepresentable(
            userLocation: $userLocation,
            hasLocatedUser: $hasLocatedUser,
            centerCoordinate: $centerCoordinate,
            trackingPath: $locationManager.pathCoordinates,
            pathUpdateVersion: locationManager.pathUpdateVersion,
            isTracking: locationManager.isTracking,
            isPathClosed: locationManager.isPathClosed,
            territories: territories,
            currentUserId: supabase.auth.currentUser?.id.uuidString
        )
        .ignoresSafeArea()
    }

    // MARK: - 覆盖层

    private var overlayLayer: some View {
        VStack {
            // 速度警告横幅
            if let warning = locationManager.speedWarning {
                speedWarningBanner(message: warning)
                    .padding(.top, 50)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Day 19: 碰撞警告横幅（分级颜色）
            if showCollisionWarning, let warning = collisionWarning {
                collisionWarningBanner(message: warning, level: collisionWarningLevel)
                    .padding(.top, locationManager.speedWarning != nil ? 8 : 50)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 顶部坐标信息卡片
            if showCoordinateInfo {
                let hasTopBanner = locationManager.speedWarning != nil || showCollisionWarning
                coordinateInfoCard
                    .padding(.top, hasTopBanner ? 8 : 60)
                    .padding(.horizontal, 16)
            }

            Spacer()

            // 探索状态横幅
            if explorationManager.isExploring {
                explorationStatusBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 可闭环提示横幅
            if locationManager.canClosePath {
                canCloseBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 领地验证结果提示（闭环后显示）
            if locationManager.isPathClosed {
                validationResultBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            // 底部按钮区域
            HStack(spacing: 12) {
                Spacer()

                // 闭环确认按钮（可闭环时显示）
                if locationManager.canClosePath {
                    closePathButton
                        .transition(.scale.combined(with: .opacity))
                }

                // 探索按钮
                exploreButton

                // 圈地按钮
                claimTerritoryButton

                // 定位按钮
                locationButton
            }
            .padding(.trailing, 16)
            .padding(.bottom, 120)
            .sheet(isPresented: $showExplorationResult) {
                if let result = explorationResult {
                    ExplorationResultView(result: result)
                } else {
                    ExplorationResultView(errorMessage: "探索数据获取失败")
                }
            }
            .alert("探索失败", isPresented: $showSpeedFailureAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("您的移动速度超过30km/h并持续超过10秒，探索已被强制终止。\n\n请步行或慢跑进行探索。")
            }
        }
        .animation(.easeInOut(duration: 0.3), value: explorationManager.isExploring)
        .animation(.easeInOut(duration: 0.3), value: explorationManager.showSpeedWarning)
        .animation(.easeInOut(duration: 0.3), value: locationManager.speedWarning)
        .animation(.easeInOut(duration: 0.3), value: locationManager.isPathClosed)
        .animation(.easeInOut(duration: 0.3), value: locationManager.territoryValidationPassed)
        .animation(.easeInOut(duration: 0.3), value: locationManager.canClosePath)
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
        .onChange(of: explorationManager.explorationFailedDueToSpeed) { failed in
            if failed {
                // 探索因超速失败，显示失败提示
                showExplorationSpeedFailureAlert()
            }
        }
    }

    // MARK: - Day 19: 碰撞警告横幅（分级颜色）

    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 16))

            Text(message)
                .font(.system(size: 13, weight: .medium))

            Spacer()
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            backgroundColor
                .opacity(0.95)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // MARK: - 速度警告横幅

    private func speedWarningBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.isTracking ? "exclamationmark.triangle.fill" : "xmark.octagon.fill")
                .font(.system(size: 16))

            Text(message)
                .font(.system(size: 13, weight: .medium))

            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            // 追踪中用黄色警告，停止追踪用红色
            (locationManager.isTracking ? Color.orange : Color.red)
                .opacity(0.95)
        )
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // MARK: - 可闭环提示横幅

    private var canCloseBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))

            Text("可以闭环！点击绿色按钮确认占领")
                .font(.system(size: 13, weight: .medium))

            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.95))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // MARK: - 闭环确认按钮

    private var closePathButton: some View {
        Button {
            print("📍 [地图] 用户点击闭环确认")
            locationManager.confirmPathClosure()
        } label: {
            ZStack {
                // 背景圆形 - 绿色高亮
                Circle()
                    .fill(Color.green.opacity(0.95))
                    .frame(width: 50, height: 50)
                    .shadow(color: Color.green.opacity(0.5), radius: 6, x: 0, y: 2)

                // 图标 - 勾选
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - 领地验证结果横幅

    private var validationResultBanner: some View {
        Group {
            if locationManager.territoryValidationPassed {
                // 验证成功 - 绿色横幅 + 确认登记按钮
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))

                        Text("圈地成功！")
                            .font(.system(size: 13, weight: .medium))

                        Spacer()

                        // 显示面积
                        Text(formatArea(locationManager.calculatedArea))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    // 确认登记按钮
                    Button {
                        Task {
                            await uploadCurrentTerritory()
                        }
                    } label: {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                            }
                            Text(isUploading ? "上传中..." : "确认登记领地")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .disabled(isUploading)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.95))
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            } else {
                // 验证失败 - 红色横幅
                HStack(spacing: 8) {
                    Image(systemName: "xmark.seal.fill")
                        .font(.system(size: 16))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("领地验证失败")
                            .font(.system(size: 13, weight: .medium))

                        if let error = locationManager.territoryValidationError {
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.95))
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
    }

    /// 格式化面积显示
    private func formatArea(_ area: Double) -> String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    // MARK: - 坐标信息卡片

    private var coordinateInfoCard: some View {
        VStack(spacing: 8) {
            // 标题
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(ApocalypseTheme.primary)

                Text("当前坐标")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 关闭按钮
                Button {
                    withAnimation {
                        showCoordinateInfo = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            // 坐标值
            if let location = userLocation {
                HStack(spacing: 16) {
                    // 纬度
                    VStack(alignment: .leading, spacing: 2) {
                        Text("纬度")
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(String(format: "%.6f", location.latitude))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    // 经度
                    VStack(alignment: .leading, spacing: 2) {
                        Text("经度")
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text(String(format: "%.6f", location.longitude))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    Spacer()

                    // 定位状态
                    if hasLocatedUser {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.success)
                    } else {
                        ProgressView()
                            .tint(ApocalypseTheme.primary)
                    }
                }
            } else {
                // 等待定位
                HStack {
                    if locationManager.isAuthorized {
                        ProgressView()
                            .tint(ApocalypseTheme.primary)
                        Text("正在获取位置...")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    } else if locationManager.isNotDetermined {
                        Image(systemName: "location.slash")
                            .foregroundColor(ApocalypseTheme.warning)
                        Text("请允许定位权限")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    } else {
                        Image(systemName: "location.slash")
                            .foregroundColor(ApocalypseTheme.danger)
                        Text("无法获取位置")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    Spacer()
                }
            }

            // 错误信息
            if let error = locationManager.locationError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ApocalypseTheme.warning)
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.warning)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            ApocalypseTheme.cardBackground
                .opacity(0.95)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - 圈地按钮

    private var claimTerritoryButton: some View {
        Button {
            if locationManager.isTracking {
                // 停止圈地
                print("📍 [地图] 停止圈地")
                stopCollisionMonitoring()
                locationManager.stopPathTracking()
            } else {
                // Day 19: 开始圈地前检测起始点
                startClaimingWithCollisionCheck()
            }
        } label: {
            ZStack {
                // 背景圆形
                Circle()
                    .fill(locationManager.isTracking ?
                          ApocalypseTheme.primary.opacity(0.95) :
                          ApocalypseTheme.cardBackground.opacity(0.95))
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // 图标
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 20))
                    .foregroundColor(
                        locationManager.isTracking ?
                        .white : ApocalypseTheme.primary
                    )
            }
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.5)
    }

    // MARK: - 探索按钮

    private var exploreButton: some View {
        Button {
            if explorationManager.isExploring {
                // 结束探索
                stopExploration()
            } else {
                // 开始探索
                startExploration()
            }
        } label: {
            ZStack {
                // 背景圆形
                Circle()
                    .fill(
                        explorationManager.isExploring
                            ? ApocalypseTheme.success.opacity(0.95)  // 探索中显示绿色
                            : ApocalypseTheme.primary.opacity(0.95)
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // 图标
                Image(systemName: explorationManager.isExploring ? "stop.fill" : "binoculars.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.5)
    }

    /// 探索状态横幅
    private var explorationStatusBanner: some View {
        // 根据是否超速决定背景颜色
        let bannerColor: Color = explorationManager.showSpeedWarning ? .red : ApocalypseTheme.success

        return HStack(spacing: 12) {
            // 图标（超速时显示警告图标）
            if explorationManager.showSpeedWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.yellow)
                    .symbolEffect(.pulse, options: .repeating)
            } else {
                Image(systemName: "figure.walk")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(alignment: .leading, spacing: 2) {
                // 标题（超速时显示警告）
                if explorationManager.showSpeedWarning {
                    HStack(spacing: 4) {
                        Text("⚠️ 超速警告!")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("\(explorationManager.speedWarningCountdown)秒后停止")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                } else {
                    Text("探索中...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                HStack(spacing: 12) {
                    // 距离
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 10))
                        Text(formatExplorationDistance(explorationManager.currentDistance))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }

                    // 时长
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(formatExplorationDuration(explorationManager.currentDuration))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }

                    // 速度（显示当前速度）
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 10))
                        Text(String(format: "%.1f km/h", explorationManager.currentSpeed))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(explorationManager.showSpeedWarning ? .yellow : .white.opacity(0.9))
                    }
                }
                .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            // 结束按钮
            Button(action: { stopExploration() }) {
                Text("结束")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(explorationManager.showSpeedWarning ? .red : ApocalypseTheme.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(14)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(bannerColor.opacity(0.95))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    /// 开始探索
    private func startExploration() {
        guard !explorationManager.isExploring else { return }
        explorationManager.startExploration()
    }

    /// 结束探索
    private func stopExploration() {
        guard explorationManager.isExploring else { return }

        Task {
            let result = await explorationManager.stopExploration()
            await MainActor.run {
                explorationResult = result
                showExplorationResult = true
            }
        }
    }

    /// 格式化探索距离
    private func formatExplorationDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    /// 格式化探索时长
    private func formatExplorationDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// 显示超速失败提示
    private func showExplorationSpeedFailureAlert() {
        showSpeedFailureAlert = true
        // 重置标志，以便下次探索
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            explorationManager.explorationFailedDueToSpeed = false
        }
    }

    // MARK: - 定位按钮

    private var locationButton: some View {
        Button {
            // 点击定位按钮，重新居中到用户位置
            if let location = userLocation {
                print("📍 [地图] 点击定位按钮，居中到用户位置")
                centerCoordinate = location
            } else {
                // 如果没有位置，尝试请求定位
                locationManager.checkAndRequestPermission()
            }

            // 显示坐标信息卡片
            withAnimation {
                showCoordinateInfo = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                Image(systemName: locationManager.isAuthorized ? "location.fill" : "location.slash")
                    .font(.system(size: 20))
                    .foregroundColor(
                        locationManager.isAuthorized ?
                        ApocalypseTheme.primary : ApocalypseTheme.textMuted
                    )
            }
        }
    }

    // MARK: - 权限被拒绝视图

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("需要定位权限")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("请在设置中允许《地球新主》访问您的位置，以便在末日世界中显示您的坐标。")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // 前往设置按钮
                Button {
                    openAppSettings()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("前往设置")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(ApocalypseTheme.cardBackground.opacity(0.95))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    // MARK: - 方法

    /// 打开 App 设置页面
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            uploadMessage = "领地验证未通过，无法上传"
            showUploadResult = true
            return
        }

        // 检查坐标数据
        guard !locationManager.pathCoordinates.isEmpty else {
            uploadMessage = "没有坐标数据"
            showUploadResult = true
            return
        }

        // 开始上传
        isUploading = true

        do {
            try await TerritoryManager.shared.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: locationManager.trackingStartTime ?? Date()
            )

            // 上传成功
            uploadMessage = "领地登记成功！"
            showUploadResult = true
            print("📤 [地图] 领地上传成功，重置状态")

            // Day 19: 停止碰撞监控
            stopCollisionMonitoring()

            // 重置领地状态
            locationManager.resetTerritoryState()

            // 刷新领地列表
            await loadTerritories()

        } catch {
            // 上传失败
            uploadMessage = "上传失败: \(error.localizedDescription)"
            showUploadResult = true
            print("📤 [地图] 领地上传失败: \(error)")
        }

        isUploading = false
    }

    /// 加载所有领地
    private func loadTerritories() async {
        do {
            territories = try await TerritoryManager.shared.loadAllTerritories()
            // 同时更新 TerritoryManager 的 territories，供碰撞检测使用
            TerritoryManager.shared.territories = territories
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = TerritoryManager.shared.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            triggerHapticFeedback(level: .violation)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        print("📍 [地图] 开始圈地")
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        locationManager.startPathTracking()
        startCollisionMonitoring()

        // 显示坐标信息卡片
        withAnimation {
            showCoordinateInfo = true
        }
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
        TerritoryLogger.shared.log("碰撞检测监控已停止", type: .info)
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = TerritoryManager.shared.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
