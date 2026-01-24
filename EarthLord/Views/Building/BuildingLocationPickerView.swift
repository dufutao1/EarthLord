//
//  BuildingLocationPickerView.swift
//  EarthLord
//
//  建筑位置选择器 - 简化版本
//

import SwiftUI
import MapKit

// MARK: - 建筑位置选择器

struct BuildingLocationPickerView: UIViewRepresentable {
    let territoryCoordinates: [CLLocationCoordinate2D]
    let existingBuildings: [PlayerBuilding]
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    var initialCenter: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        print("🗺️ [LocationPicker] makeUIView 开始")

        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false  // 暂时关闭，避免权限问题
        mapView.mapType = .standard
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false

        print("🗺️ [LocationPicker] MKMapView 基础配置完成")

        // 🔄 坐标转换：数据库保存的是 WGS-84，需要转换为 GCJ-02 显示
        var convertedCoords = territoryCoordinates.map { coord in
            CoordinateConverter.wgs84ToGcj02(coord)
        }

        print("🗺️ [LocationPicker] 原始坐标（前3个点）:")
        for (index, coord) in territoryCoordinates.prefix(3).enumerated() {
            print("  点\(index+1): (\(coord.latitude), \(coord.longitude))")
        }
        print("🗺️ [LocationPicker] 转换后坐标（前3个点）:")
        for (index, coord) in convertedCoords.prefix(3).enumerated() {
            print("  点\(index+1): (\(coord.latitude), \(coord.longitude))")
        }

        // 安全添加领地多边形
        if convertedCoords.count >= 3 {
            print("🗺️ [LocationPicker] 准备添加多边形，坐标数: \(convertedCoords.count)")
            let polygon = convertedCoords.withUnsafeMutableBufferPointer { buffer -> MKPolygon in
                MKPolygon(coordinates: buffer.baseAddress!, count: buffer.count)
            }
            polygon.title = "territory"
            mapView.addOverlay(polygon)
            print("🗺️ [LocationPicker] 多边形已添加")
        } else {
            print("⚠️ [LocationPicker] 领地坐标不足3个")
        }

        // 设置初始区域（使用转换后的坐标）
        let center = initialCenter ?? calculateCenter(from: convertedCoords)
        let span = calculateSpan(from: convertedCoords)
        print("🗺️ [LocationPicker] 设置区域 - 中心: (\(center.latitude), \(center.longitude)), span: (\(span.latitudeDelta), \(span.longitudeDelta))")

        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: false)

        // 添加长按手势（0.3秒，更接近点击体验）
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.3
        mapView.addGestureRecognizer(longPress)

        print("🗺️ [LocationPicker] makeUIView 完成")
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 只在选中坐标变化时更新标记
        context.coordinator.updateSelectedAnnotation(mapView: mapView, coordinate: selectedCoordinate)
    }

    func makeCoordinator() -> Coordinator {
        print("🗺️ [LocationPicker] makeCoordinator 被调用")
        return Coordinator(self)
    }

    private func calculateCenter(from coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
            return CLLocationCoordinate2D(latitude: 31.23, longitude: 121.47)  // 默认上海
        }
        let lat = coordinates.map { $0.latitude }.reduce(0, +) / Double(coordinates.count)
        let lon = coordinates.map { $0.longitude }.reduce(0, +) / Double(coordinates.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func calculateSpan(from coordinates: [CLLocationCoordinate2D]) -> MKCoordinateSpan {
        guard coordinates.count >= 2 else {
            return MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        let latDelta = ((lats.max() ?? 0) - (lats.min() ?? 0)) * 2.0
        let lonDelta = ((lons.max() ?? 0) - (lons.min() ?? 0)) * 2.0
        return MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.005),
            longitudeDelta: max(lonDelta, 0.005)
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: BuildingLocationPickerView
        private var selectedAnnotation: SelectedLocationAnnotation?

        init(_ parent: BuildingLocationPickerView) {
            self.parent = parent
            super.init()
            print("🗺️ [LocationPicker] Coordinator 初始化完成")
        }

        // MARK: - 更新选中标记

        func updateSelectedAnnotation(mapView: MKMapView, coordinate: CLLocationCoordinate2D?) {
            if let coord = coordinate {
                // 如果已有标记，需要移除后重新添加以触发地图更新
                if let existing = selectedAnnotation {
                    mapView.removeAnnotation(existing)
                    existing.coordinate = coord
                    mapView.addAnnotation(existing)
                    print("🗺️ [LocationPicker] 已更新选中标记位置")
                } else {
                    // 创建新标记
                    let annotation = SelectedLocationAnnotation()
                    annotation.coordinate = coord
                    annotation.title = "建造位置"
                    mapView.addAnnotation(annotation)
                    selectedAnnotation = annotation
                    print("🗺️ [LocationPicker] 已添加选中标记")
                }
            } else {
                // 移除标记
                if let existing = selectedAnnotation {
                    mapView.removeAnnotation(existing)
                    selectedAnnotation = nil
                    print("🗺️ [LocationPicker] 已移除选中标记")
                }
            }
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            // 只在开始时处理（避免多次触发）
            guard gesture.state == .began else { return }

            guard let mapView = gesture.view as? MKMapView else {
                print("❌ [LocationPicker] gesture.view 不是 MKMapView")
                return
            }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            print("🗺️ [LocationPicker] 长按位置（GCJ-02）: (\(coordinate.latitude), \(coordinate.longitude))")

            // 🔄 转换领地坐标为 GCJ-02，与地图坐标系一致
            let convertedTerritoryCoords = parent.territoryCoordinates.map { coord in
                CoordinateConverter.wgs84ToGcj02(coord)
            }

            // 检查是否在领地内（都是 GCJ-02 坐标系）
            if isPointInPolygon(coordinate, polygon: convertedTerritoryCoords) {
                print("✅ [LocationPicker] 位置在领地内，更新选中坐标")

                // 在主线程更新绑定值
                DispatchQueue.main.async {
                    self.parent.selectedCoordinate = coordinate
                }

                // 成功震动反馈
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                print("⚠️ [LocationPicker] 位置不在领地内")
                // 警告震动反馈
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }

        private func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
            guard polygon.count >= 3 else { return false }
            var isInside = false
            var j = polygon.count - 1
            for i in 0..<polygon.count {
                let xi = polygon[i].longitude, yi = polygon[i].latitude
                let xj = polygon[j].longitude, yj = polygon[j].latitude
                if ((yi > point.latitude) != (yj > point.latitude)) &&
                   (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                    isInside = !isInside
                }
                j = i
            }
            return isInside
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            print("🗺️ [LocationPicker] rendererFor overlay 被调用")
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if annotation is SelectedLocationAnnotation {
                let id = "SelectedLocation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                }
                view?.annotation = annotation
                view?.markerTintColor = .systemGreen
                view?.glyphImage = UIImage(systemName: "plus.circle.fill")
                return view
            }
            return nil
        }

        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("🗺️ [LocationPicker] 地图加载完成")
        }

        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            print("❌ [LocationPicker] 地图加载失败: \(error)")
        }
    }
}

// MARK: - 选中位置标记

class SelectedLocationAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate = CLLocationCoordinate2D()
    var title: String?
    var subtitle: String?
}

