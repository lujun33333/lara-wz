//
//  laramgr.swift
//  lara
//
//  Created by ruter on 23.03.26.
//

import AVFoundation
import Combine
import Foundation
import Darwin
import notify
import UIKit
import WebKit

private let wzHUDActionHandler: @convention(c) (Int32) -> Void = { action in
    DispatchQueue.main.async {
        switch action {
        case 1:
            if laramgr.shared.wzAttached {
                laramgr.shared.wzDetach()
            } else {
                laramgr.shared.prepareWZEnvironment()
            }
        case 2:
            laramgr.shared.launchWZGame()
        default:
            break
        }
    }
}

private func loadMutablePropertyListDictionary(from url: URL) throws -> NSMutableDictionary {
    let data = try Data(contentsOf: url)
    var format = PropertyListSerialization.PropertyListFormat.binary
    let plist = try PropertyListSerialization.propertyList(
        from: data,
        options: [.mutableContainersAndLeaves],
        format: &format
    )
    guard let dict = plist as? NSMutableDictionary else {
        throw "Property list root is not a dictionary."
    }
    return dict
}

private func clearImmutableForOverwriteIfNeeded(path: String) -> String? {
    let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    guard majorVersion == 16 else { return nil }

    let fm = FileManager.default
    guard let attributes = try? fm.attributesOfItem(atPath: path) else { return nil }

    var updates: [FileAttributeKey: Any] = [:]
    if (attributes[.immutable] as? NSNumber)?.boolValue == true {
        updates[.immutable] = false
    }
    if (attributes[.appendOnly] as? NSNumber)?.boolValue == true {
        updates[.appendOnly] = false
    }
    guard !updates.isEmpty else { return nil }

    do {
        try fm.setAttributes(updates, ofItemAtPath: path)
        return nil
    } catch {
        return "清除不可变属性失败：\(error.localizedDescription)"
    }
}

final class laramgr: ObservableObject {
    @Published var log: String = ""
    @Published var hasOffsets: Bool = false
    @Published var dsrunning: Bool = false
    @Published var dsready: Bool = false
    @Published var dsattempted: Bool = false
    @Published var dsfailed: Bool = false
    @Published var dsprogress: Double = 0.0
    @Published var kernbase: UInt64 = 0
    @Published var kernslide: UInt64 = 0
    
    @Published var kaccessready: Bool = false
    @Published var kaccesserror: String?
    @Published var fileopinprogress: Bool = false
    @Published var testresult: String?
    #if !DISABLE_REMOTECALL
    @Published var rcrunning: Bool = false
    @Published var eligibilitystate: Bool?
    @Published var eu1progress: Double = 0.0
    @Published var eu1running: Bool = false
    @Published var eu2progress: Double = 0.0
    @Published var eu2running: Bool = false
    @Published var rcLastError: String?
    #endif
    
    @Published var vfsready: Bool = false
    @Published var vfsinitlog: String = ""
    @Published var vfsattempted: Bool = false
    @Published var vfsfailed: Bool = false
    @Published var vfsrunning: Bool = false
    @Published var vfsprogress: Double = 0.0
    @Published var sbxready: Bool = false
    @Published var sbxattempted: Bool = false
    @Published var sbxfailed: Bool = false
    @Published var sbxrunning: Bool = false
    @Published var rcready: Bool = false
    @Published var rcfailed: Bool = false
    @Published var showrespring: Bool = false
    
    @Published var showLogs: Bool = false
    @Published var showWZControlPanel: Bool = false
    
    var sbProc: RemoteCall?
    lazy var ytProc = RemoteCall(process: "youtube", useMigFilterBypass: false)
    @Published var wzAttached: Bool = false
    @Published var wzRunning: Bool = false
    @Published var wzBase: UInt64 = 0
    @Published var wzTransportName: String = "none"
    @Published var wzTransportCapabilities: UInt64 = 0
    @Published var wzCanWrite: Bool = false
    @Published var wzStatus: String = "未运行"
    @Published var wzGameHUDEnabled: Bool = false
    @Published var wzGameHUDActive: Bool = false
    @Published var wzGameHUDStatus: String = "未启动"
    @Published var wzMeasuredFPS: Double = 0
    @Published var wzChainDiagnostic: String = "等待采集"
    @Published var wzGameHUDPosition: Int = {
        let value = UserDefaults.standard.object(forKey: "wzGameHUDPosition") as? Int ?? 1
        return min(max(value, 0), 3)
    }()
    @Published var wzGameHUDLargeFont: Bool = UserDefaults.standard.bool(forKey: "wzGameHUDLargeFont")
    @Published var wzGameHUDSingleLine: Bool = UserDefaults.standard.bool(forKey: "wzGameHUDSingleLine")
    @Published var wzGameHUDInverted: Bool = UserDefaults.standard.bool(forKey: "wzGameHUDInverted")
    @Published var wzShowAvatar: Bool = true
    @Published var wzShowHealth: Bool = true
    @Published var wzShowRecall: Bool = true
    @Published var wzShowRay: Bool = false
    @Published var wzShowBox: Bool = false
    @Published var wzShowSelfVision: Bool = false
    @Published var wzShowEnemyVision: Bool = true
    @Published var wzShowMinimap: Bool = true
    @Published var wzShowMapAdjustment: Bool = true
    @Published var wzShowMonster: Bool = false
    @Published var wzShowMonsterEntity: Bool = false
    @Published var wzShowMonsterTimer: Bool = false
    @Published var wzShowSoldier: Bool = false
    @Published var wzShowSoldierEntity: Bool = false
    @Published var wzShowSkill: Bool = false
    @Published var wzMinimapSize: Double = 150
    @Published var wzMinimapX: Double = 0
    @Published var wzMinimapY: Double = 0
    @Published var wzRayWidth: Double = 1.5
    @Published var wzBoxWidth: Double = 1.5
    @Published var wzAvatarScale: Double = 1.0
    @Published var wzMonsterTextSize: Double = 13
    @Published var wzSkillX: Double = 0
    @Published var wzSkillY: Double = 0
    @Published var wzExposedLineRGBA: UInt32 = 0xEF525BFF
    @Published var wzExposedHealthRGBA: UInt32 = 0x52DA84FF
    @Published var wzDefaultLineRGBA: UInt32 = 0xF1B942FF
    @Published var wzDefaultHealthRGBA: UInt32 = 0x52DA84FF
    private var wzGameHUDSessionArmed: Bool = false
    private var wzFPSWindowStart = Date()
    private var wzFPSFrameCount: Int = 0
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    
    static let shared = laramgr()
    static let fontpath = "/System/Library/Fonts/Core/SFUI.ttf"
    static let italicfontpath = "/System/Library/Fonts/Core/SFUIItalic.ttf"
    static let monofontpath = "/System/Library/Fonts/Core/SFUIMono.ttf"
    init() {
        wzhud_set_action_callback(wzHUDActionHandler)
    }

    struct AppInfo {
        let executable: String
        let displayName: String
        let bundleName: String
        let dataFolder: String
        let bundleFolder: String
    }
    
    func run(completion: ((Bool) -> Void)? = nil) {
        guard !dsrunning else { return }
        if dsready || ds_is_ready() {
            dsready = true
            dsfailed = false
            dsprogress = 1.0
            kernbase = ds_get_kernel_base()
            kernslide = ds_get_kernel_slide()
            logmsg("(ds) 内核读写已就绪，跳过重复注入")
            completion?(true)
            return
        }
        dsrunning = true
        dsready = false
        dsfailed = false
        dsattempted = true
        dsprogress = 0.0
        log = ""
        
        ds_set_log_callback { messageCStr in
            guard let messageCStr else { return }
            let message = String(cString: messageCStr)
            DispatchQueue.main.async {
                laramgr.shared.logmsg("(ds) \(message)")
            }
        }
        ds_set_progress_callback { progress in
            DispatchQueue.main.async {
                laramgr.shared.dsprogress = progress
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = ds_run()
            
            DispatchQueue.main.async {
                guard let self else { return }
                self.dsrunning = false
                let success = result == 0 && ds_is_ready()
                if success {
                    self.dsready = true
                    self.dsfailed = false
                    self.kernbase = ds_get_kernel_base()
                    self.kernslide = ds_get_kernel_slide()
                    self.logmsg("\n(ds) 漏洞利用成功！")
                    self.logmsg(String(format: "(ds) 内核基址：0x%llx", self.kernbase))
                    self.logmsg(String(format: "(ds) 内核偏移：0x%llx\n", self.kernslide))
                    globallogger.log("(ds) 漏洞利用成功！")
                    globallogger.log(String(format: "(ds) 内核基址：0x%llx", self.kernbase))
                    globallogger.log(String(format: "(ds) 内核偏移：0x%llx", self.kernslide))
                    globallogger.divider()
                    // 内存初始化成功即开启常驻保活，与具体功能开关解耦
                    self.startBackgroundAudio()
                } else {
                    self.dsfailed = true
                    self.logmsg("\n漏洞利用失败。\n")
                    globallogger.log("漏洞利用失败。")
                    globallogger.divider()
                }
                self.dsprogress = 1.0
                completion?(success)
            }
        }
    }
    
    func logmsg(_ message: String) {
        DispatchQueue.main.async {
            self.log += message + "\n"
            // 防止日志无限增长：超长时只保留尾部，避免大字符串 append 拖垮主线程触发看门狗
            if self.log.count > 200_000 {
                self.log = String(self.log.suffix(100_000))
            }
            globallogger.log(message)
        }
    }
    
    func kread64(address: UInt64) -> UInt64 {
        guard dsready else { return 0 }
        return ds_kread64(address)
    }
    
    func kwrite64(address: UInt64, value: UInt64) {
        guard dsready else { return }
        ds_kwrite64(address, value)
    }
    
    func kread32(address: UInt64) -> UInt32 {
        guard dsready else { return 0 }
        return ds_kread32(address)
    }
    
    func kwrite32(address: UInt64, value: UInt32) {
        guard dsready else { return }
        ds_kwrite32(address, value)
    }
    
    func panic() {
        guard dsready else { return }
        
        globallogger.log("触发内核崩溃")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            let kernbase = ds_get_kernel_base()
            globallogger.log("正在向内核基址的只读内存写入")
            ds_kwrite64(kernbase, 0xDEADBEEF)
        }
    }
    
