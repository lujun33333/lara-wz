import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var mgr: laramgr
    @State private var activationCode = ""
    @State private var notice: String?

    init() { globallogger.capture() }

    private let textColor = Color(red: 0.97, green: 0.97, blue: 1)
    private let secondaryColor = Color(red: 0.60, green: 0.62, blue: 0.80)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    Text("AX Pro")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(textColor)
                    Text("VERSION 1.2.8")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(secondaryColor)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.36, blue: 0.89),
                                                      Color(red: 0.66, green: 0.61, blue: 1),
                                                      Color(red: 1, green: 0.44, blue: 0.53)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: 56, height: 3)
                    supportCard
                    SecureField("请输入卡密", text: $activationCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .font(.system(size: 15))
                        .foregroundStyle(textColor)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.purple.opacity(0.22)) }
                    actionButton("卡密激活", symbol: "checkmark.seal.fill") {
                        // No AX service credentials exist in this project. Local kernel
                        // readiness must never be presented as a license activation.
                        notice = "当前工程尚未接入 AX 卡密验证服务，无法在这里验证 AX 卡密。"
                        activationCode = ""
                    }
                    statusCard
                    // AX 1.2.8: STsFYTRP1C: creates an empty UIView with a
                    // 2-point height constraint (call site 0x1000545e8).
                    Color.clear.frame(height: 2)
                    actionButton("启动应用", symbol: "play.fill") {
                        mgr.launchWZGame()
                    }
                    if mgr.dsrunning {
                        VStack(spacing: 6) {
                            Text("\(Int(min(max(mgr.dsprogress, 0), 1) * 100))%")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                            ProgressView(value: min(max(mgr.dsprogress, 0), 1))
                                .tint(Color(red: 0.60, green: 0.46, blue: 1))
                        }
                        .frame(height: 34)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
                .background(Color(red: 0.055, green: 0.058, blue: 0.115).opacity(0.88),
                            in: RoundedRectangle(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color(red: 0.62, green: 0.58, blue: 1).opacity(0.22))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .alert("AX Pro", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("确定", role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.016, green: 0.018, blue: 0.042),
                                    Color(red: 0.058, green: 0.052, blue: 0.125),
                                    Color(red: 0.02, green: 0.02, blue: 0.048)],
                           startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [Color(red: 0.46, green: 0.34, blue: 0.98).opacity(0.20),
                                    Color(red: 0.30, green: 0.24, blue: 0.78).opacity(0.06), .clear],
                           startPoint: UnitPoint(x: 0.15, y: 0), endPoint: UnitPoint(x: 0.85, y: 1))
                .blendMode(.screen)
            LinearGradient(colors: [.clear, Color(red: 0.22, green: 0.30, blue: 0.90).opacity(0.08),
                                    Color(red: 0.40, green: 0.30, blue: 0.95).opacity(0.16)],
                           startPoint: UnitPoint(x: 0.10, y: 0), endPoint: UnitPoint(x: 0.90, y: 1))
                .blendMode(.screen)
        }
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("设备与系统支持")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(secondaryColor)
            Text("\(machineIdentifier()) · iOS \(UIDevice.current.systemVersion)")
                .font(.system(size: 13))
            Text(mgr.dsready && mgr.hasOffsets ? "内核环境已就绪" : "当前环境尚未初始化")
                .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color(red: 0.74, green: 0.76, blue: 0.90))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(red: 0.05, green: 0.07, blue: 0.10), in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color(red: 0.36, green: 0.70, blue: 0.56).opacity(0.36)) }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("当前状态")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(secondaryColor)
            Text(mgr.wzStatus)
                .font(.system(size: 15))
                .foregroundStyle(Color(red: 0.74, green: 0.76, blue: 0.90))
            if mgr.wzGameHUDEnabled {
                Text(mgr.wzGameHUDStatus)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.66, green: 0.95, blue: 0.82))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(red: 0.04, green: 0.042, blue: 0.088), in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color(red: 0.55, green: 0.50, blue: 1).opacity(0.28)) }
    }

    private func actionButton(_ title: String, symbol: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(LinearGradient(
                    colors: [Color(red: 0.42, green: 0.37, blue: 0.98),
                             Color(red: 0.60, green: 0.46, blue: 1)],
                    startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func machineIdentifier() -> String {
        var value = utsname()
        uname(&value)
        return withUnsafePointer(to: &value.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}

#Preview {
    ContentView().environmentObject(laramgr())
}
