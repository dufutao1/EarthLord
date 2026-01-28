//
//  DeviceManagementView.swift
//  EarthLord
//
//  设备管理页面
//  Day 32-B: 显示4种通讯设备，支持切换和解锁提示
//

import SwiftUI
import Supabase

struct DeviceManagementView: View {

    @StateObject private var communicationManager = CommunicationManager.shared

    /// 未解锁设备提示
    @State private var showLockedAlert = false
    @State private var lockedDeviceType: DeviceType?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 标题说明
                headerSection

                // 设备列表
                ForEach(DeviceType.allCases, id: \.self) { deviceType in
                    deviceCard(for: deviceType)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            if let userId = supabase.auth.currentUser?.id {
                await communicationManager.loadDevices(userId: userId)
            }
        }
        .alert("设备未解锁", isPresented: $showLockedAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            if let deviceType = lockedDeviceType {
                Text(deviceType.unlockRequirement)
            }
        }
    }

    // MARK: - 标题说明

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("通讯设备")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("不同设备有不同的通讯范围，选择合适的设备进行通讯")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    // MARK: - 设备卡片

    private func deviceCard(for deviceType: DeviceType) -> some View {
        let device = communicationManager.devices.first(where: { $0.deviceType == deviceType })
        let isUnlocked = device?.isUnlocked ?? false
        let isCurrent = device?.isCurrent ?? false

        return Button(action: {
            handleDeviceTap(deviceType: deviceType, isUnlocked: isUnlocked, isCurrent: isCurrent)
        }) {
            HStack(spacing: 14) {
                // 设备图标
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(deviceIconColor(deviceType, isUnlocked: isUnlocked).opacity(0.15))
                        .frame(width: 52, height: 52)

                    if isUnlocked {
                        Image(systemName: deviceType.iconName)
                            .font(.system(size: 22))
                            .foregroundColor(deviceIconColor(deviceType, isUnlocked: true))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }

                // 设备信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(deviceType.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isUnlocked ? ApocalypseTheme.textPrimary : ApocalypseTheme.textMuted)

                        if isCurrent {
                            Text("当前")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ApocalypseTheme.success)
                                .cornerRadius(4)
                        }
                    }

                    Text(deviceType.description)
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 10))
                        Text("范围：\(deviceType.rangeText)")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(ApocalypseTheme.textMuted)
                }

                Spacer()

                // 右侧指示
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(ApocalypseTheme.success)
                } else if isUnlocked {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .padding(14)
            .background(
                isCurrent
                    ? ApocalypseTheme.primary.opacity(0.08)
                    : ApocalypseTheme.cardBackground
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isCurrent ? ApocalypseTheme.primary.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 辅助方法

    private func deviceIconColor(_ deviceType: DeviceType, isUnlocked: Bool) -> Color {
        guard isUnlocked else { return ApocalypseTheme.textMuted }
        switch deviceType {
        case .radio: return .green
        case .walkieTalkie: return ApocalypseTheme.primary
        case .campRadio: return .purple
        case .satellite: return .cyan
        }
    }

    private func handleDeviceTap(deviceType: DeviceType, isUnlocked: Bool, isCurrent: Bool) {
        if isCurrent { return }

        if !isUnlocked {
            lockedDeviceType = deviceType
            showLockedAlert = true
            return
        }

        if let userId = supabase.auth.currentUser?.id {
            Task {
                await communicationManager.switchDevice(userId: userId, to: deviceType)
            }
        }
    }
}

#Preview {
    DeviceManagementView()
        .background(ApocalypseTheme.background)
}
