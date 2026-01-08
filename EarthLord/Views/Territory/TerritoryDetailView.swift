//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页
//  显示领地信息、地图预览、删除功能
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - 属性

    /// 领地数据
    let territory: Territory

    /// 删除成功回调
    var onDelete: (() -> Void)?

    /// 环境变量 - 用于关闭 sheet
    @Environment(\.dismiss) private var dismiss

    // MARK: - 状态

    /// 是否显示删除确认
    @State private var showDeleteAlert: Bool = false

    /// 是否正在删除
    @State private var isDeleting: Bool = false

    /// 地图区域
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
        latitudinalMeters: 500,
        longitudinalMeters: 500
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreviewSection

                    // 领地信息
                    infoSection

                    // 占位功能区
                    placeholderFeaturesSection

                    // 删除按钮
                    deleteButtonSection
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    Task {
                        await deleteTerritory()
                    }
                }
            } message: {
                Text("删除后无法恢复，确定要删除这块领地吗？")
            }
            .onAppear {
                setupMapRegion()
            }
        }
    }

    // MARK: - 地图预览

    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("位置预览")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Map(coordinateRegion: $mapRegion, annotationItems: [territory]) { item in
                MapAnnotation(coordinate: getCenterCoordinate()) {
                    Image(systemName: "flag.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                        .font(.system(size: 24))
                }
            }
            .frame(height: 200)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - 领地信息

    private var infoSection: some View {
        VStack(spacing: 12) {
            // 面积
            infoRow(icon: "square.dashed", title: "面积", value: territory.formattedArea)

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 坐标点数
            infoRow(icon: "point.topleft.down.curvedto.point.bottomright.up", title: "坐标点数", value: "\(territory.pointCount ?? 0) 个")

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 创建时间
            infoRow(icon: "clock", title: "占领时间", value: territory.formattedDate)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    // MARK: - 占位功能区

    private var placeholderFeaturesSection: some View {
        VStack(spacing: 12) {
            Text("更多功能")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 重命名
            placeholderFeatureRow(icon: "pencil", title: "重命名领地", subtitle: "敬请期待")

            // 建筑系统
            placeholderFeatureRow(icon: "building.2", title: "建筑系统", subtitle: "敬请期待")

            // 领地交易
            placeholderFeatureRow(icon: "arrow.left.arrow.right", title: "领地交易", subtitle: "敬请期待")
        }
    }

    private func placeholderFeatureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(10)
    }

    // MARK: - 删除按钮

    private var deleteButtonSection: some View {
        Button {
            showDeleteAlert = true
        } label: {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "trash")
                }
                Text(isDeleting ? "删除中..." : "删除领地")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ApocalypseTheme.danger)
            .cornerRadius(12)
        }
        .disabled(isDeleting)
        .padding(.top, 20)
    }

    // MARK: - 方法

    /// 设置地图区域
    private func setupMapRegion() {
        let coords = territory.toCoordinates()
        guard !coords.isEmpty else { return }

        // 计算中心点
        let center = getCenterCoordinate()

        // 计算范围
        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLon = coords[0].longitude
        var maxLon = coords[0].longitude

        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let latDelta = (maxLat - minLat) * 1.5
        let lonDelta = (maxLon - minLon) * 1.5

        mapRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.005),
                longitudeDelta: max(lonDelta, 0.005)
            )
        )
    }

    /// 获取中心坐标（已转换为 GCJ-02）
    private func getCenterCoordinate() -> CLLocationCoordinate2D {
        let coords = territory.toCoordinates()
        guard !coords.isEmpty else {
            return CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        }

        let totalLat = coords.reduce(0) { $0 + $1.latitude }
        let totalLon = coords.reduce(0) { $0 + $1.longitude }

        let wgs84Center = CLLocationCoordinate2D(
            latitude: totalLat / Double(coords.count),
            longitude: totalLon / Double(coords.count)
        )

        // WGS-84 → GCJ-02 坐标转换（中国地图需要）
        return CoordinateConverter.wgs84ToGcj02(wgs84Center)
    }

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true

        let success = await TerritoryManager.shared.deleteTerritory(territoryId: territory.id)

        isDeleting = false

        if success {
            dismiss()
            onDelete?()
        }
    }
}

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test-id",
            userId: "user-id",
            name: "测试领地",
            path: [
                ["lat": 39.9, "lon": 116.4],
                ["lat": 39.91, "lon": 116.4],
                ["lat": 39.91, "lon": 116.41],
                ["lat": 39.9, "lon": 116.41]
            ],
            area: 12345,
            pointCount: 50,
            isActive: true,
            createdAt: "2024-01-01T12:00:00.000Z",
            startedAt: nil,
            completedAt: nil
        )
    )
}
