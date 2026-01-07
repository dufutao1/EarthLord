//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器
//  负责显示地图、应用末世滤镜、处理用户位置居中
//  支持轨迹变色和闭环后的多边形填充
//

import SwiftUI
import MapKit

/// MKMapView 的 SwiftUI 包装器
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Bindings

    /// 用户位置坐标（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

    /// 地图中心位置（可选，用于外部控制）
    @Binding var centerCoordinate: CLLocationCoordinate2D?

    /// 轨迹坐标数组（用于绘制路径）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 轨迹更新版本号（用于触发重绘）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 轨迹是否已闭环
    var isPathClosed: Bool

    /// 已加载的领地列表
    var territories: [Territory]

    /// 当前用户 ID
    var currentUserId: String?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 设置地图类型为卫星图+道路标签（符合末世废土风格）
        mapView.mapType = .hybrid

        // 隐藏所有 POI 标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏 3D 建筑
        mapView.showsBuildings = false

        // 显示用户位置蓝点（关键！这会触发 MapKit 开始获取位置）
        mapView.showsUserLocation = true

        // 允许用户交互
        mapView.isZoomEnabled = true      // 允许双指缩放
        mapView.isScrollEnabled = true    // 允许单指拖动
        mapView.isRotateEnabled = true    // 允许旋转
        mapView.isPitchEnabled = true     // 允许俯仰

        // 显示指南针
        mapView.showsCompass = true

        // 设置代理（关键！否则 didUpdate userLocation 不会被调用）
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        // 设置初始区域（默认北京）
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
        mapView.setRegion(defaultRegion, animated: false)

        print("🗺️ [地图] MKMapView 创建完成")
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 如果外部传入了新的中心坐标，移动地图
        if let center = centerCoordinate {
            let region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)

            // 重置中心坐标，防止重复触发
            DispatchQueue.main.async {
                self.centerCoordinate = nil
            }
        }

        // 更新轨迹路径
        updateTrackingPath(on: mapView, context: context)

        // 绘制领地
        drawTerritories(on: mapView, context: context)
    }

    /// 更新轨迹路径
    private func updateTrackingPath(on mapView: MKMapView, context: Context) {
        // 检查版本号是否有变化
        guard context.coordinator.lastPathVersion != pathUpdateVersion else { return }
        context.coordinator.lastPathVersion = pathUpdateVersion

        // 移除旧的轨迹覆盖物（折线和当前绘制的多边形，但保留领地多边形）
        let trackOverlays = mapView.overlays.filter { overlay in
            if overlay is MKPolyline {
                return true
            }
            if let polygon = overlay as? MKPolygon {
                // 只移除没有标题的多边形（当前绘制的轨迹多边形）
                return polygon.title == nil || polygon.title == "current"
            }
            return false
        }
        mapView.removeOverlays(trackOverlays)

        // 如果没有轨迹点，不绘制
        guard trackingPath.count >= 2 else { return }

        // 将 WGS-84 坐标转换为 GCJ-02 坐标（修正中国地图偏移）
        let convertedCoordinates = CoordinateConverter.convertPath(trackingPath)

        // 如果已闭环且点数足够，创建多边形填充
        if isPathClosed && convertedCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: convertedCoordinates, count: convertedCoordinates.count)
            polygon.title = "current"  // 标记为当前绘制的多边形
            mapView.addOverlay(polygon)
            print("🗺️ [地图] 添加闭环多边形，共 \(convertedCoordinates.count) 个点")
        }

        // 创建折线（轨迹边框）
        let polyline = MKPolyline(coordinates: convertedCoordinates, count: convertedCoordinates.count)
        mapView.addOverlay(polyline)

        print("🗺️ [地图] 更新轨迹，共 \(trackingPath.count) 个点，闭环: \(isPathClosed)")
    }

    /// 绘制领地多边形
    private func drawTerritories(on mapView: MKMapView, context: Context) {
        // 检查领地数量是否有变化
        guard context.coordinator.lastTerritoriesCount != territories.count else { return }
        context.coordinator.lastTerritoriesCount = territories.count

        // 移除旧的领地多边形（保留轨迹和当前绘制的多边形）
        let territoryOverlays = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon {
                return polygon.title == "mine" || polygon.title == "others"
            }
            return false
        }
        mapView.removeOverlays(territoryOverlays)

        // 绘制每个领地
        for territory in territories {
            var coords = territory.toCoordinates()

            // 中国大陆需要坐标转换（WGS-84 → GCJ-02）
            coords = coords.map { coord in
                CoordinateConverter.wgs84ToGcj02(coord)
            }

            guard coords.count >= 3 else { continue }

            let polygon = MKPolygon(coordinates: coords, count: coords.count)

            // ⚠️ 关键：比较 userId 时必须统一大小写！
            // 数据库存的是小写 UUID，但 iOS 的 uuidString 返回大写
            let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
            polygon.title = isMine ? "mine" : "others"

            mapView.addOverlay(polygon, level: .aboveRoads)
        }

        if !territories.isEmpty {
            print("🗺️ [地图] 绘制了 \(territories.count) 个领地")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 末世滤镜效果

    /// 应用末世废土风格滤镜
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        guard let colorControls = CIFilter(name: "CIColorControls") else { return }
        colorControls.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
        colorControls.setValue(0.5, forKey: kCIInputSaturationKey)    // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        guard let sepiaFilter = CIFilter(name: "CISepiaTone") else { return }
        sepiaFilter.setValue(0.65, forKey: kCIInputIntensityKey)

        // 应用滤镜到地图图层
        mapView.layer.filters = [colorControls, sepiaFilter]

        print("🗺️ [地图] 末世滤镜已应用")
    }

    // MARK: - Coordinator

    /// 协调器：处理 MKMapView 代理回调
    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: MapViewRepresentable

        /// 首次居中标志（防止重复居中）
        private var hasInitialCentered = false

        /// 上次更新的轨迹版本号（用于避免重复更新）
        var lastPathVersion: Int = -1

        /// 上次更新的领地数量（用于避免重复绘制）
        var lastTerritoriesCount: Int = -1

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：用户位置更新时调用
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else {
                print("🗺️ [地图] 用户位置为空")
                return
            }

            let coordinate = location.coordinate
            print("🗺️ [地图] 用户位置更新: (\(coordinate.latitude), \(coordinate.longitude))")

            // 更新绑定的位置（在主线程）
            DispatchQueue.main.async {
                self.parent.userLocation = coordinate
            }

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else { return }

            print("🗺️ [地图] 首次定位，自动居中地图...")

            // 创建居中区域（约1公里范围）
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }

            print("🗺️ [地图] 首次居中完成")
        }

        /// 地图区域变化回调
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可以在这里获取当前地图中心坐标
            // let center = mapView.centerCoordinate
            // print("🗺️ [地图] 地图区域变化: (\(center.latitude), \(center.longitude))")
        }

        /// 地图加载完成回调
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("🗺️ [地图] 地图加载完成")
        }

        /// 地图渲染完成回调
        func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
            if fullyRendered {
                print("🗺️ [地图] 地图渲染完成")
            }
        }

        /// 定位用户失败回调
        func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
            print("🗺️ [地图] 定位用户失败: \(error.localizedDescription)")
        }

        /// ⭐ 关键方法：渲染覆盖物（轨迹线 + 多边形）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 渲染多边形（领地 + 当前绘制的闭环区域）
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2.0
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                    renderer.lineWidth = 2.0
                } else {
                    // 当前绘制的闭环区域：绿色（稍粗）
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 3.0
                }

                return renderer
            }

            // 渲染折线（轨迹边框）
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 根据闭环状态选择颜色
                if parent.isPathClosed {
                    // 已闭环：绿色轨迹线
                    renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.9)
                    renderer.lineWidth = 4.0
                    print("🗺️ [地图] 渲染闭环轨迹（绿色）")
                } else if parent.isTracking {
                    // 追踪中：青色虚线
                    renderer.strokeColor = UIColor.systemCyan.withAlphaComponent(0.8)
                    renderer.lineWidth = 4.0
                    renderer.lineDashPattern = [8, 4]  // 8像素实线，4像素间隔
                    print("🗺️ [地图] 渲染追踪轨迹（青色虚线）")
                } else {
                    // 停止追踪但未闭环：青色实线
                    renderer.strokeColor = UIColor.systemCyan.withAlphaComponent(0.8)
                    renderer.lineWidth = 4.0
                    print("🗺️ [地图] 渲染停止轨迹（青色实线）")
                }

                renderer.lineCap = .round
                renderer.lineJoin = .round

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        centerCoordinate: .constant(nil),
        trackingPath: .constant([]),
        pathUpdateVersion: 0,
        isTracking: false,
        isPathClosed: false,
        territories: [],
        currentUserId: nil
    )
}
