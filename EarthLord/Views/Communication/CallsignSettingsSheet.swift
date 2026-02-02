//
//  CallsignSettingsSheet.swift
//  EarthLord
//
//  呼号设置弹窗
//  Day 36-D: 设置用户电台呼号
//

import SwiftUI
import Supabase

struct CallsignSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var callsign: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    private var isValid: Bool {
        let trimmed = callsign.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 3 && trimmed.count <= 20
    }

    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // 说明
                    infoSection

                    // 输入框
                    inputSection

                    // 错误提示
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    // 保存按钮
                    saveButton

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("呼号设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .onAppear {
            loadCurrentCallsign()
        }
        .alert("保存成功", isPresented: $showingSuccess) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("您的呼号已更新为：\(callsign)")
        }
    }

    // MARK: - 说明区
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("什么是呼号？")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.text)
            }

            Text("呼号是您在电波中的身份标识，其他幸存者会通过呼号识别您。就像真实电台中的 CQ CQ，这里是 BJ-Alpha-001。")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.secondaryText)

            // 格式示例
            VStack(alignment: .leading, spacing: 4) {
                Text("推荐格式：")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.secondaryText)

                HStack(spacing: 12) {
                    ForEach(["BJ-Alpha-001", "SH-Beta-42", "Survivor-X"], id: \.self) { example in
                        Text(example)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ApocalypseTheme.primary.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 输入区
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("您的呼号")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.text)

            TextField("输入呼号（3-20字符）", text: $callsign)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(14)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
                .foregroundColor(ApocalypseTheme.text)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isValid ? ApocalypseTheme.primary : Color.gray, lineWidth: 1)
                )
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)

            Text("仅支持字母、数字和连字符（-）")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.secondaryText)
        }
    }

    // MARK: - 保存按钮
    private var saveButton: some View {
        Button(action: saveCallsign) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("保存呼号")
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(isValid ? ApocalypseTheme.primary : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(!isValid || isLoading)
    }

    // MARK: - 方法
    private func loadCurrentCallsign() {
        // 从 profiles 加载当前呼号
        guard let userId = supabase.auth.currentUser?.id else { return }

        Task {
            do {
                struct ProfileResponse: Decodable {
                    let callsign: String?
                }

                let response: [ProfileResponse] = try await supabase
                    .from("profiles")
                    .select("callsign")
                    .eq("id", value: userId.uuidString)
                    .execute()
                    .value

                if let profile = response.first, let existingCallsign = profile.callsign {
                    await MainActor.run {
                        callsign = existingCallsign
                    }
                }
            } catch {
                print("加载呼号失败: \(error)")
            }
        }
    }

    private func saveCallsign() {
        guard isValid else { return }

        // 验证格式：仅字母、数字、连字符
        let pattern = "^[A-Za-z0-9-]+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(callsign.startIndex..., in: callsign)

        if regex?.firstMatch(in: callsign, range: range) == nil {
            errorMessage = "呼号只能包含字母、数字和连字符"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let userId = supabase.auth.currentUser?.id else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
                }

                // 更新 profiles 表中的呼号
                try await supabase
                    .from("profiles")
                    .update(["callsign": callsign])
                    .eq("id", value: userId.uuidString)
                    .execute()

                await MainActor.run {
                    isLoading = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "保存失败：\(error.localizedDescription)"
                }
            }
        }
    }
}
