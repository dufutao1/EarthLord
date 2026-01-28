//
//  PTTCallView.swift
//  EarthLord
//
//  按住通话（PTT）呼叫页面
//  Day 32-B: 模拟对讲机按住说话功能
//

import SwiftUI

struct PTTCallView: View {

    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var isPressing = false
    @State private var showCannotSendAlert = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 设备状态
            deviceStatusSection

            Spacer()

            // PTT 按钮
            pttButton

            Spacer()

            // 提示文字
            Text(communicationManager.canSendMessage() ? "按住按钮说话，松开发送" : "当前设备不支持发送消息")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("无法发送", isPresented: $showCannotSendAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("收音机只能接收信号，无法发送消息。请切换到对讲机或更高级设备。")
        }
    }

    // MARK: - 设备状态

    private var deviceStatusSection: some View {
        let deviceType = communicationManager.getCurrentDeviceType()

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.primary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: deviceType.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(ApocalypseTheme.primary)
            }

            Text(deviceType.displayName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("通讯范围：\(deviceType.rangeText)")
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - PTT 按钮

    private var pttButton: some View {
        ZStack {
            // 外圈波纹
            if isPressing {
                Circle()
                    .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 3)
                    .frame(width: 160, height: 160)
                    .scaleEffect(isPressing ? 1.2 : 1.0)
                    .opacity(isPressing ? 0 : 1)
                    .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: isPressing)
            }

            // 主按钮
            Circle()
                .fill(isPressing ? ApocalypseTheme.danger : ApocalypseTheme.primary)
                .frame(width: 120, height: 120)
                .shadow(color: (isPressing ? ApocalypseTheme.danger : ApocalypseTheme.primary).opacity(0.4), radius: 10)

            VStack(spacing: 6) {
                Image(systemName: isPressing ? "mic.fill" : "mic")
                    .font(.system(size: 36))
                Text(isPressing ? "正在通话..." : "按住说话")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressing {
                        if communicationManager.canSendMessage() {
                            isPressing = true
                        } else {
                            showCannotSendAlert = true
                        }
                    }
                }
                .onEnded { _ in
                    isPressing = false
                }
        )
    }
}

#Preview {
    PTTCallView()
        .background(ApocalypseTheme.background)
}
