//
//  CoordinateConverter.swift
//  EarthLord
//
//  WGS-84 → GCJ-02 坐标转换工具
//  用于修正中国地图的 GPS 偏移问题
//

import Foundation
import CoreLocation

/// 坐标转换工具
/// 将 WGS-84 坐标（GPS 原始坐标）转换为 GCJ-02 坐标（中国地图坐标）
struct CoordinateConverter {

    // MARK: - 常量

    /// 地球长半轴（米）
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    /// 圆周率
    private static let pi: Double = Double.pi

    // MARK: - 公开方法

    /// 将 WGS-84 坐标转换为 GCJ-02 坐标
    /// - Parameter wgs84: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图坐标）
    static func wgs84ToGcj02(_ wgs84: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果在中国境外，直接返回原坐标
        guard isInChina(wgs84) else {
            return wgs84
        }

        let lat = wgs84.latitude
        let lon = wgs84.longitude

        // 计算偏移量
        var dLat = transformLat(lon - 105.0, lat - 35.0)
        var dLon = transformLon(lon - 105.0, lat - 35.0)

        let radLat = lat / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        let gcj02Lat = lat + dLat
        let gcj02Lon = lon + dLon

        return CLLocationCoordinate2D(latitude: gcj02Lat, longitude: gcj02Lon)
    }

    /// 将 GCJ-02 坐标转换为 WGS-84 坐标（反向转换，精度稍低）
    /// - Parameter gcj02: GCJ-02 坐标（中国地图坐标）
    /// - Returns: WGS-84 坐标（GPS 原始坐标）
    static func gcj02ToWgs84(_ gcj02: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果在中国境外，直接返回原坐标
        guard isInChina(gcj02) else {
            return gcj02
        }

        // 使用迭代法进行反向转换
        let gcj02Converted = wgs84ToGcj02(gcj02)
        let dLat = gcj02Converted.latitude - gcj02.latitude
        let dLon = gcj02Converted.longitude - gcj02.longitude

        return CLLocationCoordinate2D(
            latitude: gcj02.latitude - dLat,
            longitude: gcj02.longitude - dLon
        )
    }

    /// 批量转换坐标数组（WGS-84 → GCJ-02）
    /// - Parameter coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func convertPath(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - 私有方法

    /// 判断坐标是否在中国境内
    /// - Parameter coordinate: 坐标
    /// - Returns: 是否在中国境内
    private static func isInChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // 简单的边界判断（中国大致范围）
        // 纬度：3.86°N ~ 53.55°N
        // 经度：73.66°E ~ 135.05°E
        return lon > 73.66 && lon < 135.05 && lat > 3.86 && lat < 53.55
    }

    /// 纬度偏移转换
    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度偏移转换
    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
