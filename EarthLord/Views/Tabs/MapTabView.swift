//
//  MapTabView.swift
//  EarthLord
//
//  地图页面
//  显示末世风格的卫星地图，包含用户定位功能
//

import SwiftUI
import MapKit

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
            isPathClosed: locationManager.isPathClosed
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

            // 闭环成功提示
            if locationManager.isPathClosed {
                closureSuccessBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            // 底部按钮区域
            HStack(spacing: 12) {
                Spacer()

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

    // MARK: - 闭环成功横幅

    private var closureSuccessBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16))

            Text("圈地成功！领土已占领")
                .font(.system(size: 13, weight: .medium))

            Spacer()

            Text("\(locationManager.pathCoordinates.count) 个点")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.95))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
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
}

// MARK: - Preview

#Preview {
    MapTabView()
}
