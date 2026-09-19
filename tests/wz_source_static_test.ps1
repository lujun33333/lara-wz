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

# AX architecture: two local source windows plus two SpringBoard CALayerHost
# mirrors. Local SBS registrations are independent best-effort operations.
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@interface WZHUDDrawWindow : UIWindow' '缺少 AX 绘制窗口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@interface WZHUDMenuWindow : UIWindow' '缺少 AX 菜单窗口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_drawHostingController' '缺少绘制窗口本地 controller'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_menuHostingController' '缺少菜单窗口本地 controller'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_windowContextIDs\[2\]' 'AX context 数量不是两个'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'SBSAccessibilityWindowHostingController' '缺少 AX 本地托管 controller'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'registerWindowWithContextID:atLevel:' '缺少本地 context 注册'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'unregisterWindowWithContextID:atLevel:' '缺少本地 context 注销'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'remote_getClass\(process, "SBMainWorkspace"\)' '缺少 AX SpringBoard workspace 链'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'remote_getClass\(process, "UIWindow"\)' '缺少 SpringBoard UIWindow'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'remote_getClass\(process, "CALayerHost"\)' '缺少 SpringBoard CALayerHost'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '"setWindowScene:"' 'SpringBoard 窗口未绑定主场景'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '"setContextId:"' 'CALayerHost 未绑定 Lara context ID'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '"addSublayer:"' 'CALayerHost 未加入 SpringBoard 窗口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'performSelectorOnMainThread:withObject:waitUntilDone:' '远程 UIKit 未按 AX 切到 SpringBoard 主线程'
Require-Text 'lara/kexploit/WZHUDBridge.h' 'wzhud_register_springboard_hosts\(RemoteCall \*remote_call\)' '桥接头未暴露 AX SpringBoard 托管入口'
Require-Text 'lara/kexploit/WZHUDBridge.h' 'wzhud_unregister_springboard_hosts\(RemoteCall \*remote_call\)' '桥接头未暴露 SpringBoard 托管清理入口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'bool wzhud_is_enabled\(void\)[\s\S]{0,500}g_active\.load\(\)[\s\S]{0,250}g_menuWindowReady\.load\(\)[\s\S]{0,350}g_windowContextIDs\[0\][\s\S]{0,120}g_windowContextIDs\[1\]' '本地双窗口 readiness 未绑定活动状态和两个 context'
Reject-Text 'lara/kexploit/WZHUDBridge.mm' 'posix_spawn|--wzhud-host|WZHUDFloatWindow|g_windowContextIDs\[3\]' '仍混入 helper 或 Core 三窗口结构'
Reject-Text 'lara/kexploit/WZHUDBridge.mm' 'wzhud_(create|remove|poll)_direct_springboard|wzhud_(start|stop)_context_host_helper' '仍暴露旧远端/helper 实现'
Reject-Text 'lara/kexploit/WZHUDBridge.mm' 'static void handle_scene_activity_main\(BOOL active\)[\s\S]{0,900}if \(!active\)[\s\S]{0,450}(destroy_hud_main|unregister_local_hosting_main|g_(window|menuWindow)\.hidden = YES)' '切到游戏后仍销毁、注销或隐藏 AX 双窗口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'void wzhud_update_wz_snapshot\([\s\S]{0,1200}!g_sceneActive\.load\(\)[\s\S]{0,300}g_backgroundSnapshotApplyPending\.compare_exchange_strong[\s\S]{0,700}dispatch_async\(dispatch_get_main_queue\(\)[\s\S]{0,700}render_frame_main\(CACurrentMediaTime\(\)\)' '后台快照发布未驱动合并后的主线程应用'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'static void render_frame_main\([\s\S]{0,1800}apply_wz_snapshot_main[\s\S]{0,1200}BOOL backgroundHosted = !g_sceneActive\.load\(\)[\s\S]{0,300}\[CATransaction flush\]' '后台帧未保持数据应用和 CA 提交'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'ax_enable_hosted_layer\(CALayer \*layer\)[\s\S]{0,350}setDisableUpdateMask:[\s\S]{0,200}0x12' '缺少 AX 已证实的后台图层掩码'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'BackBoardServices\.framework/BackBoardServices"[\s\S]{0,160}RTLD_NOW \| RTLD_GLOBAL[\s\S]{0,300}objc_getClass\([\s\S]{0,100}"SBSAccessibilityWindowHostingController"' '未按 AX 顺序先全局加载 BackBoardServices 再查询 hosting 类'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'kWZHUDWindowLevel = 10000009\.0' 'HUD 层级未对齐 AX 的 10000009/10000010'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_menuWindow = \[\[WZHUDMenuWindow alloc\] initWithFrame:initialSurface\];[\s\S]{0,100}g_window = \[\[WZHUDDrawWindow alloc\] initWithFrame:initialSurface\]' 'AX 本地窗口未按 menu/draw 顺序 scene-less 创建'
Reject-Text 'lara/kexploit/WZHUDBridge.mm' 'initWithWindowScene:|previousKeyWindow|\[.* makeKeyWindow\]' 'HUD 仍绑定 App scene 或恢复旧 key window'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '\[g_menuWindow makeKeyAndVisible\]' 'AX 菜单未 makeKeyAndVisible'
foreach ($window in @('WZHUDDrawWindow', 'WZHUDMenuWindow')) {
    Require-Text 'lara/kexploit/WZHUDBridge.mm' ("@implementation $window" + '[\s\S]{0,100}\+ \(BOOL\)_isSystemWindow \{ return YES; \}[\s\S]{0,100}_isSecure \{ return NO; \}[\s\S]{0,100}_canBecomeKeyWindow \{ return YES; \}[\s\S]{0,100}_isApplicationKeyWindow \{ return NO; \}[\s\S]{0,100}_isWindowServerHostingManaged \{ return NO; \}') 'AX 私有窗口身份不一致'
}
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@implementation WZHUDDrawWindow[\s\S]{0,500}_ignoresHitTest \{ return YES; \}' '绘制窗口未透传'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@implementation WZHUDMenuWindow[\s\S]{0,500}_ignoresHitTest \{ return NO; \}' '菜单窗口错误透传'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'for \(NSUInteger index : \{ 1u, 0u \}\)' 'context 未按菜单、绘制顺序获取'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'BOOL menuReady = register_local_hosting_controller\([\s\S]{0,250}BOOL drawReady = register_local_hosting_controller\(' '本地 draw 注册仍受 menu 返回值阻断'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'static BOOL unregister_local_hosting_controller\([\s\S]{0,500}@"unregisterWindowWithContextID:"[\s\S]{0,200}@"unregisterWindowWithContextID:atLevel:"' 'AX 注销 selector 优先级不一致'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'BOOL menuReady = runtimeReady && remote_host_context\([\s\S]{0,250}BOOL drawReady = menuReady && remote_host_context\(' '远端双 mirror 顺序不一致'
Require-Count 'lara/kexploit/WZHUDBridge.mm' '&zeroFrame, sizeof\(zeroFrame\), nullptr' 2 '远端 window/host frame 未全部采用 CGRectZero'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'if \(success\) \{\s*\*windowOut = window;\s*\*hostLayerOut = hostLayer;\s*\}' 'AX mirror 输出未限于成功出口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'if \(drawReady\)\s*\(void\)remote_unhost_context\(remoteCall, &runtime,\s*drawWindow, drawLayer\);\s*if \(menuReady\)\s*\(void\)remote_unhost_context\(remoteCall, &runtime,\s*menuWindow, menuLayer\);' 'mirror 失败未按 AX 仅清理成功对象'
Reject-Text 'lara/kexploit/WZHUDBridge.mm' 'if \(success \|\| drawWindow|Preserve any failed rollback handles' '仍保留 AX 没有的 partial-host 状态'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'BOOL drawRemoved = runtimeReady && remote_unhost_context\([\s\S]{0,150}drawWindow, drawLayer\);[\s\S]{0,150}BOOL menuRemoved = runtimeReady && remote_unhost_context\([\s\S]{0,150}menuWindow, menuLayer\)' '正常 mode-0 清理未按 draw、menu 顺序'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'if \(!active\)[\s\S]{0,500}configure_layer_renderer_main\(\)' '后台未配置 AX 托管图层'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'hosting=ready mode=system-window' 'AX 类不可用时缺少明确的 system-window 模式'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '_shouldCreateContextAsSecure \{ return NO; \}' 'Core system-window fallback 仍错误创建 secure context'

# AX failure callbacks report the error; only host success opens the game.
Require-Text 'lara/classes/laramgr.swift' 'func launchWZGame\(\)[\s\S]*setGameHUD\(true\)[\s\S]*prepareWZSpringBoardHosting \{[\s\S]{0,450}guard success else[\s\S]{0,200}openWZGame\(epoch: launchEpoch\)' '游戏启动未依照 AX 成功/失败分支'
Require-Text 'lara/classes/laramgr.swift' 'wzLaunchPending = true[\s\S]{0,180}initializeWZEnvironment\(\)' '首次启动未保留环境初始化后的续接请求'
Require-Text 'lara/classes/laramgr.swift' 'if self\.wzLaunchPending \{[\s\S]{0,100}self\.launchWZGame\(\)' '偏移初始化成功后未自动续接游戏启动'
Require-Text 'lara/classes/laramgr.swift' 'if ready \{ usleep\(1_200_000\) \}[\s\S]{0,100}DispatchQueue\.main\.async' 'AX host 成功后 worker 1.2s 延迟未同步'
Reject-Text 'lara/classes/laramgr.swift' 'prepareWZLocalHUDAndOpen|attempt < 30|正在注册 AX 本地双窗口' '游戏启动仍保留 HUD 等待门禁'
Require-Text 'lara/classes/laramgr.swift' 'let removed = wzhud_unregister_springboard_hosts\(remoteProcess\)[\s\S]{0,300}let ready = wzhud_register_springboard_hosts' 'host 未按 mode0 再 mode1 重建'
Reject-Text 'lara/classes/laramgr.swift' 'removed &&' 'mode0 返回值仍错误阻断 mode1 或失败清理'
Require-Text 'lara/classes/laramgr.swift' 'let installFailed = !ready[\s\S]{0,100}if installFailed \{ remoteProcess\.destroy\(\) \}' 'AX mode1 失败后未在 worker 销毁 RemoteCall'
Require-Text 'lara/classes/laramgr.swift' 'if installFailed, self\.sbProc === remoteProcess[\s\S]{0,100}self\.sbProc = nil[\s\S]{0,80}self\.rcready = false' 'mode1 失败未按对象身份清除对应会话'
Require-Text 'lara/classes/laramgr.swift' 'wzhud_register_springboard_hosts\(remoteProcess\)' 'Swift 未调用 AX SpringBoard 托管链'
Require-Text 'lara/classes/laramgr.swift' 'opening com.tencent.smoba[\s\S]*wzhud_open_smoba_application\(\)[\s\S]*open callback opened=' 'bundle ID 启动缺少结果诊断'
Reject-Text 'lara/classes/laramgr.swift' 'private func openWZGame\(epoch: UInt64\)[\s\S]{0,240}DispatchQueue\.main\.async' 'LS 启动成功块被额外投递了一次主队列'
Reject-Text 'lara/classes/laramgr.swift' 'smoba1104466820|openWZGameURL' '仍保留非 AX URL 启动'
Require-Text 'lara/classes/laramgr.swift' 'func setGameHUD\(_ enabled: Bool\)[\s\S]{0,1500}let requested = wzhud_set_enabled\(true\)' 'HUD 创建未收敛到 wzhud_set_enabled'
Require-Count 'lara/classes/laramgr.swift' 'wzhud_set_enabled\(true\)' 1 'HUD 创建入口不唯一'
Reject-Text 'lara/classes/laramgr.swift' 'wzGameHUD(Position|LargeFont|SingleLine|Inverted)|showWZControlPanel|cycleWZColor|resetWZFeatureState|wzhud_set_wz_config' 'Swift 仍保留 CORE 面板状态或覆盖 AX 配置'
Require-Text 'lara/classes/laramgr.swift' 'wzhud_copy_wz_config\(&config\)' '采集未直接读取 AX 菜单配置'
Require-Text 'lara/kexploit/wzesp.h' 'float skillSize;' '配置缺少独立 AX 技能大小字段'
Require-Text 'lara/classes/laramgr.swift' 'private func hideGameHUD\([\s\S]{0,400}rcdestroy' 'HUD 停止未统一走 mode0/RC/context 清理'
Reject-Text 'lara/classes/laramgr.swift' 'wzhud_(start|stop)_context_host_helper|wzhud_prepare_game_launch' 'Swift 启动链仍调用旧 helper/Core 门禁'
Reject-Text 'lara/lara.swift' 'handleLaraBackgroundTransition\([\s\S]{0,1000}wzhud_set_enabled\(false\)' 'App 退后台仍销毁 AX HUD'
Reject-Text 'lara/lara.swift' 'handleLaraBackgroundTransition|RemoteCallCleanup' '普通前后台仍销毁 RemoteCall'
Require-Text 'lara/lara.swift' 'didFinishLaunchingWithOptions[\s\S]{0,150}startBackgroundAudio\(\)' '启动音频晚于窗口生命周期'
Require-Text 'lara/classes/laramgr.swift' 'numberOfLoops = -1[\s\S]{0,80}volume = 0\.08' 'AX 音频循环/音量不一致'
Require-Text 'lara/classes/laramgr.swift' 'beginBackgroundTask\(withName: "AXHUDKeepAlive"' '缺少 AX background task'
Require-Text 'lara/classes/laramgr.swift' 'guard audioObservers\.isEmpty[\s\S]{0,250}AVAudioSession\.interruptionNotification' '音频观察者重复或遗漏中断通知'
Require-Text 'lara/classes/laramgr.swift' 'AVAudioSession\.mediaServicesWereResetNotification[\s\S]{0,250}audioPlayer = nil[\s\S]{0,80}recoverBackgroundAudio' '媒体服务重置未重建播放器'
Require-Text 'lara/classes/laramgr.swift' 'reason == 1 \|\| reason == 2 \|\| reason == 4' 'route change 原因未按 AX 筛选'
Require-Text 'lara/classes/laramgr.swift' 'for delay in \[0\.0, 0\.2, 0\.5, 1\.0, 2\.0, 4\.0, 8\.0, 16\.0\]' 'AX 音频恢复时序不一致'
Require-Text 'lara/classes/laramgr.swift' 'audioRecoveryEpoch == epoch[\s\S]{0,200}endAudioBackgroundTask\(\)' '恢复成功未取消旧代恢复并结束后台任务'
Require-Text 'lara/classes/laramgr.swift' 'func stopBackgroundAudio[\s\S]{0,400}removeObserver[\s\S]{0,200}audioWatchdog\?\.cancel' '音频终止未注销通知和watchdog'
Require-Text 'lara/kexploit/TaskRop/RemoteCall.m' 'return version\.majorVersion == 16;' 'AX exact iOS16 分支未同步'
Reject-Text 'lara/kexploit/TaskRop/RemoteCall.m' 'return version\.majorVersion >= 16;' 'iOS17/26 仍误走 iOS16 分支'
Require-Text 'lara/classes/laramgr.swift' 'func rcdestroy[\s\S]{0,1000}let removed = wzhud_unregister_springboard_hosts\(remoteProcess\)\s+remoteProcess\?\.destroy\(\)' 'AX mode0 后仍未按顺序无条件拆RC'
Reject-Text 'lara/classes/laramgr.swift' 'retained local contexts|RemoteCall and contexts retained|远程调用会话已保留' '仍残留非 AX 失败保留策略'
Reject-Text 'lara/classes/laramgr.swift' 'Date\(timeIntervalSinceNow: 2\)|deadline: \.now\(\) \+ 0\.5|termination cleanup did not finish before callback deadline' '仍残留无 AX 依据的终止期限/host 轮询'
Require-Text 'lara/classes/laramgr.swift' 'wzHostingRequests\.append[\s\S]{0,150}prepareWZSpringBoardHosting' 'host 忙时未接入完成事件'
Require-Text 'lara/classes/laramgr.swift' 'guard self\.wzGameHUDSessionArmed, let remoteProcess = self\.sbProc else[\s\S]{0,650}self\.sbProc = nil[\s\S]{0,140}self\.wzWorker\.async[\s\S]{0,100}abandonedProcess\.destroy\(\)[\s\S]{0,180}wzSpringBoardInstallRunning = false' 'RC 初始化与 HUD 取消竞态未在恢复请求前清理废弃会话'
Require-Text 'lara/classes/laramgr.swift' 'func terminateWZSession[\s\S]{0,1000}while !finished[\s\S]{0,60}CFRunLoopRun\(\)' '终止未等待远端队列完成'

# AX pages and the retained collector draw-item interface.
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'item\.primitive == WZESP_PRIMITIVE_MONSTER_POINT' '野怪点位绘制断开'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'item\.primitive == WZESP_PRIMITIVE_SOLDIER_POINT' '兵线点位绘制断开'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_wzPortraitRecallRings' '回城动态绘制断开'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'item\.auxiliaryCooldownSeconds' '辅助技能冷却未进入绘制层'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'heroimg/%d/%d\.jpg' 'AX 英雄头像加载链未接入'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'summoner/%d\.jpg' 'AX 召唤师图标加载链未接入'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@"大地图头像"' 'AX 大地图头像功能缺失'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@"小地图野怪"' 'AX 小地图野怪功能缺失'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@"召唤师技能"' 'AX 召唤师技能功能缺失'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@"地图位置"' 'AX 地图位置功能缺失'
Reject-Text 'lara/kexploit/WZHUDBridge.mm' '@"CORE\.|S M O B A|wzCore|rebuild_core_page|update_fallback_snapshot|present_snapshot_metal|wzhud_set_presentation' '仍残留 CORE UI 或截图渲染实现'
Reject-Text 'lara/kexploit/WZHUDBridge.mm' '描边增强（写入）|目标追踪（写入）|自动瞄准（写入）' '菜单仍混入写入功能'

# One executable, no helper source and no spawn/direct-remote path.
$helper = Join-Path $root 'scripts/WZHUDHostHelper.m'
if (Test-Path -LiteralPath $helper) { throw 'FAIL: 已删除的 WZHUDHostHelper.m 仍存在' }
Reject-Text 'lara.xcodeproj/project.pbxproj' 'WZHUDHostHelper' 'Xcode 工程仍引用旧 helper'
Reject-Text 'scripts/build_ipa_wz.sh' 'WZHUDHostHelper\.m|WZHUDHostHelper\.o|posix_spawn\s*\(' '构建脚本仍编译 helper 或调用 spawn'
Require-Text 'scripts/build_ipa_wz.sh' 'WZHUDDrawWindow[\s\S]*WZHUDMenuWindow[\s\S]*SBMainWorkspace[\s\S]*CALayerHost[\s\S]*SBSAccessibilityWindowHostingController' '构建未验证 AX 双窗口与 SpringBoard CALayerHost'
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

Require-Text 'lara/kexploit/WZHUDBridge.mm' 'game\.gtimg\.cn/images/yxzj/img201606/heroimg/%d/%d\.jpg' 'AX 英雄头像地址未接入'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'game\.gtimg\.cn/images/yxzj/img201606/summoner/%d\.jpg' 'AX 召唤师技能头像地址未接入'
if (Test-Path -LiteralPath (Join-Path $root 'lara/heroatlas.bin')) {
    throw 'FAIL: 已删除的旧英雄图集仍在产品资源中'
}

Write-Output 'PASS: WZ AX two-window static contracts present; build and device behavior remain unverified'
