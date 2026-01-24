//
//  TerritoryMapView.swift
//  EarthLord
//
//  领地地图组件
//  使用 UIKit MKMapView 渲染领地多边形和建筑标记
//  注意：领地坐标已经是 GCJ-02，不需要再做转换
//

import SwiftUI
import MapKit

// MARK: - 领地地图组件

struct TerritoryMapView: UIViewRepresentable {
    /// 领地边界坐标（已经是 GCJ-02）
    let territoryCoordinates: [CLLocationCoordinate2D]

    /// 领地内的建筑列表
    let buildings: [PlayerBuilding]

    /// 是否显示用户位置
    var showsUserLocation: Bool = true

    /// 地图类型
    var mapType: MKMapType = .standard

    /// 建筑点击回调
    var onBuildingTap: ((PlayerBuilding) -> Void)?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.mapType = mapType
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true

        // 🔄 坐标转换：数据库保存的是 WGS-84，需要转换为 GCJ-02 显示
        var convertedCoords = territoryCoordinates.map { coord in
            CoordinateConverter.wgs84ToGcj02(coord)
        }

        print("🗺️ [TerritoryMap] 原始坐标（前3个点）:")
        for (index, coord) in territoryCoordinates.prefix(3).enumerated() {
            print("  点\(index+1): (\(coord.latitude), \(coord.longitude))")
        }
        print("🗺️ [TerritoryMap] 转换后坐标（前3个点）:")
        for (index, coord) in convertedCoords.prefix(3).enumerated() {
            print("  点\(index+1): (\(coord.latitude), \(coord.longitude))")
        }

        // 添加领地多边形
        if convertedCoords.count >= 3 {
            let polygon = convertedCoords.withUnsafeMutableBufferPointer { buffer -> MKPolygon in
                MKPolygon(coordinates: buffer.baseAddress!, count: buffer.count)
            }
            polygon.title = "territory"
            mapView.addOverlay(polygon)
            print("🗺️ [TerritoryMap] ✅ 领地多边形已添加，点数: \(polygon.pointCount)")
        }

        // 设置初始区域（使用转换后的坐标计算中心）
        let center = calculateCenter(from: convertedCoords)
        let span = calculateSpan(from: convertedCoords)
        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新建筑标记
        updateBuildingAnnotations(mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 更新建筑标记

    private func updateBuildingAnnotations(_ mapView: MKMapView) {
        // 移除旧的建筑标记
        let existingAnnotations = mapView.annotations.compactMap { $0 as? TerritoryBuildingAnnotation }
        mapView.removeAnnotations(existingAnnotations)

        // 添加新的建筑标记
        for building in buildings {
            guard let coord = building.coordinate else { continue }

            // 🔄 坐标转换：数据库保存的是 WGS-84，转换为 GCJ-02 显示
            let gcj02Coord = CoordinateConverter.wgs84ToGcj02(coord)
            print("🗺️ [TerritoryMap] 建筑 '\(building.buildingName)' WGS-84: (\(coord.latitude), \(coord.longitude)) → GCJ-02: (\(gcj02Coord.latitude), \(gcj02Coord.longitude))")

            let annotation = TerritoryBuildingAnnotation(building: building)
            annotation.coordinate = gcj02Coord
            mapView.addAnnotation(annotation)
        }
    }

    // MARK: - 计算中心点

    private func calculateCenter(from coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
            return CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        }

        var totalLat = 0.0
        var totalLon = 0.0

        for coord in coordinates {
            totalLat += coord.latitude
            totalLon += coord.longitude
        }

        return CLLocationCoordinate2D(
            latitude: totalLat / Double(coordinates.count),
            longitude: totalLon / Double(coordinates.count)
        )
    }

    // MARK: - 计算缩放范围

    private func calculateSpan(from coordinates: [CLLocationCoordinate2D]) -> MKCoordinateSpan {
        guard coordinates.count >= 2 else {
            return MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let latDelta = (maxLat - minLat) * 1.8
        let lonDelta = (maxLon - minLon) * 1.8

        return MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.003),
            longitudeDelta: max(lonDelta, 0.003)
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TerritoryMapView

        init(_ parent: TerritoryMapView) {
            self.parent = parent
        }

        // MARK: - 渲染覆盖物（多边形）

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.15)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: - 渲染标记（建筑）

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认样式
            if annotation is MKUserLocation {
                return nil
            }

            // 建筑标记
            if let buildingAnnotation = annotation as? TerritoryBuildingAnnotation {
                let identifier = "TerritoryBuilding"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: buildingAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                }

                view?.annotation = buildingAnnotation

                // 根据状态设置颜色
                let building = buildingAnnotation.building
                if building.status == .constructing {
                    view?.markerTintColor = .systemYellow
                    view?.glyphImage = UIImage(systemName: "hammer.fill")
                } else {
                    view?.markerTintColor = .systemGreen
                    view?.glyphImage = UIImage(systemName: building.template?.icon ?? "building.2.fill")
                }

                // 添加详情按钮
                let detailButton = UIButton(type: .detailDisclosure)
                view?.rightCalloutAccessoryView = detailButton

                return view
            }

            return nil
        }

        // MARK: - 标记点击

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let buildingAnnotation = view.annotation as? TerritoryBuildingAnnotation {
                parent.onBuildingTap?(buildingAnnotation.building)
            }
        }
    }
}

// MARK: - 领地建筑标记

class TerritoryBuildingAnnotation: NSObject, MKAnnotation {
    let building: PlayerBuilding
    @objc dynamic var coordinate: CLLocationCoordinate2D

    var title: String? {
        building.buildingName
    }

    var subtitle: String? {
        if building.status == .constructing {
            return "建造中..."
        }
        return "Lv.\(building.level)"
    }

    init(building: PlayerBuilding) {
        self.building = building
        self.coordinate = building.coordinate ?? CLLocationCoordinate2D()
        super.init()
    }
}

// MARK: - 预览

#Preview {
    let territoryCoords: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 39.9100, longitude: 116.4000),
        CLLocationCoordinate2D(latitude: 39.9100, longitude: 116.4020),
        CLLocationCoordinate2D(latitude: 39.9080, longitude: 116.4020),
        CLLocationCoordinate2D(latitude: 39.9080, longitude: 116.4000)
    ]

    return TerritoryMapView(
        territoryCoordinates: territoryCoords,
        buildings: []
    )
    .frame(height: 400)
}
