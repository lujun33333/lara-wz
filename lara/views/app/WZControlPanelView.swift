import SwiftUI
import Foundation

private enum WZCorePage: Int, CaseIterable, Identifiable {
    case initialize, home, hero, lane, other, tune

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .initialize: return "初始化"
        case .home: return "主页"
        case .hero: return "英雄"
        case .lane: return "兵野"
        case .other: return "其他"
        case .tune: return "调整"
        }
    }
}

struct WZControlPanelView: View {
    @EnvironmentObject private var mgr: laramgr
    @Binding var isPresented: Bool
    @State private var page: WZCorePage = .home

    private let accent = Color(red: 0.16, green: 0.77, blue: 0.65)
    private let panel = Color(red: 0.035, green: 0.043, blue: 0.059)
    private let sidebar = Color(red: 0.051, green: 0.067, blue: 0.09)
    private let card = Color(red: 0.078, green: 0.102, blue: 0.137)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.72).ignoresSafeArea()
                HStack(spacing: 0) {
                    sideBar
                    pageBody
                }
                .frame(width: 900, height: 600)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .scaleEffect(min(1, min((proxy.size.width - 24) / 900,
                                        (proxy.size.height - 20) / 600)))
            }
        }
        .preferredColorScheme(.dark)
    }

    private var sideBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CORE")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(.white)
            Text("SMOBA")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
                .padding(.bottom, 18)

            navButton(.initialize)
            navButton(.home)
            sectionLabel("视觉")
                .padding(.top, 18)
            navButton(.hero)
            navButton(.lane)
            navButton(.other)
            sectionLabel("调整")
                .padding(.top, 18)
            navButton(.tune)
            Spacer()
            Text(mgr.wzAttached ? "ONLINE" : "OFFLINE")
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(mgr.wzAttached ? accent : .orange)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(width: 164, alignment: .leading)
        .background(sidebar)
    }

    private var pageBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(page.title)
                    .font(.system(size: 26, weight: .bold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .frame(height: 70)

            ScrollView(showsIndicators: false) {
                Group {
                    switch page {
                    case .initialize: initializePage
                    case .home: homePage
                    case .hero: heroPage
                    case .lane: lanePage
                    case .other: otherPage
                    case .tune: tunePage
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 736, height: 600, alignment: .top)
    }

    private func navButton(_ target: WZCorePage) -> some View {
        Button {
            page = target
        } label: {
            Text(target.title)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .foregroundStyle(page == target ? accent : Color.secondary)
                .background(page == target ? accent.opacity(0.18) : .clear,
                            in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.secondary.opacity(0.7))
            .padding(.horizontal, 6)
            .frame(height: 26)
    }

    private var initializePage: some View {
        VStack(spacing: 14) {
            statusCard([
                ("环境状态", mgr.wzAttached ? "环境已就绪" : "等待授权后适配"),
                ("目标进程", "smoba"),
                ("游戏模块", "UnityFramework"),
                ("读取传输", mgr.wzAttached ? mgr.wzTransportName : "未连接"),
                ("权限模式", mgr.wzCanWrite ? "读写" : "只读")
            ])
            Button(mgr.wzAttached ? "断开环境" : "初始化环境") {
                mgr.wzAttached ? mgr.wzDetach() : mgr.wzAttach()
            }
            .buttonStyle(CorePrimaryButtonStyle(accent: accent))
            .disabled(mgr.wzRunning)
            if mgr.wzRunning { ProgressView().tint(accent) }
        }
    }

    private var homePage: some View {
        VStack(spacing: 14) {
            statusCard([
                ("状态", mgr.wzAttached ? "获取信息完成" : "未初始化"),
                ("悬浮菜单", mgr.wzGameHUDActive ? "已开启" : "等待全局悬浮注册"),
                ("传输能力", capabilityText),
                ("目标版本", "11.4.10103")
            ])
            coreToggle("游戏内控制面板", isOn: Binding(
                get: { mgr.wzGameHUDEnabled },
                set: { mgr.setGameHUD($0) }
            ), enabled: mgr.wzAttached)
            Text(mgr.wzStatus)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(card, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var heroPage: some View {
        VStack(spacing: 8) {
            featureToggle("显示头像", flag: UInt32(WZESP_SHOW_AVATAR), value: mgr.wzShowAvatar)
            featureToggle("显示血量", flag: UInt32(WZESP_SHOW_HEALTH), value: mgr.wzShowHealth)
            featureToggle("显示回城", flag: UInt32(WZESP_SHOW_RECALL), value: mgr.wzShowRecall)
            featureToggle("显示射线", flag: UInt32(WZESP_SHOW_RAY), value: mgr.wzShowRay)
            featureToggle("显示方框", flag: UInt32(WZESP_SHOW_BOX), value: mgr.wzShowBox)
            featureToggle("自身视野提示", flag: UInt32(WZESP_SHOW_SELF_VISION), value: mgr.wzShowSelfVision)
            featureToggle("对方视野提示", flag: UInt32(WZESP_SHOW_ENEMY_VISION), value: mgr.wzShowEnemyVision)
            featureToggle("小地图", flag: UInt32(WZESP_SHOW_MINIMAP), value: mgr.wzShowMinimap)
            featureToggle("地图调节显示", flag: UInt32(WZESP_SHOW_MAP_ADJUSTMENT),
                          value: mgr.wzShowMapAdjustment)
        }
    }

    private var lanePage: some View {
        VStack(spacing: 10) {
            featureToggle("显示野怪", flag: UInt32(WZESP_SHOW_MONSTER), value: mgr.wzShowMonster)
            featureToggle("显示野怪实体", flag: UInt32(WZESP_SHOW_MONSTER_ENTITY), value: mgr.wzShowMonsterEntity)
            featureToggle("显示野怪计时", flag: UInt32(WZESP_SHOW_MONSTER_TIMER), value: mgr.wzShowMonsterTimer)
            featureToggle("显示兵线", flag: UInt32(WZESP_SHOW_SOLDIER), value: mgr.wzShowSoldier)
            featureToggle("显示兵线实体", flag: UInt32(WZESP_SHOW_SOLDIER_ENTITY), value: mgr.wzShowSoldierEntity)
        }
    }

    private var otherPage: some View {
        VStack(spacing: 12) {
            statusCard([
                ("版本", "Core 2.2 / lara-wz"),
                ("机型", UIDevice.current.model),
                ("系统", UIDevice.current.systemVersion),
                ("写入能力", mgr.wzCanWrite ? "可用" : "只读后端已锁定")
            ])
            Text("当前工程只保留王者绘制链。未完成版本验证的写入和 Hook 能力不会出现在功能入口中。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tunePage: some View {
        VStack(spacing: 12) {
            coreSlider("射线宽度", value: $mgr.wzRayWidth, range: 0.5...6, format: "%.1f")
            coreSlider("方框宽度", value: $mgr.wzBoxWidth, range: 0.5...6, format: "%.1f")
            coreSlider("头像大小", value: $mgr.wzAvatarScale, range: 0.5...2, format: "%.2fx")
            coreSlider("野怪计时文本", value: $mgr.wzMonsterTextSize, range: 9...28, format: "%.0f")
            coreSlider("地图大小", value: $mgr.wzMinimapSize, range: 60...420, format: "%.0f")
            coreSlider("地图坐标X", value: $mgr.wzMinimapX, range: -300...300, format: "%.0f")
            coreSlider("地图坐标Y", value: $mgr.wzMinimapY, range: -200...200, format: "%.0f")
            HStack(spacing: 12) {
                colorRow("暴露线条颜色", rgba: mgr.wzExposedLineRGBA, slot: 1)
                colorRow("暴露血条颜色", rgba: mgr.wzExposedHealthRGBA, slot: 2)
            }
            HStack(spacing: 12) {
                colorRow("默认线条颜色", rgba: mgr.wzDefaultLineRGBA, slot: 3)
                colorRow("默认血条颜色", rgba: mgr.wzDefaultHealthRGBA, slot: 4)
            }
        }
    }

    private var capabilityText: String {
        guard mgr.wzAttached else { return "未连接" }
        return "\(mgr.wzTransportName) · \(mgr.wzCanWrite ? "读写" : "只读")"
    }

    private func statusCard(_ rows: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text(row.0).foregroundStyle(Color.white.opacity(0.84))
                    Spacer()
                    Text(row.1)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(row.1.contains("只读") ? .orange : accent)
                }
                .font(.system(size: 14, weight: .medium))
                .frame(height: 44)
                if index != rows.count - 1 { Divider().opacity(0.35) }
            }
        }
        .padding(.horizontal, 18)
        .background(card, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08)) }
    }

    private func featureToggle(_ title: String, flag: UInt32, value: Bool,
                               enabled: Bool? = nil) -> some View {
        coreToggle(title, isOn: Binding(
            get: { value },
            set: { mgr.setWZFeature(flag, enabled: $0) }
        ), enabled: enabled ?? mgr.wzAttached)
    }

    private func coreToggle(_ title: String, isOn: Binding<Bool>, enabled: Bool) -> some View {
        Toggle(title, isOn: isOn)
            .font(.system(size: 14, weight: .medium))
            .tint(accent)
            .disabled(!enabled)
            .padding(.horizontal, 18)
            .frame(height: 46)
            .background(card.opacity(enabled ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07)) }
    }

    private func coreSlider(_ title: String, value: Binding<Double>,
                            range: ClosedRange<Double>, format: String) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
            }
            Slider(value: value, in: range)
                .tint(accent)
                .onChange(of: value.wrappedValue) { _ in mgr.syncWZPresentation() }
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(card, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07)) }
    }

    private func colorRow(_ title: String, rgba: UInt32, slot: Int) -> some View {
        Button { mgr.cycleWZColor(slot) } label: {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                RoundedRectangle(cornerRadius: 6)
                    .fill(swiftUIColor(rgba))
                    .frame(width: 26, height: 26)
                    .overlay { RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.8)) }
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(card, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func swiftUIColor(_ rgba: UInt32) -> Color {
        Color(red: Double((rgba >> 24) & 0xFF) / 255,
              green: Double((rgba >> 16) & 0xFF) / 255,
              blue: Double((rgba >> 8) & 0xFF) / 255,
              opacity: Double(rgba & 0xFF) / 255)
    }
}

private struct CorePrimaryButtonStyle: ButtonStyle {
    let accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.black.opacity(0.82))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(accent.opacity(configuration.isPressed ? 0.72 : 1),
                        in: RoundedRectangle(cornerRadius: 12))
    }
}
