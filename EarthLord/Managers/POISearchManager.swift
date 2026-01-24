//
//  POISearchManager.swift
//  EarthLord
//
//  POI 搜索管理器
//  使用 MapKit 搜索附近真实地点
//

import Foundation
import MapKit
import CoreLocation

// MARK: - 搜索到的 POI 模型

/// 从 MapKit 搜索到的真实 POI
struct SearchedPOI: Identifiable, Equatable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: POICategory
    let mapItem: MKMapItem

    /// 是否已被搜刮
    var isScavenged: Bool = false

    /// 距离用户的距离（米）
    var distance: CLLocationDistance = 0

    static func == (lhs: SearchedPOI, rhs: SearchedPOI) -> Bool {
        lhs.id == rhs.id
    }
}

/// POI 类别
enum POICategory: String, CaseIterable {
    case store = "store"
    case hospital = "hospital"
    case pharmacy = "pharmacy"
    case gasStation = "gasStation"
    case restaurant = "restaurant"
    case cafe = "cafe"

    /// 显示名称
    var displayName: String {
        switch self {
        case .store: return "商店"
        case .hospital: return "医院"
        case .pharmacy: return "药店"
        case .gasStation: return "加油站"
        case .restaurant: return "餐厅"
        case .cafe: return "咖啡店"
        }
    }

    /// 地图标记图标
    var icon: String {
        switch self {
        case .store: return "bag.fill"
        case .hospital: return "cross.case.fill"
        case .pharmacy: return "pills.fill"
        case .gasStation: return "fuelpump.fill"
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        }
    }

    /// 标记颜色
    var color: String {
        switch self {
        case .store: return "green"
        case .hospital: return "red"
        case .pharmacy: return "purple"
        case .gasStation: return "orange"
        case .restaurant: return "yellow"
        case .cafe: return "brown"
        }
    }

    /// 对应的 MKPointOfInterestCategory
    var mapKitCategory: MKPointOfInterestCategory {
        switch self {
        case .store: return .store
        case .hospital: return .hospital
        case .pharmacy: return .pharmacy
        case .gasStation: return .gasStation
        case .restaurant: return .restaurant
        case .cafe: return .cafe
        }
    }

    /// 搜索关键词数组（用于多次自然语言搜索，提高覆盖率）
    var searchKeywords: [String] {
        switch self {
        case .store: return ["超市", "便利店", "商店"]
        case .hospital: return ["医院", "诊所"]
        case .pharmacy: return ["药店", "药房", "大药房"]
        case .gasStation: return ["加油站", "中石油", "中石化"]
        case .restaurant: return ["餐厅", "饭店", "美食"]
        case .cafe: return ["咖啡", "奶茶", "茶饮"]
        }
    }

    /// 危险等级（1-5，影响物品稀有度）
    /// 1-2: 低危（便利店、咖啡店）
    /// 3: 中危（超市、餐厅）
    /// 4: 高危（医院、药店）
    /// 5: 极危（暂无）
    var dangerLevel: Int {
        switch self {
        case .cafe: return 1
        case .restaurant: return 2
        case .store: return 3
        case .gasStation: return 3
        case .pharmacy: return 4
        case .hospital: return 4
        }
    }
}

// MARK: - POI 搜索管理器

/// POI 搜索管理器（单例）
/// 使用 MapKit 搜索附近真实地点
class POISearchManager {

    // MARK: - 单例

    static let shared = POISearchManager()

    // MARK: - 常量

    /// 搜索半径（米）- 增大到1500米以获取更多结果
    private let searchRadius: CLLocationDistance = 1500

    /// 每种类型最多返回的数量 - 增加到10个
    private let maxResultsPerCategory: Int = 10

    /// 总共最多返回的数量 - iOS 地理围栏限制 20 个，留 2 个余量
    private let maxTotalResults: Int = 18

    // MARK: - 初始化

    private init() {
        log("POISearchManager 初始化完成")
    }

