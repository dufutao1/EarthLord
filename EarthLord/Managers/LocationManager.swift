//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器
//  负责请求定位权限、获取用户位置、处理定位错误
//  支持路径追踪功能（圈地）+ 闭环检测 + 速度检测
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

    /// 轨迹是否已闭环（走回起点）
    @Published var isPathClosed: Bool = false

    /// 是否可以闭环（满足所有条件，等待用户确认）
    @Published var canClosePath: Bool = false

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算得到的领地面积（平方米）
    @Published var calculatedArea: Double = 0

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

    /// 闭环距离阈值（米）- 距离起点多近算闭环
    private let closureDistanceThreshold: CLLocationDistance = 30.0

    /// 最少路径点数 - 至少需要多少个点才能判断闭环
    private let minimumPathPoints: Int = 10

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    /// 速度警告阈值（km/h）
    private let speedWarningThreshold: Double = 15.0

    /// 速度停止阈值（km/h）- 超过此速度自动停止追踪
    private let speedStopThreshold: Double = 30.0

    /// 上次位置的时间戳（用于计算速度）
    private var lastLocationTimestamp: Date?

    /// 上次位置（用于计算速度）
    private var lastRecordedLocation: CLLocation?

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

        // 记录日志
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

        // 清空之前的轨迹
        clearPath()

        // 重置闭环状态
        isPathClosed = false
        canClosePath = false

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 重置速度检测状态
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
        lastRecordedLocation = nil

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

        // 记录日志
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)

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
        // 如果已经闭环，不再记录新点
        guard !isPathClosed else {
            print("📍 [轨迹] 已闭环，停止记录新点")
            return
        }

        // 速度检测（跳过第一个点）
        if !pathCoordinates.isEmpty {
            let isSpeedValid = validateMovementSpeed(newLocation: location)
            if !isSpeedValid {
                print("📍 [轨迹] 速度异常，忽略此点")
                return
            }
        }

        let coordinate = location.coordinate

        // 检查与上一个点的距离，防止原地抖动
        var distanceFromLast: CLLocationDistance = 0
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            distanceFromLast = location.distance(from: lastLocation)

            if distanceFromLast < minimumRecordDistance {
                // 距离太近，忽略这个点
                return
            }
        }

        // 记录坐标
        pathCoordinates.append(coordinate)
        pathUpdateVersion += 1

        // 更新上次记录的位置和时间戳（用于速度计算）
        lastRecordedLocation = location
        lastLocationTimestamp = Date()

        print("📍 [轨迹] 记录点 #\(pathCoordinates.count): (\(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude)))")

        // 记录日志
        TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distanceFromLast))m", type: .info)

        // 检查是否闭环
        checkPathClosure()
    }

    /// 采样当前位置（定时器回调）
    private func sampleCurrentLocation() {
        guard isTracking, let location = currentLocation else { return }
        recordPathPoint(location)
    }

    // MARK: - 闭环检测

    /// 检查是否满足闭环条件（不自动闭环，只更新 canClosePath 状态）
    /// 闭环条件：点数 >= 10 且 总距离 >= 50m 且 面积 >= 100m² 且 距起点 <= 30m
    private func checkPathClosure() {
        // 已经闭环则不再检查
        guard !isPathClosed else { return }

        // 条件1：检查点数是否足够（>= 10）
        guard pathCoordinates.count >= minimumPathPoints else {
            canClosePath = false
            return
        }

        // 条件2：检查总距离是否足够（>= 50m）
        let totalDistance = calculateTotalPathDistance()
        guard totalDistance >= minimumTotalDistance else {
            canClosePath = false
            return
        }

        // 条件3：检查面积是否足够（>= 100m²）
        let area = calculatePolygonArea()
        guard area >= minimumEnclosedArea else {
            canClosePath = false
            return
        }

        // 获取起点和当前点
        guard let startPoint = pathCoordinates.first,
              let currentPoint = pathCoordinates.last else {
            canClosePath = false
            return
        }

        // 计算当前位置到起点的距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distanceToStart = currentLocation.distance(from: startLocation)

        // 条件4：判断是否在闭环范围内（距起点 <= 30m）
        if distanceToStart <= closureDistanceThreshold {
            // 满足所有条件，可以闭环
            if !canClosePath {
                // 首次进入可闭环范围，记录日志
                print("📍 [闭环] ✅ 可以闭环！面积 \(String(format: "%.0f", area))m², 距起点 \(String(format: "%.1f", distanceToStart))m")
                TerritoryLogger.shared.log("可以闭环！面积 \(String(format: "%.0f", area))m², 点击按钮确认", type: .success)
            }
            canClosePath = true
        } else {
            // 离开闭环范围
            if canClosePath {
                print("📍 [闭环] ⚠️ 离开闭环范围，距起点 \(String(format: "%.1f", distanceToStart))m")
                TerritoryLogger.shared.log("离开闭环范围，距起点 \(String(format: "%.1f", distanceToStart))m", type: .warning)
            }
            canClosePath = false
        }
    }

    /// 用户确认闭环（手动触发）
    func confirmPathClosure() {
        // 检查是否满足闭环条件
        guard canClosePath else {
            print("📍 [闭环] ❌ 当前不满足闭环条件")
            TerritoryLogger.shared.log("闭环失败：不满足闭环条件", type: .error)
            return
        }

        let area = calculatePolygonArea()
        let totalDistance = calculateTotalPathDistance()

        print("📍 [闭环] ✅ 用户确认闭环！面积 \(String(format: "%.0f", area))m²")
        TerritoryLogger.shared.log("用户确认闭环！面积 \(String(format: "%.0f", area))m²", type: .success)

        isPathClosed = true
        canClosePath = false
        pathUpdateVersion += 1  // 触发地图重绘

        // 停止追踪
        stopPathTracking()

        // 触发领地验证（主要检测自交）
        let validationResult = validateTerritory()
        territoryValidationPassed = validationResult.isValid
        territoryValidationError = validationResult.errorMessage

        // 记录最终结果
        if validationResult.isValid {
            TerritoryLogger.shared.log("🎉 领地占领成功！面积 \(String(format: "%.0f", area))m²", type: .success)
        }
    }

    // MARK: - 速度检测

    /// 验证移动速度是否正常
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 如果没有上次位置记录，初始化并返回正常
        guard let lastLocation = lastRecordedLocation,
              let lastTimestamp = lastLocationTimestamp else {
            lastRecordedLocation = newLocation
            lastLocationTimestamp = Date()
            return true
        }

        // 计算距离（米）
        let distance = newLocation.distance(from: lastLocation)

        // 计算时间差（秒）
        let timeInterval = Date().timeIntervalSince(lastTimestamp)

        // 防止除以零
        guard timeInterval > 0 else { return true }

        // 计算速度（m/s → km/h）
        let speedMps = distance / timeInterval
        let speedKmh = speedMps * 3.6

        print("📍 [速度] \(String(format: "%.1f", speedKmh)) km/h (距离: \(String(format: "%.1f", distance))m, 时间: \(String(format: "%.1f", timeInterval))s)")

        // 检查是否超过停止阈值（30 km/h）
        if speedKmh > speedStopThreshold {
            print("📍 [速度] ⛔ 严重超速！自动停止追踪")

            // 记录错误日志
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speedKmh)) km/h，已停止追踪", type: .error)

            DispatchQueue.main.async {
                self.speedWarning = "速度过快（\(String(format: "%.0f", speedKmh))km/h），已停止追踪"
                self.isOverSpeed = true
            }
            stopPathTracking()
            return false
        }

        // 检查是否超过警告阈值（15 km/h）
        if speedKmh > speedWarningThreshold {
            print("📍 [速度] ⚠️ 速度警告：\(String(format: "%.1f", speedKmh)) km/h")

            // 记录警告日志
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speedKmh)) km/h", type: .warning)

            DispatchQueue.main.async {
                self.speedWarning = "移动速度较快（\(String(format: "%.0f", speedKmh))km/h），请步行圈地"
                self.isOverSpeed = true

                // 3秒后自动清除警告
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.isTracking {
                        self.speedWarning = nil
                        self.isOverSpeed = false
                    }
                }
            }
            // 警告但仍然记录点
            return true
        }

        // 速度正常，清除警告
        if isOverSpeed {
            DispatchQueue.main.async {
                self.speedWarning = nil
                self.isOverSpeed = false
            }
        }

        return true
    }

    // MARK: - 距离与面积计算

    /// 计算轨迹总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = pathCoordinates[i]
            let next = pathCoordinates[i + 1]

            let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let nextLocation = CLLocation(latitude: next.latitude, longitude: next.longitude)

            totalDistance += currentLocation.distance(from: nextLocation)
        }

        return totalDistance
    }

    /// 计算多边形面积（使用鞋带公式，考虑地球曲率）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        // 地球半径（米）
        let earthRadius: Double = 6371000

        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        // 取绝对值并计算最终面积
        area = abs(area * earthRadius * earthRadius / 2.0)

        return area
    }

    // MARK: - 自相交检测

    /// 判断两线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 第一条线段起点
    ///   - p2: 第一条线段终点
    ///   - p3: 第二条线段起点
    ///   - p4: 第二条线段终点
    /// - Returns: true = 相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        /// CCW 辅助函数：判断三点是否逆时针排列
        /// 坐标映射：longitude = X轴，latitude = Y轴
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            // 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                               (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 判断两线段是否相交：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测轨迹是否自相交
    /// - Returns: true = 存在自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（防止正常圈地被误判为自交）
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            // ✅ 循环内索引检查
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            // 对比每条非相邻线段
            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                // ✅ 循环内索引检查
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较（防止闭环时误判）
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: (isValid: 是否有效, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let error = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败！\(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let error = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(Int(minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败！\(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let error = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败！\(error)", type: .error)
            return (false, error)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        if area < minimumEnclosedArea {
            let error = "面积不足: \(String(format: "%.0f", area))m² (需≥\(Int(minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(error)", type: .error)
            TerritoryLogger.shared.log("领地验证失败！\(error)", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // 保存计算的面积
        calculatedArea = area

        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        return (true, nil)
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
