$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Require-Text([string]$Path, [string]$Pattern, [string]$Message) {
    $content = Get-Content -LiteralPath (Join-Path $root $Path) -Raw
    if ($content -notmatch $Pattern) { throw "FAIL: $Message ($Path)" }
}

function Reject-Text([string]$Path, [string]$Pattern, [string]$Message) {
    $content = Get-Content -LiteralPath (Join-Path $root $Path) -Raw
    if ($content -match $Pattern) { throw "FAIL: $Message ($Path)" }
}

function Require-Count([string]$Path, [string]$Pattern, [int]$Count, [string]$Message) {
    $content = Get-Content -LiteralPath (Join-Path $root $Path) -Raw
    $actual = [regex]::Matches($content, $Pattern).Count
    if ($actual -ne $Count) {
        throw "FAIL: $Message expected=$Count actual=$actual ($Path)"
    }
}

# Read-only transport and current-game profile contracts.
Require-Text 'lara/kexploit/wzmem.h' 'WZ_CAP_READ' '缺少统一读取 capability'
Require-Text 'lara/kexploit/wzmem.h' 'WZ_CAP_WRITE' '缺少统一写入 capability'
Require-Text 'lara/kexploit/wzmem.m' 'task_read_for_pid' '缺少只读 task port 获取回退'
Require-Text 'lara/kexploit/wzmem.m' 'processor_set_tasks' '缺少 processor-set task port 回退'
Require-Text 'lara/kexploit/wzmem.m' 'mach_port_deallocate\(mach_task_self\(\), machTask\)' '断开未释放 task port'
Require-Text 'lara/kexploit/wzmem.m' 'writing \? WZ_CAP_WRITE : WZ_CAP_READ' '读写未按 capability 门禁'
Require-Text 'lara/kexploit/wzmem.m' 'wzmem_read_chunks' 'Mach 读取未使用部分完成契约'
Require-Text 'lara/kexploit/wzmem.m' 'wz_mcache_open\(256\)' '外读采集仍使用单页缓存'
Require-Text 'lara/classes/laramgr.swift' 'let canWrite = false' 'WZ 未保持版本级写权限 fail-closed'
Require-Text 'lara/classes/laramgr.swift' 'wzesp_tick' '王者只读采集未接入 worker'
Require-Text 'lara/classes/laramgr.swift' 'wz_find_image_base' '未按 UUID 定位 UnityFramework'
Require-Text 'lara/kexploit/wz/YuanbaoCollector.mm' 'header\.camp != host\.camp' '英雄敌我分类未接 camp'
Require-Text 'lara/kexploit/wzesp.h' 'WZESP_SHOW_MAP_ADJUSTMENT' '缺少地图调节开关'
Require-Text 'lara/kexploit/wzesp.h' 'WZESP_SHOW_SKILL' '缺少技能读取开关'

