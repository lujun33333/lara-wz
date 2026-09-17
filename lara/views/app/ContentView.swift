//
//  ContentView.swift
//  lara
//
//  Created by ruter on 23.03.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var mgr: laramgr
    @ObservedObject private var logger = globallogger
    @AppStorage("selectedMethod") private var selectedmethod: method = .hybrid
    @AppStorage("logsdisplaymode") private var selectedlogsdisplaymode: logsdisplaymode = .toolbar
    @AppStorage("loggerNoBS") private var loggernobs: Bool = true
    @AppStorage("stashKRW") private var stashKRW: Bool = false
    
    @State private var showSettings: Bool = false
    @State private var showAdvanced: Bool = false
    @State private var dlingkcache: Bool = false
    @State private var showWZControlPanel: Bool = false
    
    init() {
        globallogger.capture()
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Text("CORE")
                        .font(.system(size: 27, weight: .bold))
                        .padding(.top, 34)
                    Text("SMOBA")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.top, 5)

                    VStack(spacing: 0) {
                        coreStatusRow(symbol: "cpu", title: "内核环境", value: kernelStatus)
                        Divider().padding(.leading, 50)
                        coreStatusRow(symbol: "memorychip", title: "读取传输", value: transportStatus)
                        Divider().padding(.leading, 50)
                        coreStatusRow(symbol: "scope", title: "目标进程", value: mgr.wzAttached ? "smoba" : "等待连接")
                        Divider().padding(.leading, 50)
                        coreStatusRow(symbol: "shippingbox", title: "游戏模块", value: mgr.wzAttached ? "UnityFramework" : "未定位")
                        Divider().padding(.leading, 50)
                        coreStatusRow(symbol: "lock.shield", title: "权限模式", value: mgr.wzCanWrite ? "读写" : "只读")
                    }
                    .padding(.horizontal, 14)
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.top, 34)

                    Button(primaryActionTitle) { performPrimaryAction() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(red: 0.16, green: 0.77, blue: 0.65),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        .padding(.top, 26)
                        .disabled(mgr.dsrunning || mgr.wzRunning)

                    Button("高级设置") { showAdvanced = true }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    Text("完成环境初始化后连接王者荣耀。只读 Mach task 后端可使用绘制功能；任何需要写入的功能会按 capability 自动锁定。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)
                        .padding(.top, 22)
                        .padding(.bottom, 28)
                }
            }
        }
        .sheet(isPresented: $showAdvanced) { advancedView }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(isPresented: $showWZControlPanel) {
            WZControlPanelView(isPresented: $showWZControlPanel)
                .environmentObject(mgr)
        }
        .onChange(of: mgr.wzAttached) { attached in
            if attached { showWZControlPanel = true }
        }
    }

    private var advancedView: some View {
        NavigationStack {
            List {
                AlertsSection
                KRWSection
                WZSection
                DebugSection
                InlineLogsSection
            }
            .navigationTitle("Core 高级设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { showAdvanced = false }
                }
                if selectedlogsdisplaymode == .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { mgr.showLogs.toggle() } label: {
                            Image(systemName: "terminal")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showWZControlPanel = true } label: {
                        Image(systemName: "switch.2")
                    }
                }
            }
        }
    }

    private var kernelStatus: String {
        if mgr.dsready { return "环境已就绪" }
        if mgr.dsrunning { return "初始化中" }
        if mgr.dsfailed { return "初始化失败" }
        return "未初始化"
    }

    private var transportStatus: String {
        guard mgr.wzAttached else { return "未连接" }
        return "\(mgr.wzTransportName) · \(mgr.wzCanWrite ? "读写" : "只读")"
    }

    private var primaryActionTitle: String {
        if mgr.dsrunning || mgr.wzRunning { return "处理中…" }
        if !mgr.dsready { return "初始化环境" }
        if !mgr.wzAttached { return "连接王者荣耀" }
        return "打开 Core 控制面板"
    }

    private func performPrimaryAction() {
        if !mgr.dsready {
            offsets_init()
            mgr.run()
        } else if !mgr.wzAttached {
            mgr.wzAttach()
        } else {
            showWZControlPanel = true
        }
    }

    private func coreStatusRow(symbol: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.16, green: 0.77, blue: 0.65))
                .frame(width: 24)
            Text(title).font(.system(size: 14, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(value.contains("失败") ? .red : .secondary)
        }
        .frame(height: 44)
    }
    
    private var AlertsSection: some View {
        Section {
            if !mgr.hasOffsets {
                PlainAlert(title: "未找到偏移量！", icon: "exclamationmark.triangle.fill", text: "缺少内核缓存偏移量。点击「运行内核漏洞」后再获取偏移量。")
            }
        }
    }
    
    private var KRWSection: some View {
        Section {
            LabeledContent(content: {
                if mgr.dsready {
                    Image(systemName: "checkmark.circle")
                } else if mgr.dsrunning {
                    HStack {
                        Text("\(Int(mgr.dsprogress * 100))%")
                        ProgressView()
                    }
                } else if mgr.dsattempted && mgr.dsfailed {
                    Image(systemName: "xmark.circle")
                }
            }) {
                Button("运行内核漏洞", action: {
                    offsets_init()
                    mgr.run()
                })
                .disabled(mgr.dsready || mgr.dsrunning || isdebugged())
            }
            
            Toggle("存储 KRW 原语", isOn: $stashKRW)
                .onChange(of: stashKRW) { enabled in
                    if enabled && isIOS16() {
                        Alertinator.shared.alert(
                            title: "iOS 16 警告",
                            body: "在 iOS 16 上保存 KRW 目前不稳定。如果失败，请再手动存储几次 KRW。"
                        )
                    }
                }
            
            if !mgr.hasOffsets {
                Button {
                    guard !dlingkcache else { return }
                    dlingkcache = true

                    DispatchQueue.global(qos: .userInitiated).async {
                        let fetched = fetchkcache()

                        if fetched {
                            let dlkc = dlkcache()
                            DispatchQueue.main.async {
                                mgr.hasOffsets = dlkc
                                dlingkcache = false
                            }
                            return
                        }

                        DispatchQueue.main.async {
                            mgr.hasOffsets = false
                            dlingkcache = false
                        }
                    }
                } label: {
                    if dlingkcache {
                        HStack {
                            Text("正在获取内核缓存...")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Text("获取内核缓存")
                    }
                }
                .disabled(dlingkcache || !mgr.dsready)
            } else {
                if selectedmethod == .hybrid {
                    LabeledContent(content: {
                        if mgr.vfsready && mgr.sbxready {
                            Image(systemName: "checkmark.circle")
                        } else if mgr.vfsrunning || mgr.sbxrunning {
                            HStack {
                                Text("运行中...")
                                ProgressView()
                            }
                        } else if (mgr.vfsattempted && mgr.vfsfailed) || (mgr.sbxattempted && mgr.sbxfailed) {
                            Image(systemName: "xmark.circle")
                        }
                    }) {
                        Button("初始化系统", action: {
                            mgr.vfsinit()
                            mgr.sbxescape()
                        })
                        .disabled(!mgr.hasOffsets || !mgr.dsready || mgr.vfsrunning || mgr.sbxrunning || (mgr.vfsready && mgr.sbxready))
                    }
                }

                // initalize vfs
                if selectedmethod == .vfs {
                    LabeledContent(content: {
                        if mgr.vfsready {
                            Image(systemName: "checkmark.circle")
                        } else if mgr.vfsrunning {
                            HStack {
                                Text("\(Int(mgr.dsprogress * 100))%")
                                ProgressView()
                            }
                        } else if mgr.vfsattempted && mgr.vfsfailed {
                            Image(systemName: "xmark.circle")
                        }
                    }) {
                        Button("初始化 VFS", action: {
                            mgr.vfsinit()
                        })
                        .disabled(!mgr.dsready || mgr.vfsready || mgr.vfsrunning || isdebugged())
                    }
                }
                
                // escape sandbox
                if selectedmethod == .sbx {
                    LabeledContent(content: {
                        if mgr.sbxready {
                            Image(systemName: "checkmark.circle")
                        } else if mgr.sbxrunning {
                            HStack {
                                Text("运行中...")
                                ProgressView()
                            }
                        } else if mgr.sbxattempted && mgr.sbxfailed {
                            Image(systemName: "xmark.circle")
                        }
                    }) {
                        Button("逃逸沙箱", action: {
                            mgr.sbxescape()
                        })
                        .disabled(!mgr.dsready || mgr.sbxready || mgr.sbxrunning || isdebugged())
                    }
                }
            }
        } header: {
            HeaderLabel(text: "内核读写", icon: "externaldrive")
        } footer: {
            if isdebugged() {
                Text("调试器附加时不可用。")
            }
        }
    }
    
    private var WZSection: some View {
        Section {
            LabeledContent(content: {
                if mgr.wzRunning {
                    HStack {
                        ProgressView()
                    }
                } else if mgr.wzAttached {
                    Image(systemName: "checkmark.circle")
                }
            }) {
                Button("连接王者进程", action: {
                    mgr.wzAttach()
                })
                .disabled(mgr.wzRunning || mgr.wzAttached)
            }
            
            if mgr.wzAttached {
                Text("传输：\(mgr.wzTransportName) · \(mgr.wzCanWrite ? "读写" : "只读")")
                    .font(.caption)
                    .foregroundColor(mgr.wzCanWrite ? .secondary : .orange)
                Text(mgr.wzStatus)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                if mgr.wzGameHUDEnabled {
                    Text("悬浮窗：\(mgr.wzGameHUDStatus)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button("打开 Core 控制面板") {
                showWZControlPanel = true
            }
            
            Button("断开王者进程", action: {
                mgr.wzDetach()
            })
            .disabled(mgr.wzRunning || !mgr.wzAttached)
        } header: {
            HeaderLabel(text: "王者内存读取", icon: "externaldrive")
        }
    }
    
    private var DebugSection: some View {
        Group {
            if weonadebugbuild_pjbweouttahereexclamationmark {
                if mgr.dsready {
                    Section(header: HeaderLabel(text: "仅调试", icon: "ant")) {
                        LabeledContent("内核基址") {
                            Text(String(format: "0x%llx", mgr.kernbase))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        LabeledContent("内核偏移") {
                            Text(String(format: "0x%llx", mgr.kernslide))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var InlineLogsSection: some View {
        if selectedlogsdisplaymode == .content {
            Section {
                ScrollView {
                    if loggernobs {
                        let combined = logger.logs.joined(separator: "\n")
                        Text(combined)
                            .font(.system(size: 13, design: .monospaced))
                            .lineSpacing(1)
                            .textSelection(.enabled)
                            .onTapGesture {
                                UIPasteboard.general.string = combined
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                    } else {
                        ForEach(Array(logger.logs.enumerated()), id: \.offset) { _, log in
                            Text(log)
                                .font(.system(size: 13, design: .monospaced))
                                .lineSpacing(1)
                                .textSelection(.enabled)
                                .onTapGesture {
                                    UIPasteboard.general.string = log
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                        }
                    }
                }
                .frame(height: 250)
                
                Button("复制全部") {
                    UIPasteboard.general.string = logger.logs.joined(separator: "\n\n")
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                
                Button("清空") {
                    logger.clear()
                }
                .foregroundColor(.red)
            } header: {
                HeaderLabel(text: "日志", icon: "terminal")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(laramgr())
}
