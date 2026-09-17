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
Require-Text 'lara/kexploit/wzmem.m' 'mach_port_deallocate\(mach_task_self\(\), machTask\)' '断开未释放 task port'
Require-Text 'lara/kexploit/wzmem.m' 'region walk 后目标身份失效' 'Mach region walk 后未复核目标身份'
Require-Text 'lara/kexploit/wzmem.m' 'writing \? WZ_CAP_WRITE : WZ_CAP_READ' '读写未按 capability 门禁'
Require-Text 'lara/kexploit/wzmem.m' 'wzmem_read_chunks' 'Mach 读取未使用部分完成契约'
Require-Text 'lara/kexploit/wzmem.m' 'extern kern_return_t mach_vm_read_overwrite' 'iOS SDK 缺少 Mach 读取声明兜底'
Require-Text 'lara/kexploit/wzmem.m' 'magic == MH_MAGIC_64' '内核 Mach-O 魔数自检被改名污染'
Require-Text 'lara/classes/laramgr.swift' 'let canWrite = false' 'WZ 未保持版本级写权限 fail-closed'
Require-Text 'lara/classes/laramgr.swift' 'wzhud_set_transport_state' '连接状态未传给控制面板'
Require-Text 'lara/kexploit/wzesp.h' 'WZESP_SHOW_MAP_ADJUSTMENT' '缺少独立地图调节显示开关'
Require-Text 'lara/kexploit/wz/YuanbaoCollector.mm' '_logicVisible=0x505, _meshVisible=0x506, _inCamera=0x507' '缺少王者只读视野字段链'
Require-Text 'lara/kexploit/wz/YuanbaoCollector.mm' 'header\.camp != host\.camp' '英雄敌我分类未接 camp'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'item\.primitive == WZESP_PRIMITIVE_MONSTER_POINT' '野怪点位和实体未独立过滤'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'item\.primitive == WZESP_PRIMITIVE_SOLDIER_POINT' '兵线点位和实体未独立过滤'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_wzPortraitRecallRings' '回城动态光环未接入'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'monster_marker_color\(item\.monsterSubtype\)' '野怪分类样式未接入'
Require-Text 'lara/kexploit/WZHUDBridge.mm' '10000 \+ \(NSInteger\)__builtin_ctz\(flag\)' 'HUD 高位开关仍可能与滑块 tag 冲突'
Require-Text 'lara/kexploit/wz/WZYuanbaoDrawPolicy.h' 'kRecallSpinRadiansPerSecond = 7\.854f' '未同步元宝回城旋转参数'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'g_wzSnapshotGeneration' '并发断开可能吞掉最后清空帧'
Require-Text 'lara/kexploit/WZHUDBridge.mm' 'URLForResource:@"heroatlas"' 'HUD 未接入王者英雄头像图集'
Require-Text 'lara/views/app/WZControlPanelView.swift' 'Text\("CORE"\)' '缺少 Core 标题'
Require-Text 'lara/views/app/WZControlPanelView.swift' '显示头像' '缺少英雄页功能'
Require-Text 'lara/views/app/WZControlPanelView.swift' '显示野怪计时' '缺少兵野页功能'
Require-Text 'lara/views/app/WZControlPanelView.swift' 'featureToggle\("小地图"' '缺少独立小地图开关'
Require-Text 'lara/views/app/WZControlPanelView.swift' 'featureToggle\("地图调节显示"' '缺少地图调节显示开关'
Require-Text 'lara/views/app/WZControlPanelView.swift' '地图坐标Y' '缺少调整页功能'
Require-Text 'lara/views/app/WZControlPanelView.swift' '只读后端已锁定' '缺少只读状态提示'
Require-Text '.github/workflows/build.yml' 'scripts/build_ipa_wz\.sh' 'CI 仍未使用王者构建入口'

$atlas = Join-Path $root 'lara/heroatlas.bin'
if (-not (Test-Path -LiteralPath $atlas) -or (Get-Item -LiteralPath $atlas).Length -ne 2164890) {
    throw 'FAIL: 王者英雄头像图集缺失或长度不符'
}
$atlasHash = (Get-FileHash -LiteralPath $atlas -Algorithm SHA256).Hash
if ($atlasHash -ne '32061154E6545F5372C567BD0598AFBAE815E18EAA80B1F4247C218FB3FB913E') {
    throw 'FAIL: 王者英雄头像图集哈希不符'
}

Write-Output 'PASS: WZ/Core source alignment, capability gating and lifecycle invariants'