    // MARK: - 日志

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] [POI搜索] \(message)")
    }

    // MARK: - 公开方法

    /// 搜索附近的 POI
    /// - Parameters:
    ///   - location: 搜索中心点
    ///   - maxResults: 最大返回数量（可选，默认使用 maxTotalResults）
    /// - Returns: 搜索到的 POI 列表
    func searchNearbyPOIs(around location: CLLocationCoordinate2D, maxResults: Int? = nil) async -> [SearchedPOI] {
        let effectiveMaxResults = maxResults ?? maxTotalResults
        log("开始搜索附近 POI，中心点: (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))，上限: \(effectiveMaxResults)")

        var allPOIs: [SearchedPOI] = []

        // 搜索多种类型
        let categoriesToSearch: [POICategory] = [.store, .hospital, .pharmacy, .gasStation, .restaurant, .cafe]

        for category in categoriesToSearch {
            let pois = await searchPOIs(category: category, around: location)
            allPOIs.append(contentsOf: pois)
            log("  \(category.displayName): 找到 \(pois.count) 个")
        }

        // 按距离排序
        let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        allPOIs = allPOIs.map { poi in
            var mutablePOI = poi
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            mutablePOI.distance = userLocation.distance(from: poiLocation)
            return mutablePOI
        }.sorted { $0.distance < $1.distance }

        // 去重（基于名称和坐标）
        var uniquePOIs: [SearchedPOI] = []
        var seenIds = Set<String>()
        for poi in allPOIs {
            if !seenIds.contains(poi.id) {
                uniquePOIs.append(poi)
                seenIds.insert(poi.id)
            }
        }

        // 限制总数量（使用传入的上限或默认值）
        let limitedPOIs = Array(uniquePOIs.prefix(effectiveMaxResults))

        log("搜索完成，共找到 \(limitedPOIs.count) 个 POI（上限: \(effectiveMaxResults)）")
        return limitedPOIs
    }

    // MARK: - 私有方法

    /// 搜索特定类型的 POI（使用多个关键词搜索，提高覆盖率）
    private func searchPOIs(category: POICategory, around location: CLLocationCoordinate2D) async -> [SearchedPOI] {
        var allPOIs: [SearchedPOI] = []
        var seenCoordinates = Set<String>()
        let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        // 对每个关键词进行搜索
        for keyword in category.searchKeywords {
            let pois = await searchWithKeyword(keyword, category: category, location: location, userLocation: userLocation)

            // 去重（基于坐标）
            for poi in pois {
                let coordKey = "\(String(format: "%.5f", poi.coordinate.latitude))_\(String(format: "%.5f", poi.coordinate.longitude))"
                if !seenCoordinates.contains(coordKey) {
                    seenCoordinates.insert(coordKey)
                    allPOIs.append(poi)
                }
            }
        }

        log("  \(category.displayName) 合并后: \(allPOIs.count) 个")

        // 按距离排序并限制数量
        let sortedPOIs = allPOIs.sorted { $0.distance < $1.distance }
        return Array(sortedPOIs.prefix(maxResultsPerCategory))
    }

    /// 使用单个关键词搜索
    private func searchWithKeyword(_ keyword: String, category: POICategory, location: CLLocationCoordinate2D, userLocation: CLLocation) async -> [SearchedPOI] {
        // 创建搜索请求
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword

        // 设置搜索区域 - 使用更大的区域以获取更多结果
        let region = MKCoordinateRegion(
            center: location,
            latitudinalMeters: searchRadius * 2.5,
            longitudinalMeters: searchRadius * 2.5
        )
        request.region = region

        // 执行搜索
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()

            // 转换结果
            let pois = response.mapItems.compactMap { item -> SearchedPOI? in
                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let distance = userLocation.distance(from: itemLocation)

                // 放宽距离限制，保留搜索半径内的
                guard distance <= searchRadius else { return nil }

                let id = "\(category.rawValue)_\(item.placemark.coordinate.latitude)_\(item.placemark.coordinate.longitude)"
                return SearchedPOI(
                    id: id,
                    name: item.name ?? "未知地点",
                    coordinate: item.placemark.coordinate,
                    category: category,
                    mapItem: item,
                    distance: distance
                )
            }

            return pois
        } catch {
            log("搜索关键词「\(keyword)」失败: \(error.localizedDescription)")
            return []
        }
    }
}