# AX architecture: two local windows and two controller registrations in Lara.
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@interface WZHUDDrawWindow : UIWindow' '缺少 AX 绘制窗口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@interface WZHUDMenuWindow : UIWindow' '缺少 AX 菜单窗口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_drawHostingController' '缺少绘制窗口本地 controller'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_menuHostingController' '缺少菜单窗口本地 controller'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_windowContextIDs\[2\]' 'AX context 数量不是两个'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'SBSAccessibilityWindowHostingController' '缺少 AX 本地托管 controller'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'registerWindowWithContextID:atLevel:' '缺少本地 context 注册'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'unregisterWindowWithContextID:atLevel:' '缺少本地 context 注销'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'bool wzhud_is_enabled\(void\)[\s\S]{0,700}g_localHostingReady\.load\(\)[\s\S]{0,400}g_drawHostingController[\s\S]{0,400}g_menuHostingController[\s\S]{0,500}g_hostedContextIDs\[0\]\.load\(\)[\s\S]{0,300}g_hostedContextIDs\[1\]\.load\(\)' 'readiness 未绑定两个本地 controller/context'
Reject-Text 'lara/kexploit/WZHUDBridge.mm' 'posix_spawn|--wzhud-host|direct_remote_|WZHUDFloatWindow|g_windowContextIDs\[3\]' '仍混入 helper、远端调用或 Core 三窗口结构'
Reject-Text 'lara/kexploit/WZHUDBridge.mm' 'wzhud_(create|remove|poll)_direct_springboard|wzhud_(start|stop)_context_host_helper' '仍暴露旧远端/helper 实现'
Reject-Text 'lara/kexploit/WZHUDBridge.h' 'RemoteCall|direct_springboard|context_host_helper|springboard_hosting' '桥接头仍暴露旧 HUD 架构'
Reject-Text 'lara/kexploit/WZHUDBridge.mm' 'static void handle_scene_activity_main\(BOOL active\)[\s\S]{0,900}if \(!active\)[\s\S]{0,450}(destroy_hud_main|unregister_local_hosting_main|g_(window|menuWindow)\.hidden = YES)' '切到游戏后仍销毁、注销或隐藏 AX 双窗口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'void wzhud_update_wz_snapshot\([\s\S]{0,1200}!g_sceneActive\.load\(\)[\s\S]{0,300}g_backgroundSnapshotApplyPending\.compare_exchange_strong[\s\S]{0,700}dispatch_async\(dispatch_get_main_queue\(\)[\s\S]{0,700}render_frame_main\(CACurrentMediaTime\(\)\)' '后台快照发布未驱动合并后的主线程应用'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'static void render_frame_main\([\s\S]{0,1800}apply_wz_snapshot_main[\s\S]{0,1200}BOOL backgroundHosted = !g_sceneActive\.load\(\)[\s\S]{0,250}g_localHostingReady\.load\(\)[\s\S]{0,300}\[CATransaction flush\]' '后台帧未保持数据应用和 CA 提交'

# Launch only after wzhud_set_enabled has published both local controllers.
Require-Text 'lara/classes/laramgr.swift' 'func launchWZGame\(\)[\s\S]*setGameHUD\(true\)[\s\S]*prepareWZLocalHUDAndOpen\(url: url, epoch: launchEpoch, attempt: 0\)' '游戏启动未进入 AX 双窗口确认链'
Require-Text 'lara/classes/laramgr.swift' 'private func prepareWZLocalHUDAndOpen\([\s\S]*if wzhud_is_enabled\(\)[\s\S]*openWZGameURL\(url, epoch: epoch\)[\s\S]*attempt < 30[\s\S]*milliseconds\(50\)' '游戏 URL 未等待两个本地 controller 完成注册'
Require-Text 'lara/classes/laramgr.swift' 'func setGameHUD\(_ enabled: Bool\)[\s\S]{0,1500}let requested = wzhud_set_enabled\(true\)' 'HUD 创建未收敛到 wzhud_set_enabled'
Require-Count 'lara/classes/laramgr.swift' 'wzhud_set_enabled\(true\)' 1 'HUD 创建入口不唯一'
Require-Text 'lara/classes/laramgr.swift' 'private func hideGameHUD\([\s\S]{0,500}wzhud_set_enabled\(false\)' 'HUD 停止未直接走 wzhud_set_enabled(false)'
Reject-Text 'lara/classes/laramgr.swift' 'wzhud_(start|stop)_context_host_helper|wzhud_springboard_hosting_ready|wzhud_prepare_game_launch' 'Swift 启动链仍调用旧 helper/Core 门禁'
Reject-Text 'lara/classes/laramgr.swift' 'wzHosting(InFlight|ShutdownInFlight)' 'Swift 状态仍保留 helper 生命周期'
Reject-Text 'lara/lara.swift' 'handleLaraBackgroundTransition\([\s\S]{0,1000}wzhud_set_enabled\(false\)' 'App 退后台仍销毁 AX HUD'

# Full menu and draw data remain wired after replacing only hosting.
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'item\.primitive == WZESP_PRIMITIVE_MONSTER_POINT' '野怪点位绘制断开'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'item\.primitive == WZESP_PRIMITIVE_SOLDIER_POINT' '兵线点位绘制断开'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_wzPortraitRecallRings' '回城动态绘制断开'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'item\.auxiliaryCooldownSeconds' '辅助技能冷却未进入绘制层'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'URLForResource:@"heroatlas"' '头像图集未接入'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@"显示头像"' '英雄页功能缺失'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@"显示野怪计时"' '兵野页功能缺失'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@"显示英雄技能冷却"' '技能页功能缺失'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@"地图调节显示"' '地图调节功能缺失'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@"只读锁定"' '只读状态提示缺失'
Reject-Text 'lara/kexploit/WZHUDBridge.mm' '描边增强（写入）|目标追踪（写入）|自动瞄准（写入）' '菜单仍混入写入功能'

# One executable, no helper source and no spawn/direct-remote path.
$helper = Join-Path $root 'scripts/WZHUDHostHelper.m'
if (Test-Path -LiteralPath $helper) { throw 'FAIL: 已删除的 WZHUDHostHelper.m 仍存在' }
Reject-Text 'lara.xcodeproj/project.pbxproj' 'WZHUDHostHelper' 'Xcode 工程仍引用旧 helper'
Reject-Text 'scripts/build_ipa_wz.sh' 'WZHUDHostHelper\.m|WZHUDHostHelper\.o|posix_spawn\s*\(' '构建脚本仍编译 helper 或调用 spawn'
Require-Text 'scripts/build_ipa_wz.sh' 'WZHUDDrawWindow[\s\S]*WZHUDMenuWindow[\s\S]*SBSAccessibilityWindowHostingController' '构建未验证 AX 双窗口'
Require-Text 'scripts/build_ipa_wz.sh' 'PlistBuddy.*LARABuildSourceCommit' '构建产物未写入源码提交标识'
Require-Text 'Config/lara.entitlements' 'com\.apple\.QuartzCore\.displayable-context' '最终签名缺少可显示 context 权限'
Require-Text 'Config/lara.entitlements' 'com\.apple\.springboard\.accessibility-window-hosting' '最终签名缺少 AX 托管权限'

# Explicit single-scene UIKit host and background audio contract.
Require-Text 'lara/lara.swift' '@main[\s\S]*final class LaraAppDelegate: UIResponder, UIApplicationDelegate' '缺少 UIKit AppDelegate 入口'
Require-Text 'lara/lara.swift' '@objc\(LaraSceneDelegate\)[\s\S]*UIWindowSceneDelegate' '缺少显式 SceneDelegate'
Require-Text 'lara/lara.swift' 'UIWindow\(windowScene: windowScene\)' 'SceneDelegate 未创建主窗口'
Require-Text 'lara/Info.plist' '<string>audio</string>' '应用未保留后台音频模式'
Require-Text 'lara/Info.plist' '<key>UIApplicationSupportsMultipleScenes</key>[\s\S]*<false/>' '应用未保持单场景模式'
Require-Text 'lara/views/app/ContentView.swift' 'mgr\.launchWZGame\(\)' '启动入口未接王者启动链'
Reject-Text 'lara/views/app/ContentView.swift' 'WZControlPanelView\(' '应用仍叠加 SwiftUI 控制台副本'

$atlas = Join-Path $root 'lara/heroatlas.bin'
if (-not (Test-Path -LiteralPath $atlas) -or (Get-Item -LiteralPath $atlas).Length -ne 2164890) {
    throw 'FAIL: 王者英雄头像图集缺失或长度不符'
}

Write-Output 'PASS: WZ AX two-window static contracts present; build and device behavior remain unverified'