    func respring() {
        showrespring = true
    }
    
    // MARK: - 王者进程内存读取
    
    // All WZ operations run on this queue. The main queue owns UI settings.
    private let wzWorker = DispatchQueue(label: "lara.wz.session", qos: .userInitiated)
    private var wzTimer: DispatchSourceTimer?
    private var wzEpoch: UInt64 = 0
    private var wzLaunchEpoch: UInt64 = 0
    private var wzLastResult = ""
    private var wzLastResultTime = Date.distantPast
    private var wzTickNumber: UInt64 = 0
    private var wzHostingInFlight = false
    private var wzHostingShutdownInFlight = false
    private var wzLastHUDText = ""
    private var wzLastHUDUpdateTime = Date.distantPast
    private var wzLastHUDControlFlags = UInt32.max
    private var wzLastConfigFingerprint: UInt64 = UInt64.max
    private var wzConsecutiveListFailures = 0

    private let wzExpectedUUID: [UInt8] = [
        0x6a,0x83,0x8f,0x46,0xa5,0xe8,0x3e,0xc9,
        0xbb,0xce,0x6b,0x01,0xab,0x2f,0xfa,0xd4
    ]

    private func wzBytes(_ address: UInt64, _ count: Int) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: count)
        let n: Int = bytes.withUnsafeMutableBytes { raw in
            wz_read(address, raw.baseAddress, count)
        }
        return n == count ? bytes : nil
    }
    private func wzCheckImage(_ base: UInt64) -> Bool {
        guard let header = wzBytes(base, 32) else { return false }
        func u32(_ b: [UInt8], _ p: Int) -> UInt32 {
            UInt32(b[p]) | UInt32(b[p+1]) << 8 | UInt32(b[p+2]) << 16 | UInt32(b[p+3]) << 24
        }
        guard u32(header, 0) == 0xfeedfacf,
              u32(header, 4) == 0x0100000c,
              u32(header, 12) == 6 else { return false }
        let count = Int(u32(header, 16)), length = Int(u32(header, 20))
        guard length > 0, length <= 1024 * 1024,
              let commands = wzBytes(base+32, length) else { return false }
        var cursor = 0
        for _ in 0..<count {
            guard cursor+8 <= commands.count else { return false }
            let cmd = u32(commands, cursor), size = Int(u32(commands, cursor+4))
            guard size >= 8, size <= commands.count-cursor else { return false }
            if cmd == 0x1b {
                guard size >= 24 else { return false }
                let uuid = Array(commands[(cursor+8)..<(cursor+24)])
                logmsg("(wz) UnityFramework UUID=" + uuid.map { String(format: "%02x", $0) }.joined())
                return uuid == wzExpectedUUID
            }
            cursor += size
        }
        return false
    }
    private func wzUnityFrameworkBase() -> UInt64 {
        wzExpectedUUID.withUnsafeBufferPointer { uuid in
            wz_find_image_base(uuid.baseAddress, 6)
        }
    }
    private func wzCollectorPagesReadable(_ unityBase: UInt64) -> Bool {
        // These are page-readability probes, not value assertions: the slots
        // may legitimately contain zero before a match begins, but the pages
        // themselves must be readable by the selected external transport.
        let requiredRVAs: [(String, UInt64)] = [
            ("matrix", 0x12CA9580),
            ("actor", 0x1325A6C0)
        ]
        var readable = 0
        for (name, rva) in requiredRVAs {
            var slot: UInt64 = 0
            let count = withUnsafeMutableBytes(of: &slot) { bytes in
                wz_read(unityBase + rva, bytes.baseAddress, bytes.count)
            }
            if count == MemoryLayout<UInt64>.size {
                readable += 1
            } else {
                logmsg("(wz.profile) \(name) page unreadable addr=0x\(String(unityBase + rva, radix: 16)) transport=\(String(cString: wz_transport_name())) completed=\(count)")
            }
        }
        return readable == requiredRVAs.count
    }
    func initializeWZEnvironment() {
        prepareWZEnvironment(connectWhenReady: false)
    }
    func setWZControlPanelPresented(_ presented: Bool) {
        // Core 2.2 keeps its application scene portrait (mask 2) and uses the
        // system HUD window as the single control surface in both apps. Do not
        // mount a second SwiftUI copy or rotate the LARA scene underneath it.
        showWZControlPanel = false
        if presented {
            if !wzGameHUDEnabled { setGameHUD(true) }
            wzhud_set_panel_visible(true)
        } else {
            wzhud_set_panel_visible(false)
        }
    }
    func openWZControlPanel() {
        if dsready && hasOffsets {
            setWZControlPanelPresented(true)
        } else {
            initializeWZEnvironment()
        }
    }
    func prepareWZEnvironment(connectWhenReady: Bool = true) {
        guard !dsrunning, !wzRunning, !wzAttached else { return }
        if !dsready {
            offsets_init()
            wzStatus = "正在初始化内核环境"
            run { [weak self] success in
                guard let self else { return }
                if success {
                    self.prepareWZEnvironment(connectWhenReady: connectWhenReady)
                } else {
                    self.wzStatus = "内核环境初始化失败"
                }
            }
            return
        }
        if !hasOffsets {
            wzRunning = true
            wzStatus = "正在获取并解析内核偏移"
            logmsg("(wz) 正在获取 kernelcache 并解析内核偏移")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let fetched = fetchkcache()
                let loaded = fetched && dlkcache()
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.hasOffsets = loaded
                    self.wzRunning = false
                    if loaded {
                        if connectWhenReady {
                            self.wzStatus = "内核偏移已就绪，正在连接王者荣耀"
                            self.logmsg("(wz) 内核偏移已就绪，继续连接 smoba")
                            self.wzAttach()
                        } else {
                            self.wzStatus = "内核环境已就绪，可以启动游戏"
                            self.logmsg("(wz) 内核环境和偏移已就绪")
                            self.setWZControlPanelPresented(true)
                        }
                    } else {
                        self.wzStatus = "内核偏移获取失败"
                        self.logmsg("(wz) kernelcache 获取或偏移解析失败")
                    }
                }
            }
            return
        }
        if connectWhenReady {
            wzAttach()
        } else {
            wzStatus = "内核环境已就绪，可以启动游戏"
            setWZControlPanelPresented(true)
        }
    }
    func launchWZGame() {
        guard dsready, hasOffsets else {
            wzStatus = "请先完成内核初始化，再启动游戏"
            initializeWZEnvironment()
            return
        }
        guard let url = URL(string: "smoba1104466820://") else {
            wzStatus = "王者荣耀启动地址无效"
            return
        }
        // The Core system panel is already the controller. Keeping the SwiftUI
        // copy mounted here caused the duplicated panels in device captures.
        showWZControlPanel = false
        setGameHUD(true)
        wzLaunchEpoch &+= 1
        let launchEpoch = wzLaunchEpoch
        _ = wzhud_prepare_game_launch()
        // The helper only registers Lara's existing Core contexts. It never
        // executes UIKit or RemoteCall inside SpringBoard, and failure never
        // blocks launching the game.
        wzStatus = "正在启动原版 Core 悬浮窗"
        prepareWZContextHostAndOpen(url: url, epoch: launchEpoch)
    }

    private func prepareWZContextHostAndOpen(url: URL, epoch: UInt64) {
        guard epoch == wzLaunchEpoch else { return }
        guard !wzHostingInFlight else { return }
        wzHostingInFlight = true
        wzGameHUDStatus = "正在启动独立 HUD 托管进程"
        wzWorker.async { [weak self] in
            let hosted = wzhud_start_context_host_helper()
            let reason = String(cString: wzhud_last_error())
            DispatchQueue.main.async {
                guard let self else { return }
                self.wzHostingInFlight = false
                guard epoch == self.wzLaunchEpoch else {
                    if hosted {
                        self.wzWorker.async {
                            _ = wzhud_stop_context_host_helper()
                        }
                    }
                    return
                }
                if hosted && wzhud_springboard_hosting_ready() {
                    self.wzGameHUDActive = true
                    self.wzGameHUDStatus = "原版 Core 菜单已由独立 HUD 进程托管"
                    self.logmsg("(wz.hud) context helper ready; no SpringBoard RemoteCall")
                } else {
                    self.wzGameHUDActive = false
                    self.wzGameHUDStatus = reason.isEmpty
                        ? "HUD 托管失败，游戏仍继续启动"
                        : "\(reason)（游戏仍继续启动）"
                    self.logmsg("(wz.hud) context helper failed error=\(reason)")
                }
                self.openWZGameURL(url, epoch: epoch)
            }
        }
    }

    private func openWZGameURL(_ url: URL, epoch: UInt64) {
        guard epoch == wzLaunchEpoch else { return }
        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            DispatchQueue.main.async {
                guard let self else { return }
                guard epoch == self.wzLaunchEpoch else { return }
                if opened {
                    self.wzStatus = "游戏已启动，等待 smoba 进程"
                    self.scheduleWZAttachAfterLaunch(attempt: 0)
                } else {
                    self.wzStatus = "未能启动王者荣耀"
                    self.logmsg("(wz) smoba URL scheme 启动失败")
                    self.wzLaunchEpoch &+= 1
                    self.hideGameHUD("游戏启动失败，已注销悬浮窗")
                }
            }
        }
    }
    private func scheduleWZAttachAfterLaunch(attempt: Int) {
        guard !wzAttached, attempt < 15 else { return }
        let delay = attempt == 0 ? 2.5 : 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.wzAttached else { return }
            if !self.wzRunning { self.wzAttach() }
            self.scheduleWZAttachAfterLaunch(attempt: attempt + 1)
        }
    }
    func wzAttach(process: String = "smoba") {
        guard !wzRunning, !wzAttached else { return }
        wzRunning = true
        wzEpoch &+= 1
        let epoch = wzEpoch
        let build = Bundle.main.infoDictionary?["LARABuildSourceCommit"] as? String ?? "unknown"
        logmsg("(lara-wz) build=\(build) profile=smoba-11.4.10103/6a838f46")
        logmsg("正在连接进程「\(process)」")
        wzWorker.async { [weak self] in
            guard let self else { return }
            let connected = process.withCString { wz_connect($0) }
            let base = connected ? self.wzUnityFrameworkBase() : 0
            let transportReady = connected && wz_transport_ready()
            let capabilities = transportReady ? wz_transport_capabilities() : 0
            let backendCanWrite = transportReady && wz_transport_can_write()
            // 王者 11.4.10103 当前只同步了 Core/Koi 的只读采集链。
            // 未经该版本验证的王者写偏移不得因 mapped-pages 可写而解锁。
            let canWrite = false
            let transportName = transportReady ? String(cString: wz_transport_name()) : "none"
            let imageValid = transportReady && base != 0 && self.wzCheckImage(base)
            let profileReadable = imageValid && self.wzCollectorPagesReadable(base)
            let valid = imageValid && profileReadable
            let pid = wz_connected_pid()
            if valid {
                wzesp_reset()
            } else {
                wz_disconnect()
            }
            DispatchQueue.main.async {
                guard self.wzEpoch == epoch else { return }
                self.wzRunning = false
                self.wzAttached = valid
                self.wzBase = valid ? base : 0
                self.wzTransportName = valid ? transportName : "none"
                self.wzTransportCapabilities = valid ? capabilities : 0
                self.wzCanWrite = valid && canWrite
                if valid {
                    transportName.withCString {
                        wzhud_set_transport_state(true, self.wzCanWrite, $0)
                    }
                    var hudConfig = self.wzHUDConfig()
                    wzhud_set_wz_config(&hudConfig)
                    self.logmsg("(wz) connected pid=\(pid) UnityFramework=0x\(String(base, radix: 16)) transport=\(transportName) backendWrite=\(backendCanWrite ? "yes" : "no") profileWrite=disabled")
                    self.wzGameHUDEnabled = true
                    self.wzGameHUDSessionArmed = true
                    UserDefaults.standard.set(false, forKey: "wzGameHUDEnabled")
                    self.applyGameHUDPresentation()
                    // Core creates QXA105/QXA110 exactly once from the scene
                    // controller. A game-memory attach only updates transport
                    // and snapshot state; it never re-enters window creation
                    // after smoba has foregrounded.
                    let requested = wzhud_is_enabled()
                    self.startWZLoop()
                    self.updateGameHUD("王者已连接\n等待功能开关")
                    let hudError = String(cString: wzhud_last_error())
                    self.logmsg("(wz.hud) requested=\(requested ? "yes" : "no") active=\(self.wzGameHUDActive ? "yes" : "no") error=\(hudError.isEmpty ? "none" : hudError)")
                } else {
                    "none".withCString {
                        wzhud_set_transport_state(false, false, $0)
                    }
                    self.logmsg("连接失败：smoba/UnityFramework、UUID 或王者采集数据页不可读")
                }
            }
        }
    }
    func wzReadBase() {
        guard wz_transport_ready(), wzAttached, !wzRunning else { return }
        wzRunning = true
        let base = wzBase
        wzWorker.async { [weak self] in
            guard let self else { return }
            if let bytes = self.wzBytes(base,64) { self.logmsg(self.wzHexdump(bytes,base)) }
            else { self.logmsg("(wz) 主程序头读取失败") }
            DispatchQueue.main.async { self.wzRunning = false }
        }
    }
    func wzDetach() {
        // Detach is serialized on wzWorker.  Do not drop a user request just
        // because attach/read is still in flight; epoch invalidation makes
        // the stale completion harmless and this block releases the session
        // after the queued operation.
        guard wzAttached || wzRunning || wzTimer != nil else { return }
        wzRunning = true
        wzEpoch &+= 1
        wzTimer?.cancel()
        wzTimer = nil
        wzWorker.async { [weak self] in
            guard let self else { return }
            // The queue orders this after every in-flight read-only WZ frame.
            wzesp_reset()
            wz_disconnect()
            "none".withCString {
                wzhud_set_transport_state(false, false, $0)
            }
            wzhud_update_wz_snapshot(nil, 0)
            self.wzLastResult = ""
            self.wzLastHUDText = ""
            self.wzLastHUDControlFlags = UInt32.max
            self.wzLastConfigFingerprint = UInt64.max
            self.wzFPSWindowStart = Date()
            self.wzFPSFrameCount = 0
            DispatchQueue.main.async {
                self.wzAttached = false
                self.wzBase = 0
                self.wzTransportName = "none"
                self.wzTransportCapabilities = 0
                self.wzCanWrite = false
                self.wzMeasuredFPS = 0
                self.wzChainDiagnostic = "已断开"
                self.resetWZFeatureState()
                self.wzRunning = false
                self.wzStatus = "已断开"
                self.hideGameHUD("已断开")
                self.logmsg("王者工作队列已结束，端口、映射与会话已释放")
            }
        }
    }

    private func resetWZFeatureState() {
        wzShowAvatar = true
        wzShowHealth = true
        wzShowRecall = true
        wzShowRay = false
        wzShowBox = false
        wzShowSelfVision = false
        wzShowEnemyVision = true
        wzShowMinimap = true
        wzShowMapAdjustment = true
        wzShowMonster = false
        wzShowMonsterEntity = false
        wzShowMonsterTimer = false
        wzShowSoldier = false
        wzShowSoldierEntity = false
        wzShowSkill = false
        var config = wzHUDConfig()
        wzhud_set_wz_config(&config)
    }

    func setGameHUD(_ enabled: Bool) {
        wzGameHUDEnabled = enabled
        UserDefaults.standard.set(false, forKey: "wzGameHUDEnabled")
        if enabled {
            wzGameHUDSessionArmed = true
            var config = wzHUDConfig()
            wzhud_set_wz_config(&config)
            wzTransportName.withCString {
                wzhud_set_transport_state(wzAttached, wzCanWrite, $0)
            }
            applyGameHUDPresentation()
            // Core creates its system windows while the controller app is
            // still foreground. Creating them only after smoba attaches means
            // they belong to an already-backgrounded scene and never surface
            // above the game.
            let requested = wzhud_set_enabled(true)
            wzGameHUDActive = requested && wzhud_is_enabled()
            if wzAttached {
                updateGameHUD("王者已连接\n等待功能开关")
            } else {
                wzGameHUDStatus = wzGameHUDActive
                    ? "悬浮窗已准备\n等待王者进程"
                    : "悬浮窗创建失败"
            }
        } else {
            // Invalidate in-flight direct-float callbacks before cleanup.
            wzLaunchEpoch &+= 1
            hideGameHUD("已关闭")
        }
    }
    func setGameHUDPosition(_ position: Int) {
        wzGameHUDPosition = min(max(position, 0), 3)
        UserDefaults.standard.set(wzGameHUDPosition, forKey: "wzGameHUDPosition")
        applyGameHUDPresentation()
    }
    func setGameHUDLargeFont(_ enabled: Bool) {
        wzGameHUDLargeFont = enabled
        UserDefaults.standard.set(enabled, forKey: "wzGameHUDLargeFont")
        applyGameHUDPresentation()
    }
    func setGameHUDSingleLine(_ enabled: Bool) {
        wzGameHUDSingleLine = enabled
        UserDefaults.standard.set(enabled, forKey: "wzGameHUDSingleLine")
        applyGameHUDPresentation()
    }
    func setGameHUDInverted(_ enabled: Bool) {
        wzGameHUDInverted = enabled
        UserDefaults.standard.set(enabled, forKey: "wzGameHUDInverted")
        applyGameHUDPresentation()
    }
    private func wzFeatureFlags() -> UInt32 {
        var flags: UInt32 = 0
        if wzShowAvatar { flags |= UInt32(WZESP_SHOW_AVATAR) }
        if wzShowHealth { flags |= UInt32(WZESP_SHOW_HEALTH) }
        if wzShowRecall { flags |= UInt32(WZESP_SHOW_RECALL) }
        if wzShowRay { flags |= UInt32(WZESP_SHOW_RAY) }
        if wzShowBox { flags |= UInt32(WZESP_SHOW_BOX) }
        if wzShowSelfVision { flags |= UInt32(WZESP_SHOW_SELF_VISION) }
        if wzShowEnemyVision { flags |= UInt32(WZESP_SHOW_ENEMY_VISION) }
        if wzShowMinimap { flags |= UInt32(WZESP_SHOW_MINIMAP) }
        if wzShowMapAdjustment { flags |= UInt32(WZESP_SHOW_MAP_ADJUSTMENT) }
        if wzShowMonster { flags |= UInt32(WZESP_SHOW_MONSTER) }
        if wzShowMonsterEntity { flags |= UInt32(WZESP_SHOW_MONSTER_ENTITY) }
        if wzShowMonsterTimer { flags |= UInt32(WZESP_SHOW_MONSTER_TIMER) }
        if wzShowSoldier { flags |= UInt32(WZESP_SHOW_SOLDIER) }
        if wzShowSoldierEntity { flags |= UInt32(WZESP_SHOW_SOLDIER_ENTITY) }
        if wzShowSkill { flags |= UInt32(WZESP_SHOW_SKILL) }
        return flags & UInt32(WZESP_READ_FEATURES)
    }
    private func wzHUDConfig() -> wzesp_config_t {
        var config = wzesp_config_t()
        config.flags = wzFeatureFlags()
        config.minimapSize = Float(min(max(wzMinimapSize, 60), 520))
        config.minimapX = Float(min(max(wzMinimapX, -300), 300))
        config.minimapY = Float(min(max(wzMinimapY, -200), 200))
        config.rayWidth = Float(min(max(wzRayWidth, 0.5), 6))
        config.boxWidth = Float(min(max(wzBoxWidth, 0.5), 6))
        config.avatarScale = Float(min(max(wzAvatarScale, 0.5), 2))
        config.monsterTextSize = Float(min(max(wzMonsterTextSize, 9), 28))
        config.skillX = Float(min(max(wzSkillX, -300), 300))
        config.skillY = Float(min(max(wzSkillY, -40), 260))
        config.exposedLineRGBA = wzExposedLineRGBA
        config.exposedHealthRGBA = wzExposedHealthRGBA
        config.defaultLineRGBA = wzDefaultLineRGBA
        config.defaultHealthRGBA = wzDefaultHealthRGBA
        return config
    }
    func setWZFeature(_ flag: UInt32, enabled: Bool) {
        guard (flag & UInt32(WZESP_ALL_FEATURES)) != 0 else { return }
        switch flag {
        case UInt32(WZESP_SHOW_AVATAR): wzShowAvatar = enabled
        case UInt32(WZESP_SHOW_HEALTH): wzShowHealth = enabled
        case UInt32(WZESP_SHOW_RECALL): wzShowRecall = enabled
        case UInt32(WZESP_SHOW_RAY): wzShowRay = enabled
        case UInt32(WZESP_SHOW_BOX): wzShowBox = enabled
        case UInt32(WZESP_SHOW_SELF_VISION): wzShowSelfVision = enabled
        case UInt32(WZESP_SHOW_ENEMY_VISION): wzShowEnemyVision = enabled
        case UInt32(WZESP_SHOW_MINIMAP): wzShowMinimap = enabled
        case UInt32(WZESP_SHOW_MAP_ADJUSTMENT): wzShowMapAdjustment = enabled
        case UInt32(WZESP_SHOW_MONSTER): wzShowMonster = enabled
        case UInt32(WZESP_SHOW_MONSTER_ENTITY): wzShowMonsterEntity = enabled
        case UInt32(WZESP_SHOW_MONSTER_TIMER): wzShowMonsterTimer = enabled
        case UInt32(WZESP_SHOW_SOLDIER): wzShowSoldier = enabled
        case UInt32(WZESP_SHOW_SOLDIER_ENTITY): wzShowSoldierEntity = enabled
        case UInt32(WZESP_SHOW_SKILL): wzShowSkill = enabled
        default: return
        }
        var config = wzHUDConfig()
        wzhud_set_wz_config(&config)
        if enabled && !wzGameHUDEnabled { setGameHUD(true) }
    }
    func syncWZPresentation() {
        var config = wzHUDConfig()
        wzhud_set_wz_config(&config)
    }
    func cycleWZColor(_ slot: Int) {
        let palette: [UInt32] = [
            0xEF525BFF, 0x52DA84FF, 0xF1B942FF,
            0x4AA3FFFF, 0xB66EFFFF, 0xFFFFFFFF
        ]
        func next(_ value: UInt32) -> UInt32 {
            guard let index = palette.firstIndex(of: value) else { return palette[0] }
            return palette[(index + 1) % palette.count]
        }
        switch slot {
        case 1: wzExposedLineRGBA = next(wzExposedLineRGBA)
        case 2: wzExposedHealthRGBA = next(wzExposedHealthRGBA)
        case 3: wzDefaultLineRGBA = next(wzDefaultLineRGBA)
        case 4: wzDefaultHealthRGBA = next(wzDefaultHealthRGBA)
        default: return
        }
        syncWZPresentation()
    }
    private func applyGameHUDPresentation() {
        wzhud_set_presentation(
            Int32(wzGameHUDPosition),
            wzGameHUDLargeFont,
            wzGameHUDSingleLine,
            wzGameHUDInverted
        )
    }
    private func updateGameHUD(_ text: String) {
        guard wzGameHUDEnabled, wzGameHUDSessionArmed, wzAttached else { return }
        text.withCString { wzhud_update_text($0) }
        wzGameHUDActive = wzhud_springboard_hosting_ready()
        let error = String(cString: wzhud_last_error())
        wzGameHUDStatus = wzGameHUDActive ? "原版 Core 跨进程菜单运行中" :
            (error.isEmpty ? "独立 HUD 托管进程启动中" : error)
    }
    private func hideGameHUD(_ status: String) {
        wzGameHUDEnabled = false
        wzGameHUDSessionArmed = false
        wzGameHUDActive = false
        wzGameHUDStatus = status
        if wzHostingShutdownInFlight {
            wzGameHUDStatus = "正在停止独立 HUD 托管进程"
            return
        }
        guard wzhud_springboard_hosting_ready() else {
            wzhud_set_enabled(false)
            return
        }

        wzHostingShutdownInFlight = true
        wzWorker.async { [weak self] in
            let removed = wzhud_stop_context_host_helper()
            let reason = String(cString: wzhud_last_error())
            DispatchQueue.main.async {
                guard let self else { return }
                self.wzHostingShutdownInFlight = false
                wzhud_set_enabled(false)
                if removed {
                    self.logmsg("(wz.hud) context helper stopped")
                } else {
                    self.wzGameHUDStatus = reason.isEmpty
                        ? "独立 HUD 托管进程停止不完整"
                        : reason
                    self.logmsg("(wz.hud) context helper stop failed error=\(reason)")
                }
            }
        }
    }
    private func startWZLoop() {
        guard wzTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: wzWorker)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in self?.wzFrame() }
        wzTimer = timer
        timer.resume()
    }
    private func wzFrame() {
        let request = DispatchQueue.main.sync {
            var canvasWidth = Double(UIScreen.main.bounds.width)
            var canvasHeight = Double(UIScreen.main.bounds.height)
            wzhud_get_canvas_size(&canvasWidth, &canvasHeight)
            return (wzEpoch, wzBase, wzAttached,
                    CGSize(width: CGFloat(canvasWidth),
                           height: CGFloat(canvasHeight)))
        }
        guard request.2, request.1 != 0 else { return }
        guard wz_transport_ready() else {
            wzhud_update_wz_snapshot(nil, 0)
            return
        }

        var config = wzesp_config_t()
        wzhud_copy_wz_config(&config)
        config.flags &= UInt32(WZESP_READ_FEATURES)
        let drawEnabled = config.flags != 0
        let fingerprint = wzConfigFingerprint(config)
        let configChanged = fingerprint != wzLastConfigFingerprint
        wzLastConfigFingerprint = fingerprint
        wzLastHUDControlFlags = config.flags

        wzTickNumber &+= 1
        wzFPSFrameCount += 1
        let fpsElapsed = Date().timeIntervalSince(wzFPSWindowStart)
        var sampledFPS: Double?
        if fpsElapsed >= 1.0 {
            sampledFPS = Double(wzFPSFrameCount) / fpsElapsed
            wzFPSFrameCount = 0
            wzFPSWindowStart = Date()
        }
        var items = [wzesp_item_t](repeating: wzesp_item_t(), count: 256)
        let width = UInt32(max(request.3.width, request.3.height))
        let height = UInt32(max(1, min(request.3.width, request.3.height)))
        let itemCount: Int = drawEnabled ? items.withUnsafeMutableBufferPointer { buffer in
            Int(wzesp_tick(request.1, width, height, &config,
                           buffer.baseAddress, Int32(buffer.count)))
        } : 0
        let stats = wzesp_stats()
        let error = String(cString: wzesp_last_error())
        items.withUnsafeBufferPointer {
            wzhud_update_wz_snapshot(itemCount > 0 ? $0.baseAddress : nil,
                                     Int32(itemCount))
        }

        if drawEnabled && stats.readFailures > 0 && itemCount == 0 {
            wzConsecutiveListFailures += 1
        } else {
            wzConsecutiveListFailures = 0
        }
        if wzConsecutiveListFailures >= 120 {
            wzConsecutiveListFailures = 0
            if !wzCheckImage(request.1) {
                wzhud_update_wz_snapshot(nil, 0)
                wzTimer?.cancel()
                wzTimer = nil
                wzesp_reset()
                wz_disconnect()
                "none".withCString {
                    wzhud_set_transport_state(false, false, $0)
                }
                let epoch = request.0
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.wzEpoch == epoch else { return }
                    self.wzAttached = false
                    self.wzBase = 0
                    self.wzTransportName = "none"
                    self.wzTransportCapabilities = 0
                    self.wzCanWrite = false
                    self.resetWZFeatureState()
                    self.wzRunning = false
                    self.wzStatus = "smoba/UnityFramework 已失效，等待重新连接"
                    self.hideGameHUD("目标已断开")
                }
                return
            }
        }

        let diagnostic = wzChainDescription(stats)
        let text = drawEnabled
            ? "frame=\(wzTickNumber) entities=\(stats.entityCount) items=\(itemCount) readFail=\(stats.readFailures) chain=0x\(String(stats.chainFailureMask, radix: 16)) \(diagnostic) \(error)"
            : "王者只读绘制已停止"
        let hudText = drawEnabled
            ? "王者只读绘制\n实体:\(stats.entityCount) 可见:\(itemCount)"
            : "王者已连接\n绘制未开启"
        let now = Date()
        let shouldLog = text != wzLastResult &&
            now.timeIntervalSince(wzLastResultTime) >= 1
        let shouldUpdateHUD = hudText != wzLastHUDText &&
            now.timeIntervalSince(wzLastHUDUpdateTime) >= 0.5
        wzLastResult = text
        if shouldLog { wzLastResultTime = now }
        if shouldUpdateHUD {
            wzLastHUDText = hudText
            wzLastHUDUpdateTime = now
        }
        if shouldLog { logmsg("(wz-frame) " + text) }
        if shouldLog || shouldUpdateHUD || configChanged || sampledFPS != nil {
            let epoch = request.0
            let publishedConfig = config
            DispatchQueue.main.async { [weak self] in
                guard let self, self.wzEpoch == epoch else { return }
                self.applyWZConfigToPublished(publishedConfig)
                if shouldLog { self.wzStatus = text }
                if shouldUpdateHUD { self.updateGameHUD(hudText) }
                if let sampledFPS { self.wzMeasuredFPS = sampledFPS }
                self.wzChainDiagnostic = diagnostic
            }
        }
    }

    private func wzChainDescription(_ stats: wzesp_stats_t) -> String {
        var failed: [String] = []
        let mask = stats.chainFailureMask
        if mask & (1 << 0) != 0 { failed.append("矩阵") }
        if mask & (1 << 1) != 0 { failed.append("ActorRoot") }
        if mask & (1 << 2) != 0 { failed.append("ActorTable") }
        if mask & (1 << 5) != 0 { failed.append("MonsterRoot") }
        if mask & (1 << 7) != 0 { failed.append("英雄坐标") }
        if mask & (1 << 8) != 0 { failed.append("英雄血量") }
        if mask & (1 << 9) != 0 { failed.append("兵线表") }
        if mask & (1 << 10) != 0 { failed.append("兵线坐标") }
        let readiness = "matrix=\(stats.matrixReady) actors=\(stats.actorVectorReady) camp=\(stats.hostCampReady) slots=\(stats.actorSlotCount)"
        return failed.isEmpty
            ? "链路正常 \(readiness)"
            : "失败:\(failed.joined(separator: ",")) \(readiness)"
    }

    private func wzConfigFingerprint(_ config: wzesp_config_t) -> UInt64 {
        var value = UInt64(config.flags)
        let scalars: [UInt32] = [
            config.minimapSize.bitPattern, config.minimapX.bitPattern,
            config.minimapY.bitPattern, config.rayWidth.bitPattern,
            config.boxWidth.bitPattern, config.avatarScale.bitPattern,
            config.monsterTextSize.bitPattern, config.skillX.bitPattern,
            config.skillY.bitPattern, config.exposedLineRGBA,
            config.exposedHealthRGBA, config.defaultLineRGBA,
            config.defaultHealthRGBA
        ]
        for scalar in scalars {
            value = (value ^ UInt64(scalar)) &* 0x100000001B3
        }
        return value
    }

    private func applyWZConfigToPublished(_ config: wzesp_config_t) {
        let flags = config.flags & UInt32(WZESP_READ_FEATURES)
        wzShowAvatar = flags & UInt32(WZESP_SHOW_AVATAR) != 0
        wzShowHealth = flags & UInt32(WZESP_SHOW_HEALTH) != 0
        wzShowRecall = flags & UInt32(WZESP_SHOW_RECALL) != 0
        wzShowRay = flags & UInt32(WZESP_SHOW_RAY) != 0
        wzShowBox = flags & UInt32(WZESP_SHOW_BOX) != 0
        wzShowSelfVision = flags & UInt32(WZESP_SHOW_SELF_VISION) != 0
        wzShowEnemyVision = flags & UInt32(WZESP_SHOW_ENEMY_VISION) != 0
        wzShowMinimap = flags & UInt32(WZESP_SHOW_MINIMAP) != 0
        wzShowMapAdjustment = flags & UInt32(WZESP_SHOW_MAP_ADJUSTMENT) != 0
        wzShowMonster = flags & UInt32(WZESP_SHOW_MONSTER) != 0
        wzShowMonsterEntity = flags & UInt32(WZESP_SHOW_MONSTER_ENTITY) != 0
        wzShowMonsterTimer = flags & UInt32(WZESP_SHOW_MONSTER_TIMER) != 0
        wzShowSoldier = flags & UInt32(WZESP_SHOW_SOLDIER) != 0
        wzShowSoldierEntity = flags & UInt32(WZESP_SHOW_SOLDIER_ENTITY) != 0
        wzShowSkill = flags & UInt32(WZESP_SHOW_SKILL) != 0
        wzMinimapSize = Double(config.minimapSize)
        wzMinimapX = Double(config.minimapX)
        wzMinimapY = Double(config.minimapY)
        wzRayWidth = Double(config.rayWidth)
        wzBoxWidth = Double(config.boxWidth)
        wzAvatarScale = Double(config.avatarScale)
        wzMonsterTextSize = Double(config.monsterTextSize)
        wzSkillX = Double(config.skillX)
        wzSkillY = Double(config.skillY)
        wzExposedLineRGBA = config.exposedLineRGBA
        wzExposedHealthRGBA = config.exposedHealthRGBA
        wzDefaultLineRGBA = config.defaultLineRGBA
        wzDefaultHealthRGBA = config.defaultHealthRGBA
    }

    // 静音音频常驻后台：让系统认为 app 仍在后台“播放”，从而使采集线程不被挂起
    private func startBackgroundAudio() {
        stopBackgroundAudio()
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2048) else { return }
        buffer.frameLength = 2048
        if let ch = buffer.floatChannelData?[0] {
            for i in 0..<Int(buffer.frameLength) { ch[i] = 0 }
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            // mixWithOthers：不独占系统，避免影响游戏声音
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try engine.start()
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logmsg("⚠️ 后台常驻音频启动失败：\(error.localizedDescription)")
        }
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
        audioEngine = engine
        audioPlayer = player
        logmsg("🔊 已开启静音音频后台常驻（写入将不会因切后台而暂停）")
    }
    
    private func stopBackgroundAudio() {
        audioPlayer?.stop()
        audioEngine?.stop()
        audioPlayer = nil
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func wzReadPointerChain(chainText: String) {
        guard dsready else {
            logmsg("❌ 内核未就绪")
            return
        }
        guard wzAttached else {
            logmsg("❌ 尚未连接王者进程，请先点击「连接王者进程」")
            return
        }
        guard !wzRunning else { return }
        let base = wzBase
        guard base != 0 else {
            logmsg("❌ 尚未获取王者模块基址，请先点击「连接王者进程」")
            return
        }
        
        let offsets = Self.parsePointerOffsets(chainText)
        guard !offsets.isEmpty else {
            logmsg("❌ 指针链格式错误：请用十六进制偏移并以 +（或空格、逗号）分隔，例如 0xC003C10+0xA0+0x210+0x1D0")
            return
        }
        
        wzRunning = true
        logmsg("正在读取指针链（共 \(offsets.count) 级）...")
        
        wzWorker.async { [weak self] in
            defer {
                DispatchQueue.main.async { laramgr.shared.wzRunning = false }
            }
            guard let self else { return }
            
            var addr = base
            self.logmsg(String(format: "基址 = 0x%llx", base))
            
            // 前 N-1 个偏移做指针跳转（读 8 字节指针），最后一个偏移是最终字段偏移（不再解引用）
            let pointerJumps = max(offsets.count - 1, 0)
            for i in 0..<pointerJumps {
                let offset = offsets[i]
                let ptrAddr = addr + offset
                var value: UInt64 = 0
                let n = withUnsafeMutableBytes(of: &value) { raw -> Int in
                    wz_read(ptrAddr, raw.baseAddress, 8)
                }
                guard n == 8 else {
                    self.logmsg(String(format: "❌ 第 %d 级读取失败：无法读取 0x%llx（+0x%llx）", i + 1, ptrAddr, offset))
                    return
                }
                self.logmsg(String(format: "0x%llx + 0x%llx -> 0x%llx", addr, offset, value))
                if value == 0 {
                    self.logmsg("⚠️ 第 \(i + 1) 级读到的指针为 0，指针链中断")
                    return
                }
                addr = value
            }
            
            let finalOffset = offsets.last!
            let finalAddr = addr + finalOffset
            self.logmsg(String(format: "0x%llx + 0x%llx = 最终地址 0x%llx", addr, finalOffset, finalAddr))
            
            var val32: Int32 = 0
            let n2 = withUnsafeMutableBytes(of: &val32) { raw -> Int in
                wz_read(finalAddr, raw.baseAddress, 4)
            }
            guard n2 == 4 else {
                self.logmsg(String(format: "❌ 读取最终地址 0x%llx 的值失败", finalAddr))
                return
            }
            let u32 = UInt32(bitPattern: val32)
            let f32 = Float(bitPattern: u32)
            self.logmsg(String(format: "✅ 最终地址 0x%llx 的值：i32 = %d（0x%08x），f32 = %f", finalAddr, val32, u32, f32))
        }
    }
    
    static func parsePointerOffsets(_ text: String) -> [UInt64] {
        var seps = CharacterSet.whitespacesAndNewlines
        seps.insert(charactersIn: "+,")
        let tokens = text.components(separatedBy: seps)
        var result: [UInt64] = []
        for raw in tokens {
            let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty { continue }
            var t = token
            if t.hasPrefix("0x") || t.hasPrefix("0X") {
                t = String(t.dropFirst(2))
            }
            if let v = UInt64(t, radix: 16) {
                result.append(v)
            }
        }
        return result
    }
    
    private func wzHexdump(_ bytes: [UInt8], _ base: UInt64) -> String {
        var lines: [String] = []
        var i = 0
        while i < bytes.count {
            let end = min(i + 16, bytes.count)
            let chunk = bytes[i..<end]
            let addr = String(format: "0x%llx", base + UInt64(i))
            let hex = chunk.map { String(format: "%02x", $0) }.joined(separator: " ")
            let ascii = chunk.map { c -> String in
                (c >= 0x20 && c <= 0x7e) ? String(UnicodeScalar(c)) : "."
            }.joined()
            lines.append(String(format: "%@  %@  %@",
                                addr,
                                hex.padding(toLength: 47, withPad: " ", startingAt: 0),
                                ascii))
            i += 16
        }
        return lines.joined(separator: "\n")
    }
    
    func vfsinit(completion: ((Bool) -> Void)? = nil) {
        guard dsready, hasOffsets, !vfsrunning else { return }
        vfs_setlogcallback(laramgr.vfslogcallback)
        vfs_setprogresscallback { progress in
            DispatchQueue.main.async {
                laramgr.shared.vfsprogress = progress
            }
        }
        vfsattempted = true
        vfsfailed = false
        vfsrunning = true
        vfsprogress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let r = vfs_init()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.vfsready = (r == 0 && vfs_isready())
                if self.vfsready {
                    self.vfsfailed = false
                    self.logmsg("\nvfs 就绪！\n")
                } else {
                    self.vfsfailed = true
                    self.logmsg("\nvfs 初始化失败。\n")
                }
                self.vfsrunning = false
                self.vfsprogress = 1.0
                completion?(self.vfsready)
            }
        }
    }
    
    func sbxescape(completion: ((Bool) -> Void)? = nil) {
        guard dsready, hasOffsets, !sbxrunning else { return }
        sbxattempted = true
        sbxfailed = false
        sbxrunning = true
        
        sbx_setlogcallback(laramgr.sbxlogcallback)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let r = sbx_escape(ds_get_our_proc())
            DispatchQueue.main.async {
                guard let self else { return }
                self.sbxready = (r == 0)
                if self.sbxready {
                    self.sbxfailed = false
                    self.logmsg("\n沙箱逃逸就绪！\n")
                } else {
                    self.sbxfailed = true
                    self.logmsg("\n沙箱逃逸失败。\n")
                }
                self.sbxrunning = false
                completion?(self.sbxready)
            }
        }
    }
    
    private static let sbxlogcallback: @convention(c) (UnsafePointer<CChar>?) -> Void = { msg in
        guard let msg = msg else { return }
        let s = String(cString: msg)
        DispatchQueue.main.async {
            laramgr.shared.logmsg("(sbx) " + s)
        }
    }
    
    private static let vfslogcallback: @convention(c) (UnsafePointer<CChar>?) -> Void = { msg in
        guard let msg = msg else { return }
        let s = String(cString: msg)
        DispatchQueue.main.async {
            laramgr.shared.vfsinitlog += "(vfs) " + s + "\n"
            laramgr.shared.logmsg("(vfs) " + s)
        }
    }
    
    func vfslistdir(path: String) -> [(name: String, isDir: Bool)]? {
        guard vfsready else {
            logmsg(" 列出目录：未就绪（\(path)）")
            return nil
        }
        var ptr: UnsafeMutablePointer<vfs_entry_t>?
        var count: Int32 = 0
        let r = vfs_listdir(path, &ptr, &count)
        guard r == 0, let entries = ptr else {
            logmsg(" 列出目录失败（\(path)）r=\(r)")
            return nil
        }
        defer { vfs_freelisting(entries) }
        
        var items: [(String, Bool)] = []
        for i in 0..<Int(count) {
            let e = entries[i]
            let name = withUnsafePointer(to: e.name) { p in
                p.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
            }
            items.append((name, e.d_type == 4))
        }
        logmsg(" 列出目录 \(path) -> \(items.count) 项")
        return items.sorted { $0.0.lowercased() < $1.0.lowercased() }
    }
    
    func vfsread(path: String, maxSize: Int = 512 * 1024) -> Data? {
        guard vfsready else { return nil }
        let fsz = vfs_filesize(path)
        if fsz <= 0 { return nil }
        let toRead = min(Int(fsz), maxSize)
        var buf = [UInt8](repeating: 0, count: toRead)
        let n = vfs_read(path, &buf, toRead, 0)
        if n <= 0 { return nil }
        return Data(buf.prefix(Int(n)))
    }
    
    func vfswrite(path: String, data: Data) -> Bool {
        guard vfsready else { return false }
        return data.withUnsafeBytes { ptr in
            let n = vfs_write(path, ptr.baseAddress, data.count, 0)
            return n > 0
        }
    }
    
    func vfssize(path: String) -> Int64 {
        guard vfsready else { return -1 }
        return vfs_filesize(path)
    }
    
    func vfsoverwritefromlocalpath(target: String, source: String) -> Bool {
        print("(vfs) target \(source) -> \(target)")
        
        guard vfsready else {
            print("(vfs) not ready")
            return false
        }
        
        guard FileManager.default.fileExists(atPath: source) else {
            print("(vfs) 源文件未找到：\(source)")
            return false
        }
        
        let r = vfs_overwritefile(target, source)
        
        print("(vfs) vfs_overwritefile returned: \(r)")
        
        if r == 0 {
            print("(vfs) file overwritten")
        } else {
            print("(vfs) failed to overwrite file")
        }
        
        return r == 0
    }
    
    func vfsoverwritewithdata(target: String, data: Data) -> Bool {
        guard vfsready else { return false }
        let tmp = NSTemporaryDirectory() + "vfs_src_\(arc4random()).bin"
        do { try data.write(to: URL(fileURLWithPath: tmp)) } catch { return false }
        let ok = vfsoverwritefromlocalpath(target: target, source: tmp)
        try? FileManager.default.removeItem(atPath: tmp)
        return ok
    }
    
    private func sbxoverwrite(path: String, data: Data) -> (ok: Bool, message: String) {
        let immutableMessage = clearImmutableForOverwriteIfNeeded(path: path)
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        if fd == -1 {
            let prefix = immutableMessage.map { "\($0), " } ?? ""
            return (false, "\(prefix)sbx 打开失败：errno=\(errno) \(String(cString: strerror(errno)))")
        }
        defer { close(fd) }
        
        var total = 0
        let wroteAll = data.withUnsafeBytes { ptr -> Bool in
            guard let base = ptr.baseAddress else { return ptr.count == 0 }
            while total < ptr.count {
                let n = write(fd, base.advanced(by: total), ptr.count - total)
                if n <= 0 { return false }
                total += n
            }
            return true
        }
        
        if !wroteAll {
            return (false, "sbx 写入失败：errno=\(errno) \(String(cString: strerror(errno)))")
        }

        if ftruncate(fd, off_t(total)) != 0 {
            return (false, "sbx 截断失败：errno=\(errno) \(String(cString: strerror(errno)))")
        }
        
        return (true, "成功（\(total) 字节）")
    }
    
    @discardableResult
    func lara_overwritefile(target: String, source: String, fallback_vfs: Bool = true) -> (ok: Bool, message: String) {
        guard FileManager.default.fileExists(atPath: source) else {
            return (false, "源文件未找到：\(source)")
        }
        
        let result: (ok: Bool, message: String)
        if sbxready {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: source))
                result = sbxoverwrite(path: target, data: data)
            } catch {
                result = (false, "sbx 读取源失败：\(error.localizedDescription)")
            }
        } else {
            result = (false, "sbx 未就绪")
        }
        
        if result.ok {
            return result
        }

        guard fallback_vfs else {
            return result
        }
        
        guard vfsready else {
            return (false, result.message + " | vfs 未就绪")
        }
        
        let ok = vfsoverwritefromlocalpath(target: target, source: source)
        return ok ? (true, "成功（vfs 覆盖）") : (false, result.message + " | vfs 覆盖失败")
    }
    
    @discardableResult
    func lara_overwritefile(target: String, data: Data, fallback_vfs: Bool = true) -> (ok: Bool, message: String) {
        let result = sbxready ? sbxoverwrite(path: target, data: data) : (false, "sbx 未就绪")
        if result.0 {
            return result
        }

        guard fallback_vfs else {
            return result
        }
        
        guard vfsready else {
            return (false, result.1 + ", vfs 未就绪")
        }
        
        let ok = vfsoverwritewithdata(target: target, data: data)
        return ok ? (true, "vfs 覆盖成功") : (false, result.1 + ", vfs 覆盖失败")
    }
    
    func vfszeropage(at path: String, dumb: Bool) -> Bool {
        if dumb {
            guard vfsready else {
                self.logmsg("(vfs) 清空文件失败（vfs 未就绪）")
                return false
            }
    
            let ok = path.withCString { vfs_zerofile($0) } == 0

            if !ok {
                self.logmsg("(vfs) 清空文件失败")
                return false
            }
            
            self.logmsg("(vfs) 已清空 \(path)")
            return true
        } else {
            let result = path.withCString { cpath in
                vfs_zeropage(cpath, 0)
            }

            if result != 0 {
                self.logmsg("(vfs) 清空页失败")
                return false
            }
    
            self.logmsg("(vfs) 已清空 \(path) 首页")
            return true
        }
    }
    
    func sbxgettoken(pid: Int32) -> UInt64? {
        let addr = sbx_gettoken(pid)

        guard addr != 0 else {
            return nil
        }

        return addr
    }

    func sbxgettokenstring(pid: Int32) -> String? {
        guard let cstr = sbx_copytoken(pid) else {
            return nil
        }
        defer { sbx_freestr(cstr) }
        return String(cString: cstr)
    }

    func sbxissuetoken(extClass: String, path: String) -> String? {
        guard let cstr = sbx_issue_token(extClass, path) else {
            return nil
        }
        defer { sbx_freestr(cstr) }
        return String(cString: cstr)
    }
    
    func sbxelevate() {
        DispatchQueue.main.async {
            sbx_elevate();
        }
    }
    
    func isapfs(_ path: String) -> Bool {
        var s = statfs()
        guard path.withCString({ statfs($0, &s) }) == 0 else {
            return false
        }
        
        let fstypename = s.f_fstypename
        return withUnsafePointer(to: fstypename) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: fstypename)) {
                String(cString: $0) == "apfs"
            }
        }
    }

    // inspired by nugget from leminlimez
    func PPHelper() -> Bool {
        do {
            let fm = FileManager.default
            let dataFolder = "/private/var/mobile/Containers/Data/Application"
            let bundleFolder = "/private/var/containers/Bundle/Application"
            var bundleIDs = ["com.apple.PosterBoard"]
            if UIDevice.current.userInterfaceIdiom == .phone {
                bundleIDs.append("com.apple.CarPlayWallpaper")
            }
            guard let appList = getAppList() else { return false}
            var hashes: [String:String] = [:]
            for bundleID in bundleIDs {
                if let appInfo = appList[bundleID] {
                    hashes[bundleID] = appInfo.dataFolder
                } else {
                    // this shouldn't happen
                    logmsg("未找到 bundle ID 为 \(bundleID) 的应用。")
                    return false
                }
            }
            var PPbundleID = "com.leemin.Pocket-Poster"
            for (bundleID, info) in appList {
                if info.executable == "Pocket Poster" {
                    PPbundleID = bundleID
                    break
                } else if info.executable == "LiveContainer" {
                    PPbundleID = bundleID
                }
            }
            if let PPHash = appList[PPbundleID]?.dataFolder {
                for bundleID in hashes.keys {
                    let fileName = "Nugget" + bundleID.replacingOccurrences(of: "com.apple.", with: "") + "Hash"
                    let content = hashes[bundleID]!
                    let filePath = dataFolder + "/" + PPHash + "/Documents/" + fileName
                    try content.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
                    logmsg("已将哈希 \(content) 写入 \(filePath)")
                }
                return true
            } else {
                logmsg("请在使用 Pocket Poster Helper 前先安装 Pocket Poster。如果你已安装 Pocket Poster，请确认没有修改其 bundle ID。如果你把 Pocket Poster 安装在 LiveContainer 内，请同时确认没有修改 LiveContainer 的 bundle ID。")
                return false
            }
        } catch {
            logmsg("Pocket Poster Helper 出错：\(error.localizedDescription)")
            return false
        }
    }

    func getAppList() -> [String:AppInfo]? {
        let fm = FileManager.default
        let dataFolder = "/private/var/mobile/Containers/Data/Application"
        let bundleFolder = "/private/var/containers/Bundle/Application"
        var appList: [String:AppInfo] = [:]
        do {
            let appData = try fm.contentsOfDirectory(atPath: dataFolder)
            for app in appData {
                if let plist = NSDictionary(contentsOf: URL(fileURLWithPath: dataFolder + "/" + app + "/.com.apple.mobile_container_manager.metadata.plist")),
                    let bundleID = plist["MCMMetadataIdentifier"] as? String {
                    appList[bundleID] = AppInfo(executable: "", displayName: "", bundleName: "", dataFolder: app, bundleFolder: "")
                }
            }

            let appBundles = try fm.contentsOfDirectory(atPath: bundleFolder)
            for app in appBundles {
                let appPath = bundleFolder + "/" + app
                let contents = try fm.contentsOfDirectory(atPath: appPath)
                for item in contents {
                    if item.hasSuffix(".app") {
                        if let plist = NSDictionary(contentsOf: URL(fileURLWithPath: appPath + "/" + item + "/Info.plist")),
                            let bundleID = plist["CFBundleIdentifier"] as? String {
                            let executable = plist["CFBundleExecutable"] as? String ?? ""
                            let displayName = plist["CFBundleDisplayName"] as? String ?? ""
                            let bundleName = plist["CFBundleName"] as? String ?? ""
                            let dataFolderID = appList[bundleID]?.dataFolder ?? ""
                            let appInfo = AppInfo(executable: executable, displayName: displayName, bundleName: bundleName, dataFolder: dataFolderID, bundleFolder: app)
                            appList[bundleID] = appInfo
                        }
                        break
                    }
                }

            }
        } catch {
            logmsg("获取应用列表出错：\(error.localizedDescription)")
            return nil
        }
        return appList
    }
    
    func setplistvalue(path: String, key: (key: String, value: Any?), force: Bool = false) -> (ok: Bool, message: String) {
        do {
            let fm = FileManager.default
            var dict = NSMutableDictionary()
            if !fm.fileExists(atPath: path) {
                if !force { return (false, "\(path) 处的文件不存在或未找到") }
            } else {
                dict = try loadMutablePropertyListDictionary(from: URL(fileURLWithPath: path))
            }
            if let value = key.value {
                dict[key.key] = value
            } else {
                dict.removeObject(forKey: key.key)
            }
            let data = try PropertyListSerialization.data(
                fromPropertyList: dict,
                format: .binary,
                options: 0
            )
            let result = self.lara_overwritefile(
                target: path,
                data: data
            )
            if result.ok {
                return (true, "已覆盖 plist：\(path)")
            } else {
                return(false, "覆盖失败：\(result.message)")
            }
        } catch {
            return (false, "发生错误：\(error)")
        }
    }

    func getplistvalue(path: String, key: String) -> (ok: Bool, message: String, value: Any?) {
        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: path) {
                let dict = try loadMutablePropertyListDictionary(from: URL(fileURLWithPath: path))
                if let value = dict[key] {
                    return (true, "成功", value)
                } else {
                    return (false, "未找到键 \(key)", nil)
                }
            } else {
                return (false, "\(path) 处的文件不存在或未找到", nil)
            }
        } catch {
            return (false, "发生错误：\(error)", nil)
        }
    }

    @discardableResult
    func apfsown(path: String, uid: UInt32, gid: UInt32) -> Bool {
        if !isapfs(path) {
            print("\(path) 是 apfs！")
        }
        
        let result = path.withCString { cPath in
            apfs_own(cPath, uid_t(uid), gid_t(gid))
        }
        
        if result != 0 {
            print("chown \(path) 失败")
            return false
        }
        
        print("已将 \(path) 的所有者改为 \(uid):\(gid)！")
        return true
    }
    
    #if !DISABLE_REMOTECALL
    func rcinit(process: String, migbypass: Bool = false, completion: ((Bool) -> Void)? = nil) {
        guard dsready else {
            completion?(false)
            return
        }
        if rcready {
            completion?(sbProc != nil)
            return
        }
        guard !rcrunning else {
            completion?(false)
            return
        }
        
        rcrunning = true
        rcLastError = nil
        logmsg("正在初始化远程调用 \(process)...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let remoteProcess = RemoteCall(
                process: process,
                useMigFilterBypass: migbypass
            )
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.sbProc = remoteProcess
                let success = remoteProcess != nil
                if success {
                    self.logmsg("远程调用已在 \(process) 上初始化")
                    self.rcLastError = nil
                    self.rcrunning = false
                    self.rcready = true
                } else {
                    self.logmsg("远程调用初始化失败 \(process)")
                    let error = RemoteCall.lastInitError()
                    self.rcLastError = error
                    if let error, !error.isEmpty {
                        self.logmsg("远程调用初始化失败 \(process)：\(error)")
                    } else {
                        self.logmsg("远程调用初始化失败 \(process)")
                    }
                    self.rcrunning = false
                }
                completion?(success)
            }
        }
    }
    
    func rcinitDaemon(serviceName: String, framework: String? = nil, process: String, migbypass: Bool = false, completion: ((RemoteCall?) -> Void)? = nil) {
        guard dsready, let sbProc else {
            completion?(nil)
            return
        }
        
        rcrunning = true
        logmsg("正在初始化远程调用 \(process)...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if process.withCString({ proc_find_by_name($0) == 0 }) {
                wake_up_daemon(sbProc, serviceName, framework)
                sleep(1) // give the daemon some time to start up
            }
            
            let proc = RemoteCall(process: process, useMigFilterBypass: migbypass)
            completion?(proc)
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                let success = proc != nil
                if success {
                    self.logmsg("远程调用已在 \(process) 上初始化")
                    self.rcrunning = false
                } else {
                    let error = RemoteCall.lastInitError()
                    if let error, !error.isEmpty {
                        self.logmsg("远程调用初始化失败 \(process)：\(error)")
                    } else {
                        self.logmsg("远程调用初始化失败 \(process)")
                    }
                    self.rcrunning = false
                }
            }
        }
    }
    
    func rcdestroy(completion: (() -> Void)? = nil) {
        guard rcready || sbProc != nil else {
            completion?()
            return
        }
        
        logmsg("正在销毁远程调用会话...")
        rcready = false
        rcrunning = true
        let remoteProcess = sbProc
        sbProc = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self, remoteProcess] in
            remoteProcess?.destroy()
            
            DispatchQueue.main.async {
                self?.rcrunning = false
                self?.logmsg("远程调用会话已销毁")
                completion?()
            }
        }
    }

    func stashKRWToLaunchd(completion: ((Bool) -> Void)? = nil) {
        guard dsready, !rcrunning else {
            completion?(false)
            return
        }

        rcrunning = true
        rcLastError = nil
        logmsg("(persist) 正在手动转移 KRW 原语到 launchd...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = transfer_krw_to_launchd()

            DispatchQueue.main.async {
                guard let self else { return }
                self.rcrunning = false
                if success {
                    self.rcLastError = nil
                    self.logmsg("(persist) 手动转移 KRW 原语到 launchd 成功")
                } else {
                    let error = RemoteCall.lastInitError()
                    self.rcLastError = error
                    if let error, !error.isEmpty {
                        self.logmsg("(persist) 手动转移 KRW 原语到 launchd 失败：\(error)")
                    } else {
                        self.logmsg("(persist) 手动转移 KRW 原语到 launchd 失败")
                    }
                }
                completion?(success)
            }
        }
    }
    
    //  params:
    //  - name: function to call
    //  - args: up to 8 args in registers (x0-x7) and extra args passed to stack pointer
    //  - timeout: timeout in ms
    //  ret: return value from rc
    func rccall(name: String, args: [UInt64] = [], timeout: Int32 = 100) -> UInt64 {
        guard rcready else { return 0 }
        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
        let ptr = dlsym(RTLD_DEFAULT, name)
        var argsCopy = args
        return name.withCString { (cName: UnsafePointer<CChar>) -> UInt64 in
            UInt64(argsCopy.withUnsafeMutableBufferPointer { buffer in
                sbProc?.doStable(
                    withTimeout: timeout,
                    functionName: UnsafeMutablePointer(mutating: cName),
                    functionPointer: ptr,
                    args: buffer.baseAddress,
                    argCount: UInt(args.count)
                ) ?? 0
            })
        }
    }
    #endif
}
