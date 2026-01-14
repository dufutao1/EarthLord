//
//  POIProximityPopup.swift
//  EarthLord
//
//  POI 接近弹窗
//  当玩家进入 POI 50 米范围内时显示
//

import SwiftUI
import MapKit
import CoreLocation

/// POI 接近弹窗视图
struct POIProximityPopup: View {

    /// 当前接近的 POI
    let poi: SearchedPOI

    /// 搜刮回调
    let onScavenge: () -> Void

    /// 稍后回调
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 半透明背景
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // 点击背景关闭
                    onDismiss()
                }

            // 弹窗内容
            popupContent
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - 弹窗内容

    private var popupContent: some View {
        VStack(spacing: 16) {
            // 拖动指示条
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            // 图标和标题
            HStack(spacing: 12) {
                // POI 类型图标
                ZStack {
                    Circle()
                        .fill(poiColor.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: poi.category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(poiColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("发现废墟")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text(poi.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    // 类型和距离
                    HStack(spacing: 8) {
                        Text(poi.category.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(poiColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(poiColor.opacity(0.15))
                            .cornerRadius(4)

                        if poi.distance > 0 {
                            Text("距离 \(Int(poi.distance)) 米")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            // 提示文字
            Text("你已进入该地点的搜刮范围，是否立即搜刮物资？")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // 按钮区域
            HStack(spacing: 12) {
                // 稍后再说按钮
                Button(action: onDismiss) {
                    Text("稍后再说")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                        )
                }

                // 立即搜刮按钮
                Button(action: onScavenge) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                        Text("立即搜刮")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(
            ApocalypseTheme.background
                .cornerRadius(24, corners: [.topLeft, .topRight])
        )
    }

    // MARK: - 计算属性

    /// POI 类型对应的颜色
    private var poiColor: Color {
        switch poi.category {
        case .store: return .green
        case .hospital: return .red
        case .pharmacy: return .purple
        case .gasStation: return .orange
        case .restaurant: return .yellow
        case .cafe: return .brown
        }
    }
}

// MARK: - 圆角扩展

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        POIProximityPopup(
            poi: SearchedPOI(
                id: "test",
                name: "沃尔玛超市",
                coordinate: .init(latitude: 22.5, longitude: 114.1),
                category: .store,
                mapItem: .init()
            ),
            onScavenge: { print("搜刮") },
            onDismiss: { print("关闭") }
        )
    }
}
