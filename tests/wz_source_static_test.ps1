$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Require-Text([string]$Path, [string]$Pattern, [string]$Message) {
    $content = Get-Content -LiteralPath (Join-Path $root $Path) -Raw
    if ($content -notmatch $Pattern) {
        throw "FAIL: $Message ($Path)"
    }
}

Require-Text 'lara/kexploit/wzmem.h' 'WZ_CAP_READ' '缺少统一读取 capability'
Require-Text 'lara/kexploit/wzmem.h' 'WZ_CAP_WRITE' '缺少统一写入 capability'
Require-Text 'lara/kexploit/wzmem.m' 'wz_try_mach_connect\(name, generation\).*return true' 'Mach task 未作为首选传输'
Require-Text 'lara/kexploit/wzmem.m' 'task_read_for_pid' '缺少只读 task port 获取回退'
Require-Text 'lara/kexploit/wzmem.m' 'processor_set_tasks' '缺少 Core processor-set task port 回退'
Require-Text 'lara/kexploit/wzmem.m' 'task_threads\(' '缺少 Core task 线程只读探测'
Require-Text 'lara/kexploit/wzmem.m' 'mach_port_deallocate\(mach_task_self\(\), threads\[index\]\)' '线程端口未逐个释放'
Require-Text 'lara/kexploit/wzmem.m' 'wz_try_mach_connect_pid\(name, pid, proc, generation\)' '未使用内核确认的 PID 重试 Mach 传输'
Require-Text 'lara/kexploit/wzmem.m' 'mach_port_deallocate\(mach_task_self\(\), machTask\)' '断开未释放 task port'
Require-Text 'lara/kexploit/wzmem.m' 'region walk 后目标身份失效' 'Mach region walk 后未复核目标身份'
Require-Text 'lara/kexploit/wzmem.m' 'writing \? WZ_CAP_WRITE : WZ_CAP_READ' '读写未按 capability 门禁'
Require-Text 'lara/kexploit/wzmem.m' 'wzmem_read_chunks' 'Mach 读取未使用部分完成契约'
Require-Text 'lara/kexploit/wzmem.m' 'wz_mcache_open\(256\)' '外读采集仍使用单页抖动缓存'
Require-Text 'lara/kexploit/TaskRop/vm.m' 'object->entryOffset \+ PAGE_SIZE' 'mapped-pages 仍按整个 Unity vm_object 创建 named entry'
Require-Text 'lara/kexploit/TaskRop/vm.m' 'entry\.vme_offset = object->objectOffset;' 'mapped-pages 偏移语义偏离已验证 DarkSword 路径'
Require-Text 'lara/kexploit/wzmem.m' 'extern kern_return_t mach_vm_read_overwrite' 'iOS SDK 缺少 Mach 读取声明兜底'
Require-Text 'lara/kexploit/wzmem.m' 'extern kern_return_t mach_vm_region_recurse' 'iOS SDK 缺少 Mach region 声明兜底'
Require-Text 'lara/kexploit/wzmem.m' 'magic == MH_MAGIC_64' '内核 Mach-O 魔数自检被改名污染'
Require-Text 'lara/classes/laramgr.swift' 'let canWrite = false' 'WZ 未保持版本级写权限 fail-closed'
Require-Text 'lara/classes/laramgr.swift' '@Published var wzShowAvatar: Bool = true' 'Core 默认绘制开关被 Swift 状态覆盖'
Require-Text 'lara/classes/laramgr.swift' 'wzhud_set_transport_state' '连接状态未传给控制面板'
Require-Text 'lara/classes/laramgr.swift' 'func prepareWZEnvironment\(' 'Core 初始化页未接完整环境准备链'
Require-Text 'lara/classes/laramgr.swift' 'func wzCollectorPagesReadable\(' '连接成功前未验证王者关键采集页'
Require-Text 'lara/classes/laramgr.swift' 'imageValid && profileReadable' '采集页失败仍可能伪装连接成功'
Require-Text 'lara/classes/laramgr.swift' 'wzGameHUDSessionArmed = true[\s\S]*wzhud_set_enabled\(true\)' '连接成功后未自动启动游戏内 HUD'
Require-Text 'lara/classes/laramgr.swift' 'Core creates its system windows while the controller app is[\s\S]*let requested = wzhud_set_enabled\(true\)' 'HUD 仍在切到游戏后才创建窗口'
Require-Text 'lara/kexploit/wzesp.h' 'WZESP_SHOW_MAP_ADJUSTMENT' '缺少独立地图调节显示开关'
Require-Text 'lara/kexploit/wzesp.h' 'WZESP_SHOW_SKILL' '缺少技能页读取开关'
Require-Text 'lara/kexploit/wz/YuanbaoCollector.mm' '_logicVisible=0x505, _meshVisible=0x506, _inCamera=0x507' '缺少王者只读视野字段链'
Require-Text 'lara/kexploit/wz/YuanbaoCollector.mm' 'header\.camp != host\.camp' '英雄敌我分类未接 camp'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'item\.primitive == WZESP_PRIMITIVE_MONSTER_POINT' '野怪点位和实体未独立过滤'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'item\.primitive == WZESP_PRIMITIVE_SOLDIER_POINT' '兵线点位和实体未独立过滤'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_wzPortraitRecallRings' '回城动态光环未接入'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'monster_marker_color\(item\.monsterSubtype\)' '野怪分类样式未接入'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '10000 \+ \(NSInteger\)__builtin_ctz\(flag\)' 'HUD 高位开关仍可能与滑块 tag 冲突'
Require-Text 'lara/kexploit/wz/WZYuanbaoDrawPolicy.h' 'kRecallSpinRadiansPerSecond = 7\.854f' '未同步元宝回城旋转参数'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_wzSnapshotGeneration' '并发断开可能吞掉最后清空帧'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'preferredFramesPerSecond = 60' '游戏绘制未接 Core 2.2 的 60 FPS 帧驱动'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'WZESP_SHOW_AVATAR \| WZESP_SHOW_HEALTH \| WZESP_SHOW_RECALL' 'Core 默认绘制开关未同步'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'WZHUDMetalCanvas' '游戏画布未按 Core QXA110 使用独立 UIView 宿主'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'NSClassFromString\(@"CAMetalLayer"\)' '游戏画布未按 Core QXA110 使用 CAMetalLayer'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_directInteractionEnabled = !gestureReady' 'HID 失败时没有本地交互回退'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'directControlGesture:' '控制台动态开关没有直接触摸入口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'IOHIDEventSystemClientCreate' '全局触摸未以 Core IOHID client 为首选'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'IOHIDEventSystemClientRegisterEventCallback' '全局触摸未注册 Core IOHID 回调'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'IOHIDEventSystemClientScheduleWithRunLoop' 'Core IOHID client 未调度到主运行循环'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_wzSkillPortraits' '技能冷却仍未使用固定英雄栏'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'item\.auxiliaryCooldownSeconds' '辅助技能冷却未进入绘制层'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'URLForResource:@"heroatlas"' 'HUD 未接入王者英雄头像图集'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'error=%s' 'HUD 创建失败没有输出可诊断日志'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@interface WZHUDDrawWindow : UIWindow' '缺少 Core 绘制系统窗口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '@interface WZHUDControlWindow : UIWindow' '缺少 Core 控制系统窗口'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'canBecomeKeyWindow \{ return NO; \}' 'HUD 窗口未同步 Core 非 key-window 语义'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '_isSystemWindow \{ return YES; \}' 'HUD 窗口未同步 Core system-window 语义'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '_isWindowServerHostingManaged \{ return NO; \}' 'HUD 窗口未同步 Core hosting 语义'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '_shouldCreateContextAsSecure \{ return NO; \}' 'HUD 窗口未同步 Core context 语义'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '_ignoresHitTest \{ return YES; \}' 'Core 绘制窗口未保持穿透'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '_ignoresHitTest \{ return NO; \}' 'Core 控制窗口未保持交互'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'UISceneActivationStateForegroundActive' 'HUD 未绑定前台活动场景'
$hudSource = Get-Content -LiteralPath (Join-Path $root 'lara/kexploit/WZHUDBridge.mm') -Raw
if ($hudSource -match 'SBSAccessibilityWindowHostingController') {
    throw 'FAIL: HUD 仍把非 Core 的 SBS 托管链混入主窗口路径'
}
Require-Text 'lara/views/app/WZControlPanelView.swift' 'Text\("CORE"\)' '缺少 Core 原版标题'
Require-Text 'lara/views/app/WZControlPanelView.swift' '@State private var page: WZCorePage = \.home' '游戏控制台首屏未落到主页'
Require-Text 'lara/views/app/WZControlPanelView.swift' '显示头像' '缺少英雄页功能'
Require-Text 'lara/views/app/WZControlPanelView.swift' '显示野怪计时' '缺少兵野页功能'
Require-Text 'lara/views/app/WZControlPanelView.swift' '显示英雄技能冷却' '缺少技能页功能'
Require-Text 'lara/views/app/WZControlPanelView.swift' 'featureRow\("显示小地图"' '缺少独立小地图开关'
Require-Text 'lara/views/app/WZControlPanelView.swift' 'featureRow\("地图调节显示"' '缺少地图调节显示开关'
Require-Text 'lara/views/app/WZControlPanelView.swift' '地图坐标Y' '缺少调整页功能'
Require-Text 'lara/views/app/WZControlPanelView.swift' '只读锁定' '缺少只读状态提示'
Require-Text 'lara/views/app/WZControlPanelView.swift' 'writeFeatureRow\("自动瞄准"\)' '写入功能门禁未呈现在控制台'
Require-Text 'lara/views/app/WZControlPanelView.swift' 'wzMeasuredFPS' '控制台仍显示硬编码帧率'
Require-Text 'lara/views/app/ContentView.swift' 'Image\("core-mountain"\)' '应用首屏未接 Core 山景卡片'
Require-Text 'lara/views/app/ContentView.swift' '关闭菜单' '应用首屏未同步 Core 环形入口'
Require-Text 'lara/views/app/ContentView.swift' 'mgr\.launchWZGame\(\)' '启动游戏入口未接王者启动链'
Require-Text 'lara/views/app/ContentView.swift' 'WZControlPanelView\(' '应用首屏没有控制台导航入口'
if ((Get-Content -LiteralPath (Join-Path $root 'lara/views/app/ContentView.swift') -Raw) -match 'fullScreenCover') {
    throw 'FAIL: Core 控制台仍通过不透明 fullScreenCover 打开'
}
Require-Text 'lara/classes/laramgr.swift' 'func openWZControlPanel\(' '控制台入口未接初始化状态机'
Require-Text 'lara/classes/laramgr.swift' 'requestGeometryUpdate' 'Core 控制台未主动请求横屏 geometry'
Require-Text '.github/workflows/build.yml' 'scripts/build_ipa_wz\.sh' 'CI 仍未使用王者构建入口'
Require-Text 'scripts/build_ipa_wz.sh' 'PlistBuddy.*LARABuildSourceCommit' '构建产物未写入源码提交标识'

$appSource = Get-Content -LiteralPath (Join-Path $root 'lara/lara.swift') -Raw
if ($appSource -match 'TabView\s*\(') {
    throw 'FAIL: 应用入口仍保留旧 TabView 外壳'
}

$atlas = Join-Path $root 'lara/heroatlas.bin'
if (-not (Test-Path -LiteralPath $atlas) -or (Get-Item -LiteralPath $atlas).Length -ne 2164890) {
    throw 'FAIL: 王者英雄头像图集缺失或长度不符'
}
$atlasHash = (Get-FileHash -LiteralPath $atlas -Algorithm SHA256).Hash
if ($atlasHash -ne '32061154E6545F5372C567BD0598AFBAE815E18EAA80B1F4247C218FB3FB913E') {
    throw 'FAIL: 王者英雄头像图集哈希不符'
}

$launcher = Join-Path $root 'lara/core-mountain.png'
if (-not (Test-Path -LiteralPath $launcher) -or (Get-Item -LiteralPath $launcher).Length -lt 500000) {
    throw 'FAIL: Core 启动页山景资产缺失或无效'
}

Write-Output 'PASS: WZ/Core static contracts present; build and device parity remain unverified'
