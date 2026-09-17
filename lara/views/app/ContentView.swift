import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var mgr: laramgr
    @State private var menuExpanded = true
    @State private var notice: String?

    init() {
        globallogger.capture()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                launcherBackground
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroCard
                            .frame(height: min(270,
                                max(168, (proxy.size.width - 32) / 2.15)))
                        authorizationBar
                            .padding(.top, 10)
                        radialMenu
                            .padding(.top, 20)
                        equalizer
                            .padding(.top, 14)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 18))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, max(proxy.safeAreaInsets.top + 16, 24))
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Core", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("确定", role: .cancel) { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }

    private var launcherBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.055, green: 0.075, blue: 0.16),
                         Color(red: 0.015, green: 0.027, blue: 0.075),
                         Color(red: 0.015, green: 0.020, blue: 0.052)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            RadialGradient(colors: [Color.purple.opacity(0.20), .clear],
                           center: .center, startRadius: 10, endRadius: 250)
                .offset(y: 110)
            ForEach(0..<18, id: \.self) { index in
                Circle()
                    .fill(particleColor(index).opacity(0.42))
                    .frame(width: CGFloat(3 + index % 4), height: CGFloat(3 + index % 4))
                    .position(x: CGFloat(24 + (index * 73) % 340),
                              y: CGFloat(120 + (index * 109) % 760))
                    .blur(radius: index.isMultiple(of: 3) ? 1.5 : 0)
            }
        }
    }

    private var heroCard: some View {
        ZStack {
            Image("core-mountain")
                .resizable()
                .scaledToFill()
            LinearGradient(colors: [Color.blue.opacity(0.06), Color.blue.opacity(0.20)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("Core")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.14))
                        .shadow(color: .black.opacity(0.28), radius: 4, y: 3)
                    Text("匠\n心\n品\n质")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.22))
                        .padding(.top, 5)
                }
                Text("免越狱　免巨魔　自签版")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.pink, .orange, .yellow],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: .white.opacity(0.5), radius: 2)
                Text("W Z  ·  2 . 2")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.28))
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.20)) }
    }

    private var authorizationBar: some View {
        HStack(spacing: 8) {
            Text("\(machineIdentifier()) · iOS \(UIDevice.current.systemVersion)")
                .lineLimit(1)
            Spacer()
            Circle()
                .fill(LinearGradient(colors: [.pink, .purple, .cyan],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 10, height: 10)
            Spacer()
            Text(mgr.dsready && mgr.hasOffsets ? "环境已授权" : "等待本地授权")
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium, design: .serif))
        .foregroundStyle(Color(red: 0.76, green: 0.47, blue: 0.91))
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color.black.opacity(0.18), in: Capsule())
        .overlay {
            Capsule().stroke(
                LinearGradient(colors: [.pink, .purple, .blue, .cyan],
                               startPoint: .leading, endPoint: .trailing),
                lineWidth: 2
            )
        }
    }

    private var radialMenu: some View {
        ZStack {
            if menuExpanded {
                launcherButton("查看公告", colors: [.purple, .pink]) {
                    notice = "当前本地版没有接入 Core 原版公告服务器。"
                }
                .offset(x: -118, y: -118)
                launcherButton("启动游戏", colors: [.pink, .red]) {
                    mgr.launchWZGame()
                }
                .offset(x: 118, y: -118)
                launcherButton("提交工单", colors: [.blue, .cyan]) {
                    notice = "当前本地版没有接入远程工单服务。"
                }
                .offset(x: -120, y: 0)
                launcherButton("检查更新", colors: [.blue, .cyan]) {
                    notice = "当前版本：\(Bundle.main.infoDictionary?["LARABuildSourceCommit"] as? String ?? "本地构建")"
                }
                .offset(x: 120, y: 0)
                launcherButton("工单进度", colors: [.orange, .red]) {
                    notice = "当前本地版没有远程工单记录。"
                }
                .offset(x: -118, y: 118)
                launcherButton("激活续时", colors: [.yellow, .orange]) {
                    notice = "本地版不使用远程到期授权。"
                }
                .offset(x: 118, y: 118)
            }

            Button {
                mgr.openWZControlPanel()
            } label: {
                Group {
                    if mgr.dsrunning || mgr.wzRunning {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: mgr.dsready && mgr.hasOffsets ? "rectangle.on.rectangle" : "bolt.fill")
                            .font(.system(size: 26, weight: .bold))
                    }
                }
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(colors: [.purple, .blue],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .overlay { Circle().stroke(Color.white.opacity(0.45), lineWidth: 1.5) }
                .shadow(color: .purple.opacity(0.7), radius: 16)
            }
            .buttonStyle(.plain)
            .offset(y: -160)

            Button {
                withAnimation(.easeInOut(duration: 0.22)) { menuExpanded.toggle() }
            } label: {
                ZStack {
                    Circle().fill(Color(red: 1.0, green: 0.16, blue: 0.34).opacity(0.88))
                    Circle().stroke(Color.pink.opacity(0.75), lineWidth: 3).padding(-14)
                    Circle().stroke(Color.pink.opacity(0.34), lineWidth: 2).padding(-28)
                    Text(menuExpanded ? "关闭菜单" : "打开菜单")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.55), radius: 7)
                }
                .frame(width: 134, height: 134)
                .shadow(color: .pink.opacity(0.55), radius: 22)
            }
            .buttonStyle(.plain)

            Button {
                notice = "点击上方状态按钮完成初始化并打开控制台，再点击“启动游戏”。进入游戏后使用三指轻触呼出同一组功能。"
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.pink, .purple, .cyan],
                                                        startPoint: .leading, endPoint: .trailing))
                    Text("教程")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .offset(y: 165)
        }
        .frame(height: 390)
    }

    private func launcherButton(_ title: String, colors: [Color],
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .frame(height: 40)
                .background(LinearGradient(colors: colors,
                                           startPoint: .leading, endPoint: .trailing),
                            in: Capsule())
                .overlay { Capsule().stroke(Color.white.opacity(0.18)) }
                .shadow(color: (colors.last ?? .purple).opacity(0.55), radius: 12)
        }
        .buttonStyle(.plain)
    }

    private var equalizer: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<38, id: \.self) { index in
                equalizerBar(index)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .bottom)
        .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 34))
        .overlay { RoundedRectangle(cornerRadius: 34).stroke(Color.purple.opacity(0.32)) }
    }

    private func equalizerBar(_ index: Int) -> some View {
        let rawHeight = 20 + ((index * 17 + index * index * 3) % 58)
        return RoundedRectangle(cornerRadius: 3)
            .fill(LinearGradient(colors: [Color.pink, Color.purple, Color.cyan],
                                 startPoint: .bottom, endPoint: .top))
            .frame(height: CGFloat(rawHeight))
    }

    private func particleColor(_ index: Int) -> Color {
        [.pink, .purple, .blue, .cyan][index % 4]
    }

    private func machineIdentifier() -> String {
        var value = utsname()
        uname(&value)
        return withUnsafePointer(to: &value.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(laramgr())
}
