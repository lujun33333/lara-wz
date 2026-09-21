$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$runtime = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimRuntime.mm')
$header = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimRuntime.h')
$policy = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimPolicy.h')
$collector = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/YuanbaoCollector.mm')
$consumer = Get-Content -Raw (Join-Path $root 'lara/kexploit/wzesp.mm')
$swift = Get-Content -Raw (Join-Path $root 'lara/classes/laramgr.swift')
$bridge = Get-Content -Raw (Join-Path $root 'lara/lara-Bridging-Header.h')
$hud = Get-Content -Raw (Join-Path $root 'lara/kexploit/WZHUDBridge.mm')
$project = Get-Content -Raw (Join-Path $root 'lara.xcodeproj/project.pbxproj')
$build = Get-Content -Raw (Join-Path $root 'scripts/build_ipa_wz.sh')

function Need([string]$text, [string]$pattern, [string]$message) {
    if ($text -notmatch $pattern) { throw "FAIL: $message" }
}

Need $runtime 'WZAimRuntimeConfig gConfig\{0, 0, 1, 0, 0, 2, 0, 0\}' 'aim must default disabled with Lulu draw/visibility defaults'
Need $runtime 'wz_connected_pid\(\)' 'live pid gate missing'
Need $runtime 'wz_session_generation\(\)' 'live generation gate missing'
Need $runtime 'wz_transport_can_write\(\)' 'write-capability gate missing'
Need $runtime 'ExactIndicatorField' 'indicator field whitelist missing'
Need $runtime 'gIndicator \+ 0x48' 'verified indicator-to-skill-slot chain missing'
Need $runtime 'skillSlotObject \+ 0x30' 'active skill slot read missing'
Need $runtime 'WriteIndicatorPair' 'paired write/readback transaction missing'
Need $runtime 'RestoreOriginal' 'original-release rollback missing'
Need $runtime 'gConfig\.enabled == 0[\s\S]{0,220}WZAimRuntimeStatusDisabled' 'disabling aim can leave a stale target drawing'
Need $runtime 'gConfig\.officialParameters != 0[\s\S]{0,220}WZAimRuntimeStatusOriginalRelease' 'original-release mode can leave a stale target drawing'
Need $consumer 'WZESP_COLLECT_AIM[\s\S]{0,1600}KoiFeatureAvatar[\s\S]{0,700}KoiFeatureHero' 'shared aim collection mask missing'
Need $runtime 'FindBuiltIn' 'Lulu per-hero skill table missing'
Need $collector '0x123FBC88, 0x138, 0x2C8, 0x48, 0x170, 0x150' 'verified host chain missing'
Need $header 'wzaim_runtime_bind_indicator' 'indicator observer API missing'
Need $header 'wzaim_runtime_set_gesture_active' 'gesture lifecycle API missing'
Need $bridge 'wz/WZAimRuntime.h' 'Swift bridge import missing'
Need $swift 'wzaim_runtime_attach\(' 'attach lifecycle missing'
Need $swift 'wzaim_runtime_attach\([\s\S]*?imageValid,\s*canWrite\s*\)' 'aim attach must honor the version-profile write gate'
Need $hud 'WZESP_COLLECT_AIM' 'aim UI does not request the shared collector snapshot'
Need $consumer 'wzaim_runtime_consume_snapshot' 'shared collector does not feed the aim consumer'
Need $swift 'WZESP_AUTO_KILL \| WZESP_COLLECT_AIM[\s\S]{0,120}WZESP_READER_HOST_POSITION' 'shared aim snapshot does not schedule the verified host reader'
if ($runtime -match 'YuanbaoCollectorGather|YuanbaoCollectorReadAimHostPosition|KoiProjectionRefresh' -or
    $swift -match 'wzaim_runtime_tick\(') {
    throw 'FAIL: aim still owns a second gather/host/projection path'
}
Need $swift 'stopWZReadersOnWorker\(\)\s*wzaim_runtime_detach\(\)\s*wzesp_reset\(\)\s*wz_disconnect\(\)' 'detach must restore/stop before transport disconnect'
Need $hud 'wzaim_runtime_is_ready\(\)' 'UI readiness gate missing'
Need $hud 'wzaim_runtime_apply_config\(&aim\)' 'UI config is not connected to runtime'
Need $hud 'wzaim_runtime_set_skill_config' 'per-hero skill settings are not connected'
Need $hud 'aim\.enabled' 'aim switch UI missing'
Need $hud '44100' 'four target-priority controls missing'
Need $hud '44200' 'three draw-target controls missing'
Need $hud 'wzaim_runtime_copy_target\(&aimTarget\)' 'target draw mode is not connected to the shared renderer'
Need $hud 'tag >= 21000 && tag < 21002' 'aim parameter sliders are not connected to HID pointer routing'
Need $hud 'aim\.official' 'original-release control missing'
if ($hud -match 'aim\.button|44003|AIM 悬浮按钮') {
    throw 'FAIL: unsupported AIM button remains as a disabled fallback UI'
}
Need $hud 'if \(!wzaim_runtime_is_ready\(\)\) ax_store_setting.*aim\.enabled.*NO' 'not-ready UI must force persisted aim off'
Need $project 'PBXFileSystemSynchronizedRootGroup[\s\S]*?path = lara;' 'lara synchronized source membership missing'
if ($project -match 'membershipExceptions = \([\s\S]*?WZAimRuntime\.mm') {
    throw 'FAIL: WZAimRuntime.mm is excluded from the synchronized target'
}
Need $build 'xcodebuild' 'package script does not compile the synchronized Xcode target'

$rows = [regex]::Matches($runtime, '\{\d+,\d+,[0-9.]+f,[0-9.]+f\}').Count
if ($rows -ne 51) { throw "FAIL: expected 51 Lulu hero/slot rows, got $rows" }

Write-Output 'WZ aim runtime static checks passed: exact table, lifecycle, whitelist, rollback, collector and Swift wiring'
