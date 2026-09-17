//
//  ContentView.swift
//  lara-wz
//
//  王者版只保留 Core 控制台作为应用入口。底层初始化、连接、功能配置
//  和游戏内悬浮窗均从同一状态源驱动，不再套用 lara 的通用首页。
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var mgr: laramgr

    init() {
        globallogger.capture()
    }

    var body: some View {
        WZControlPanelView(isPresented: .constant(true), allowsDismiss: false)
            .environmentObject(mgr)
    }
}

#Preview {
    ContentView()
        .environmentObject(laramgr())
}
