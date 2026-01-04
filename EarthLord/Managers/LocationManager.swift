//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器
//  负责请求定位权限、获取用户位置、处理定位错误
//  支持路径追踪功能（圈地）
//

import Foundation
import CoreLocation
import Combine

/// GPS 定位管理器
final class LocationManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = LocationManager()

    // MARK: - Published 属性

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在定位
    @Published var isUpdatingLocation: Bool = false

    /// 是否正在记录轨迹（圈地模式）
    @Published var isTracking: Bool = false

    /// 轨迹坐标数组（WGS-84 原始坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 轨迹更新版本号（用于触发地图重绘）
    @Published var pathUpdateVersion: Int = 0

    // MARK: - 私有属性

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 访问）
    private var currentLocation: CLLocation?

    /// 轨迹采样定时器
    private var pathUpdateTimer: Timer?

    /// 最小记录距离（米）- 防止原地抖动产生过多点
    private let minimumRecordDistance: CLLocationDistance = 3.0

    /// 轨迹采样间隔（秒）
    private let pathSamplingInterval: TimeInterval = 1.0

    // MARK: - 计算属性

    /// 是否已授权定位（包括"使用时"和"始终"）
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被用户拒绝定位权限
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    /// 是否尚未决定（首次请求权限）
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    // MARK: - 初始化

    private override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动10米才更新位置

        print("📍 [定位] LocationManager 初始化完成，当前授权状态: \(authorizationStatus.description)")
    }

    // MARK: - 公开方法

    /// 请求定位权限（使用App期间）
    func requestPermission() {
        print("📍 [定位] 请求定位权限...")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始持续定位
    func startUpdatingLocation() {
        guard isAuthorized else {
            print("📍 [定位] 未授权，无法开始定位")
            locationError = "未获得定位权限"
            return
        }

        print("📍 [定位] 开始持续定位...")
        isUpdatingLocation = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }

    /// 停止定位
    func stopUpdatingLocation() {
        print("📍 [定位] 停止定位")
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    /// 请求单次定位
    func requestOneTimeLocation() {
        guard isAuthorized else {
            print("📍 [定位] 未授权，无法请求定位")
            locationError = "未获得定位权限"
            return
        }

        print("📍 [定位] 请求单次定位...")
        locationError = nil
        locationManager.requestLocation()
    }

    /// 检查并请求权限（如果需要）
    func checkAndRequestPermission() {
        if isNotDetermined {
            requestPermission()
        } else if isAuthorized {
            startUpdatingLocation()
        }
    }

    // MARK: - 轨迹追踪方法

    /// 开始记录轨迹（圈地模式）
    func startPathTracking() {
        guard isAuthorized else {
            print("📍 [轨迹] 未授权，无法开始记录轨迹")
            locationError = "未获得定位权限"
            return
        }

        guard !isTracking else {
            print("📍 [轨迹] 已在记录中，忽略重复调用")
            return
        }

        print("📍 [轨迹] 开始记录轨迹...")
        isTracking = true

        // 清空之前的轨迹
        clearPath()

        // 确保定位服务已开启
        if !isUpdatingLocation {
            startUpdatingLocation()
        }

        // 设置更高精度的定位参数
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 1  // 1米更新一次

        // 记录起始点
        if let location = currentLocation {
            recordPathPoint(location)
        }

        // 启动定时采样器
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: pathSamplingInterval, repeats: true) { [weak self] _ in
            self?.sampleCurrentLocation()
        }
    }

    /// 停止记录轨迹
    func stopPathTracking() {
        guard isTracking else {
            print("📍 [轨迹] 未在记录中，忽略停止调用")
            return
        }

        print("📍 [轨迹] 停止记录轨迹，共记录 \(pathCoordinates.count) 个点")
        isTracking = false

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 恢复正常定位参数
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10

        // 更新版本号，触发轨迹重绘（从虚线变为实线）
        pathUpdateVersion += 1
    }

    /// 清空轨迹
    func clearPath() {
        print("📍 [轨迹] 清空轨迹")
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
    }

    /// 记录当前位置到轨迹
    /// - Parameter location: 位置
    private func recordPathPoint(_ location: CLLocation) {
        let coordinate = location.coordinate

        // 检查与上一个点的距离，防止原地抖动
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = location.distance(from: lastLocation)

            if distance < minimumRecordDistance {
                // 距离太近，忽略这个点
                return
            }
        }

        // 记录坐标
        pathCoordinates.append(coordinate)
        pathUpdateVersion += 1

        print("📍 [轨迹] 记录点 #\(pathCoordinates.count): (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))")
    }

    /// 采样当前位置（定时器回调）
    private func sampleCurrentLocation() {
        guard isTracking, let location = currentLocation else { return }
        recordPathPoint(location)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化回调
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        print("📍 [定位] 授权状态变化: \(authorizationStatus.description) → \(newStatus.description)")

        DispatchQueue.main.async {
            self.authorizationStatus = newStatus

            // 如果刚授权，自动开始定位
            if self.isAuthorized && !self.isUpdatingLocation {
                self.startUpdatingLocation()
            }

            // 如果被拒绝，设置错误信息
            if self.isDenied {
                self.locationError = "定位权限被拒绝，请在设置中开启"
            }
        }
    }

    /// 位置更新回调
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let coordinate = location.coordinate
        print("📍 [定位] 获取到位置: (\(coordinate.latitude), \(coordinate.longitude))")

        // 存储当前位置（用于 Timer 采样）
        self.currentLocation = location

        DispatchQueue.main.async {
            self.userLocation = coordinate
            self.locationError = nil
        }
    }

    /// 定位失败回调
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 [定位] 定位失败: \(error.localizedDescription)")

        DispatchQueue.main.async {
            // 区分错误类型
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "定位权限被拒绝"
                case .locationUnknown:
                    self.locationError = "无法获取位置，请稍后重试"
                case .network:
                    self.locationError = "网络错误，无法定位"
                default:
                    self.locationError = "定位失败: \(clError.localizedDescription)"
                }
            } else {
                self.locationError = "定位失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - CLAuthorizationStatus 扩展

extension CLAuthorizationStatus {
    /// 授权状态的中文描述
    var description: String {
        switch self {
        case .notDetermined:
            return "未决定"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用时允许"
        @unknown default:
            return "未知状态"
        }
    }
}
