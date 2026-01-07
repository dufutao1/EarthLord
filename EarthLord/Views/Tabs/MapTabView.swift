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

            // 顶部坐标信息卡片
            if showCoordinateInfo {
                coordinateInfoCard
                    .padding(.top, locationManager.speedWarning != nil ? 8 : 60)
                    .padding(.horizontal, 16)
            }

            Spacer()

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

                // 圈地按钮
                claimTerritoryButton

                // 定位按钮
                locationButton
            }
            .padding(.trailing, 16)
            .padding(.bottom, 120)
        }
        .animation(.easeInOut(duration: 0.3), value: locationManager.speedWarning)
        .animation(.easeInOut(duration: 0.3), value: locationManager.isPathClosed)
        .animation(.easeInOut(duration: 0.3), value: locationManager.territoryValidationPassed)
        .animation(.easeInOut(duration: 0.3), value: locationManager.canClosePath)
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
                locationManager.stopPathTracking()
            } else {
                // 开始圈地
                print("📍 [地图] 开始圈地")
                locationManager.startPathTracking()

                // 显示坐标信息卡片
                withAnimation {
                    showCoordinateInfo = true
                }
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
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
