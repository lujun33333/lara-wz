//
//  lara.swift
//  lara
//
//  Created by ruter on 23.03.26.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

let g_isunsupported: Bool = isunsupported()
var weonadebugbuild_pjbweouttahereexclamationmark: Bool = false

@main
final class LaraAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        bootstrapLaraApplication()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = LaraSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }
}

@objc(LaraSceneDelegate)
final class LaraSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var rootViewController: UIHostingController<LaraRootView>?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let root = UIHostingController(rootView: LaraRootView())
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        rootViewController = root
        self.window = window
        globallogger.log(
            "(scene) UIKit single-scene host connected role=\(session.role.rawValue)"
        )
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        wzhud_scene_active_changed(true)
        globallogger.capture()
        IconThemeManager.shared.startPendingFixupIfPossible()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        wzhud_scene_active_changed(false)
        handleLaraBackgroundTransition()
        globallogger.stopcapture()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        wzhud_scene_active_changed(false)
        handleLaraBackgroundTransition()
        globallogger.stopcapture()
    }
}

struct LaraRootView: View {
    @StateObject private var mgr = laramgr.shared
    @StateObject private var iconthememgr = IconThemeManager.shared
    @AppStorage("logsdisplaymode") private var logsdisplaymode: logsdisplaymode = .toolbar

    var body: some View {
        ContentView()
        .environmentObject(mgr)
        .overlay {
            if mgr.showrespring {
                respringview()
                    .brightness(-1.0)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: Binding(
            get: { logsdisplaymode == .toolbar && mgr.showLogs },
            set: { mgr.showLogs = $0 }
        )) {
            LogsView(logger: globallogger)
        }
        .sheet(isPresented: $iconthememgr.showFixupSheet) {
            IconThemeFixupView()
        }
        .onAppear {
            if !isunsupported() {
                init_offsets()
                offsets_init()
                iconthememgr.startPendingFixupIfPossible()
                // beautiful name root
                // thanks
                mgr.hasOffsets = emergencyfixfunctiontobereplacedlateronquestionmark()
            } else {
                Alertinator.shared.alert(title: "此设备不受支持！", body: "很抱歉，此设备目前不受 Lara 支持。可能的原因：\n- 你所在的是不受支持的 iOS 版本（支持：iOS 16.0 - iOS 18.7.1、iOS 26.0 - iOS 26.0.1）\n- 你的设备带有 MIE（A19+ 或 M5+）\n- 有调试器已附加。", actionLabel: "退出应用", action: { exitinator() })
            }
        }
        .onChange(of: mgr.sbxready) { ready in
            if ready {
                iconthememgr.startPendingFixupIfPossible()
            }
        }
    }
}

private var laraBackgroundCleanupInFlight = false

private final class LaraBackgroundTaskBox {
    var identifier: UIBackgroundTaskIdentifier = .invalid

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}

private func bootstrapLaraApplication() {
    #if DEBUG
    weonadebugbuild_pjbweouttahereexclamationmark = true
    #endif

    // fix file picker
    let fixMethod = class_getInstanceMethod(
        UIDocumentPickerViewController.self,
        #selector(UIDocumentPickerViewController.fix_init(forOpeningContentTypes:asCopy:))
    )!
    let origMethod = class_getInstanceMethod(
        UIDocumentPickerViewController.self,
        #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:))
    )!
    method_exchangeImplementations(origMethod, fixMethod)

    if UserDefaults.standard.bool(forKey: "keepAlive") {
        toggleka()
    }
    globallogger.capture()
}

private func handleLaraBackgroundTransition() {
    let mgr = laramgr.shared
    guard mgr.rcready, !laraBackgroundCleanupInFlight else { return }
    // The independent HUD helper owns context registration; it does not use
    // Lara's SpringBoard RemoteCall and therefore does not pin that session.
    let keepSpringBoardRemoteCallAlive = UserDefaults.standard.bool(
        forKey: "keepSpringBoardRemoteCallAliveIOS16"
    )
    if isIOS16() && keepSpringBoardRemoteCallAlive { return }

    laraBackgroundCleanupInFlight = true
    let task = LaraBackgroundTaskBox()
    task.identifier = UIApplication.shared.beginBackgroundTask(withName: "RemoteCallCleanup") {
        DispatchQueue.main.async {
            task.end()
            laraBackgroundCleanupInFlight = false
        }
    }
    mgr.rcdestroy {
        DispatchQueue.main.async {
            task.end()
            laraBackgroundCleanupInFlight = false
        }
    }
}

// file picker fixes
extension UIDocumentPickerViewController {
    @objc func fix_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        return fix_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

// make strings compatiable with errors
extension String: @retroactive Error {}
