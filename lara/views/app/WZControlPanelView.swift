import SwiftUI
import UIKit

private enum WZCorePage: Int, CaseIterable, Identifiable {
    case home, hero, lane, skill, tune

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .home: return "主页"
        case .hero: return "英雄"
        case .lane: return "兵野"
        case .skill: return "技能"
        case .tune: return "调整"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .hero: return "person.2.fill"
        case .lane: return "pawprint.fill"
        case .skill: return "bolt.fill"
        case .tune: return "gearshape.fill"
        }
    }
}

struct WZControlPanelView: View {
    @EnvironmentObject private var mgr: laramgr
    @Binding var isPresented: Bool
    @State private var page: WZCorePage = .home
    let allowsDismiss: Bool

    private let rose = Color(red: 0.69, green: 0.48, blue: 0.53)
    private let ink = Color(red: 0.28, green: 0.27, blue: 0.27)
    private let muted = Color(red: 0.55, green: 0.54, blue: 0.54)
    private let panel = Color.white.opacity(0.96)
    private let sidebar = Color(red: 0.97, green: 0.97, blue: 0.965).opacity(0.96)
    private let card = Color(red: 0.94, green: 0.94, blue: 0.935)

    init(isPresented: Binding<Bool>, allowsDismiss: Bool = true) {
        _isPresented = isPresented
        self.allowsDismiss = allowsDismiss
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear
                HStack(spacing: 0) {
                    sideBar
                    pageBody
                }
                .frame(width: 900, height: 600)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.08)) }
                .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
                .scaleEffect(min(1, min((proxy.size.width - 18) / 900,
                                        (proxy.size.height - 14) / 600)))
            }
        }
        .preferredColorScheme(.light)
    }

    private var sideBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("CORE")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(ink)
                Circle().fill(rose).frame(width: 6, height: 6)
            }
            Text("—  S M O B A  —")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(muted)
                .padding(.top, 3)
                .padding(.bottom, 22)

            sectionTitle("初始化")
            navButton(.home)
            sectionTitle("视觉").padding(.top, 16)
            navButton(.hero)
            navButton(.lane)
            navButton(.skill)
            sectionTitle("其他").padding(.top, 16)
            navButton(.tune)
            Spacer()

            HStack(spacing: 6) {
                Circle().fill(mgr.wzAttached ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(mgr.wzAttached ? "已连接" : "未连接")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(muted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(width: 164, alignment: .leading)
        .background(sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.black.opacity(0.07)).frame(width: 1) }
    }

    private var pageBody: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                Group {
                    switch page {
                    case .home: homePage
                    case .hero: heroPage
                    case .lane: lanePage
                    case .skill: skillPage
                    case .tune: tunePage
                    }
                }
                .padding(18)
            }
            if allowsDismiss {
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(muted)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.035), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(12)
            }
        }
        .frame(width: 736, height: 600, alignment: .top)
        .foregroundStyle(ink)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(muted)
            .frame(height: 28)
    }

    private func navButton(_ target: WZCorePage) -> some View {
        Button {
            page = target
        } label: {
            HStack(spacing: 10) {
                Image(systemName: target.icon).frame(width: 18)
                Text(target.title)
                Spacer()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(page == target ? ink : muted)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(page == target ? Color.black.opacity(0.045) : .clear,
                        in: RoundedRectangle(cornerRadius: 5))
            .overlay(alignment: .leading) {
                if page == target { Rectangle().fill(rose).frame(width: 3, height: 30) }
            }
        }
        .buttonStyle(.plain)
    }

    private var homePage: some View {
        HStack(alignment: .top, spacing: 16) {
            lightCard("内核管理") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("DarkSword")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 25)
                            .background(rose, in: Capsule())
                        Text("V2.2 王者")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(muted)
                    }
                    infoLine("机型", machineIdentifier())
                    infoLine("系统", "iOS \(UIDevice.current.systemVersion)")
                    infoLine("内核状态", mgr.dsready ? "已就绪" : "未初始化")
                    infoLine("读取传输", mgr.wzAttached ? mgr.wzTransportName : "未连接")
                    infoLine("权限", mgr.wzCanWrite ? "读写" : "只读")
                    Button(mgr.wzAttached ? "断开连接" : "获取信息") {
                        mgr.wzAttached ? mgr.wzDetach() : mgr.prepareWZEnvironment()
                    }
                    .buttonStyle(LightCoreButtonStyle(tint: rose))
                    .disabled(mgr.dsrunning || mgr.wzRunning)
                }
            }
            lightCard("界面设置") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("UI 主题").font(.system(size: 12, weight: .semibold))
                    HStack {
                        Text("纯白 (Light)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 26)
                            .background(rose, in: Capsule())
                        Spacer()
                    }
                    Text("主题颜色").font(.system(size: 12, weight: .semibold))
                    HStack(spacing: 7) {
                        ForEach([0xB47B88FF, 0xD44B55FF, 0x347AC5FF, 0x369C91FF,
                                 0x9064C6FF, 0xD74B96FF, 0x2A9CB7FF], id: \.self) { color in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(swiftUIColor(UInt32(color)))
                                .frame(width: 23, height: 23)
                        }
                    }
                    Divider()
                    Text("性能监测").font(.system(size: 12, weight: .semibold))
                    infoLine("采集帧", mgr.wzAttached ? "60 FPS" : "--")
                    infoLine("后端", mgr.wzTransportName)
                    infoLine("悬浮窗", mgr.wzGameHUDActive ? "运行中" : "未启动")
                    infoLine("安全边界", mgr.wzCanWrite ? "读写" : "只读锁定")
                }
            }
        }
    }

    private var heroPage: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                lightCard("显示设置") {
                    VStack(spacing: 0) {
                        featureRow("显示头像", UInt32(WZESP_SHOW_AVATAR), mgr.wzShowAvatar)
                        featureRow("显示血量", UInt32(WZESP_SHOW_HEALTH), mgr.wzShowHealth)
                        featureRow("显示回城", UInt32(WZESP_SHOW_RECALL), mgr.wzShowRecall)
                        featureRow("显示射线", UInt32(WZESP_SHOW_RAY), mgr.wzShowRay)
                        featureRow("显示方框", UInt32(WZESP_SHOW_BOX), mgr.wzShowBox)
                    }
                }
                lightCard("视野") {
                    VStack(spacing: 0) {
                        featureRow("自身视野提示", UInt32(WZESP_SHOW_SELF_VISION), mgr.wzShowSelfVision)
                        featureRow("对方视野提示", UInt32(WZESP_SHOW_ENEMY_VISION), mgr.wzShowEnemyVision)
                    }
                }
            }
            lightCard("小地图") {
                VStack(spacing: 12) {
                    featureRow("显示小地图", UInt32(WZESP_SHOW_MINIMAP), mgr.wzShowMinimap)
                    featureRow("地图调节显示", UInt32(WZESP_SHOW_MAP_ADJUSTMENT), mgr.wzShowMapAdjustment)
                    lightSlider("地图大小", value: $mgr.wzMinimapSize, range: 60...520)
                    lightSlider("地图坐标X", value: $mgr.wzMinimapX, range: -300...300)
                    lightSlider("地图坐标Y", value: $mgr.wzMinimapY, range: -200...200)
                }
            }
        }
    }

    private var lanePage: some View {
        HStack(alignment: .top, spacing: 16) {
            lightCard("野怪") {
                VStack(spacing: 0) {
                    featureRow("显示野怪", UInt32(WZESP_SHOW_MONSTER), mgr.wzShowMonster)
                    featureRow("显示野怪实体", UInt32(WZESP_SHOW_MONSTER_ENTITY), mgr.wzShowMonsterEntity)
                    featureRow("显示野怪计时", UInt32(WZESP_SHOW_MONSTER_TIMER), mgr.wzShowMonsterTimer)
                }
            }
            lightCard("兵线") {
                VStack(spacing: 0) {
                    featureRow("显示兵线", UInt32(WZESP_SHOW_SOLDIER), mgr.wzShowSoldier)
                    featureRow("显示兵线实体", UInt32(WZESP_SHOW_SOLDIER_ENTITY), mgr.wzShowSoldierEntity)
                }
            }
        }
    }

    private var skillPage: some View {
        lightCard("召唤师技能") {
            VStack(alignment: .leading, spacing: 12) {
                featureRow("显示英雄技能冷却", UInt32(WZESP_SHOW_SKILL), mgr.wzShowSkill)
                Text("读取英雄技能配置与冷却时间，并在游戏画面对应英雄旁显示。")
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
            }
        }
    }

    private var tunePage: some View {
        VStack(spacing: 14) {
            lightCard("绘制参数") {
                VStack(spacing: 12) {
                    lightSlider("射线宽度", value: $mgr.wzRayWidth, range: 0.5...6)
                    lightSlider("方框宽度", value: $mgr.wzBoxWidth, range: 0.5...6)
                    lightSlider("头像大小", value: $mgr.wzAvatarScale, range: 0.5...2)
                    lightSlider("野怪计时文本", value: $mgr.wzMonsterTextSize, range: 9...28)
                }
            }
        }
    }

    private func lightCard<Content: View>(_ title: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(muted)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(card, in: RoundedRectangle(cornerRadius: 7))
        .overlay { RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.07)) }
    }

    private func featureRow(_ title: String, _ flag: UInt32, _ value: Bool) -> some View {
        Button { mgr.setWZFeature(flag, enabled: !value) } label: {
            HStack {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .stroke(value ? rose : Color.black.opacity(0.12), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .overlay {
                        if value { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(rose) }
                    }
            }
            .frame(height: 34)
            .foregroundStyle(ink.opacity(mgr.wzAttached ? 1 : 0.45))
        }
        .buttonStyle(.plain)
        .disabled(!mgr.wzAttached)
    }

    private func infoLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(muted)
            Spacer()
            Text(value).foregroundStyle(ink).lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
    }

    private func lightSlider(_ title: String, value: Binding<Double>,
                             range: ClosedRange<Double>) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(String(format: "%.0f", value.wrappedValue))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            Slider(value: value, in: range)
                .tint(rose)
                .onChange(of: value.wrappedValue) { _ in mgr.syncWZPresentation() }
        }
    }

    private func swiftUIColor(_ rgba: UInt32) -> Color {
        Color(red: Double((rgba >> 24) & 0xFF) / 255,
              green: Double((rgba >> 16) & 0xFF) / 255,
              blue: Double((rgba >> 8) & 0xFF) / 255,
              opacity: Double(rgba & 0xFF) / 255)
    }

    private func machineIdentifier() -> String {
        var value = utsname()
        uname(&value)
        return withUnsafePointer(to: &value.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }
}

private struct LightCoreButtonStyle: ButtonStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(tint.opacity(configuration.isPressed ? 0.68 : 1),
                        in: RoundedRectangle(cornerRadius: 5))
    }
}
