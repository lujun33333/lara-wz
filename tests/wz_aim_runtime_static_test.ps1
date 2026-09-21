$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$runtime = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimRuntime.mm')
$header = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimRuntime.h')
$policy = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimPolicy.h')
$observer = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimObserver.mm')
$observerHeader = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimObserver.h')
$observerPolicy = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/WZAimObserverPolicy.h')
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

function Reject([string]$text, [string]$pattern, [string]$message) {
    if ($text -match $pattern) { throw "FAIL: $message" }
}

Need $runtime 'WZAimRuntimeConfig gConfig\{0, 0, 1, 0, 0, 2, 0, 0\}' 'aim must default disabled with Lulu draw/visibility defaults'
Need $runtime 'wz_connected_pid\(\)' 'live pid gate missing'
Need $runtime 'wz_session_generation\(\)' 'live generation gate missing'
Need $runtime 'wz_transport_can_write\(\)' 'write-capability gate missing'
Need $policy 'profileVerified' 'observer-specific profile gate missing'
Need $policy 'TransportSessionReady' 'pre-observer transport/session gate missing'
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
Need $header 'wzaim_runtime_bind_verified_indicator' 'verified indicator observer API missing'
if ($header -match 'wzaim_runtime_bind_indicator\(') {
    throw 'FAIL: unverified raw indicator binder remains exposed'
}
Need $header 'wzaim_runtime_set_gesture_active' 'gesture lifecycle API missing'
Need $observerPolicy 'kTypeInfoTableRVA = 0x137DF518' 'pure-read IL2CPP type-info anchor missing'
Need $observerPolicy 'kSkillButtonManagerTypeIndex = 44507' 'manager type-definition index missing'
Need $observerPolicy 'kSkillSlotLinkerTypeIndex = 45480' 'slot type-definition index missing'
Need $observerPolicy 'kSkillControlIndicatorTypeIndex = 45348' 'indicator type-definition index missing'
Need $observerPolicy 'kClassNameOffset = 0x10' 'Il2CppClass name layout missing'
Need $observerPolicy 'kClassNamespaceOffset = 0x18' 'Il2CppClass namespace layout missing'
Need $observerPolicy 'kClassParentOffset = 0x58' 'Il2CppClass parent layout missing'
Need $observerPolicy 'kClassFieldsOffset = 0x80' 'Il2CppClass fields layout missing'
Need $observerPolicy 'kClassStaticFieldsOffset = 0xB8' 'Il2CppClass static-fields layout missing'
Need $observerPolicy 'kClassInstanceSizeOffset = 0xF8' 'Il2CppClass instance-size layout missing'
Need $observerPolicy 'kClassFieldCountOffset = 0x124' 'Il2CppClass field-count layout missing'
Need $observerPolicy 'kFieldInfoStride = 0x20' 'FieldInfo stride missing'
Need $observerPolicy 'kTypeAttributesOffset = 0x08' 'Il2CppType attrs layout missing'
Need $observerPolicy 'kFieldAttributeStatic = 0x10' 'FieldInfo static-attribute gate missing'
Need $observerPolicy 'ValidClassStructure' 'Il2CppClass structural validation missing'
Need $observerPolicy 'indicatorSlot != 0x48' 'reflected indicator layout gate missing'
Need $observerPolicy 'indicatorPosition != WZAimPolicy::kIndicatorPositionOffset' 'position field gate missing'
Need $observer 'VerifyRemoteUUID' 'observer does not independently verify remote UUID'
Need $observer 'ReadAt\(gObserver\.unityBase,[\s\S]{0,100}kTypeInfoTableRVA' 'observer does not read the fixed type-info anchor'
Need $observer 'CSkillButtonManager' 'real skill-button manager observer missing'
Need $observer 'SkillSlotLinker' 'exact skill-slot class validation missing'
Need $observer 'SkillControlIndicator' 'exact indicator class validation missing'
Need $observer 'name != "_instance"' 'singleton observer does not require the exact _instance field'
Need $observer 'record\.parent != klass\.structure\.klass' 'FieldInfo parent validation missing'
Need $observer 'kTypeAttributesOffset' 'FieldInfo type attributes are not read directly'
Need $observer 'kFieldAttributeStatic' 'static/instance FieldInfo gate missing'
Need $observer 'kClassStaticFieldsOffset' 'singleton is not read from parent static_fields'
Need $observer 'm_skillButtonDown' 'real button-down source missing'
Need $observer 'm_skillButtonDraging' 'real drag source missing'
Need $observer 'm_usingSlot' 'active SkillSlotLinker source missing'
Need $observer 'skillIndicator' 'slot-to-indicator source missing'
Need $observer 'ExactObservation' 'object/class/link proof missing'
Need $observerPolicy 'kMetadataRetryAttemptSaturation = 8' 'metadata retry counter is not bounded'
Need $observerPolicy 'MetadataRetryDelaySeconds' 'metadata retry backoff policy missing'
Need $observerPolicy 'return delay > 2\.0 \? 2\.0 : delay' 'metadata retry cadence is not capped at two seconds'
Need $observer 'metadataResolveAttempts <[\s\S]{0,120}kMetadataRetryAttemptSaturation' 'metadata retry counter does not saturate'
Need $observer 'now >= gObserver\.nextMetadataResolve' 'metadata retry has no backoff gate'
Reject $observer 'RemoteCall|doRemoteCall|remote_write|remote_alloc_str|thread_attach|thread_detach|\bmalloc\b|\bfree\b' 'observer still executes or prepares target-process calls'
Need $observer 'wzaim_runtime_bind_verified_indicator' 'verified observer is not connected to runtime'
Need $observer 'wzaim_runtime_set_gesture_active\(true\)' 'gesture activation is not connected'
if ($observer -match '\bwz_write\s*\(') {
    throw 'FAIL: observer writes game fields outside WZAimRuntime whitelist'
}
Need $observerHeader 'wzaim_observer_poll' 'observer poll API missing'
Need $bridge 'wz/WZAimRuntime.h' 'Swift bridge import missing'
Need $bridge 'wz/WZAimObserver.h' 'observer Swift bridge import missing'
Need $swift 'wzaim_runtime_attach\(' 'attach lifecycle missing'
Need $swift 'wzaim_runtime_attach\([\s\S]*?imageValid,\s*backendCanWrite\s*\)' 'aim runtime must receive backend capability behind its observer gate'
Need $swift 'wzaim_observer_start\([\s\S]*?imageValid,\s*backendCanWrite\s*\)' 'verified external observer lifecycle missing'
Need $swift 'wzaim_observer_poll\(\)' 'verified observer is not polled by the WZ worker'
Need $hud 'WZESP_COLLECT_AIM' 'aim UI does not request the shared collector snapshot'
Need $consumer 'wzaim_runtime_consume_snapshot' 'shared collector does not feed the aim consumer'
Need $swift 'WZESP_AUTO_KILL \| WZESP_COLLECT_AIM[\s\S]{0,120}WZESP_READER_HOST_POSITION' 'shared aim snapshot does not schedule the verified host reader'
if ($runtime -match 'YuanbaoCollectorGather|YuanbaoCollectorReadAimHostPosition|KoiProjectionRefresh' -or
    $swift -match 'wzaim_runtime_tick\(') {
    throw 'FAIL: aim still owns a second gather/host/projection path'
}
Need $swift 'stopWZReadersOnWorker\(\)\s*wzaim_observer_stop\(\)\s*wzaim_runtime_detach\(\)\s*wzesp_reset\(\)\s*wz_disconnect\(\)' 'detach must stop observer and restore before transport disconnect'
Need $hud 'wzaim_runtime_is_ready\(\)' 'UI readiness gate missing'
Need $hud 'wzaim_runtime_apply_config\(&aim\)' 'UI config is not connected to runtime'
Need $hud 'wzaim_runtime_set_skill_config' 'per-hero skill settings are not connected'
Need $hud 'aim\.enabled' 'aim switch UI missing'
Need $hud '44100' 'four target-priority controls missing'
Need $hud '44200' 'three draw-target controls missing'
Need $hud 'wzaim_runtime_copy_target\(&aimTarget\)' 'target draw mode is not connected to the shared renderer'
Need $hud 'tag >= 21000 && tag < 21002' 'aim parameter sliders are not connected to HID pointer routing'
Need $hud 'aim\.official' 'original-release control missing'
Need $hud 'if \(enabled\) ax_store_setting\(@"aim\.official",@NO\)' 'enabling aim does not leave original-release bypass active'
Need $hud 'if \(official\) ax_store_setting\(@"aim\.enabled",@NO\)' 'original-release mode does not disable aim writes'
if ($hud -match 'aim\.button|44003|AIM 悬浮按钮') {
    throw 'FAIL: unsupported AIM button remains as a disabled fallback UI'
}
Need $hud 'aim\.enabled=requested' 'armed aim request is not forwarded to the gated runtime'
Need $hud 'if \(ax_bool\(@"aim\.enabled"\) && !ax_bool\(@"aim\.official"\)\)[\s\S]{0,80}WZESP_COLLECT_AIM' 'armed aim does not request the shared snapshot before observer proof'
Need $hud '@"\\u81ea\\u7784\\u5f00\\u5173",44000,ax_bool\(@"aim\.enabled"\),YES' 'aim switch is still disabled before the first verified gesture'
if ($hud -match 'if \(!ready && requested\)[\s\S]{0,280}aim\.enabled.*NO') {
    throw 'FAIL: observer warm-up still clears the persisted aim request'
}
Need $project 'PBXFileSystemSynchronizedRootGroup[\s\S]*?path = lara;' 'lara synchronized source membership missing'
if ($project -match 'membershipExceptions = \([\s\S]*?WZAim(Runtime|Observer)\.mm') {
    throw 'FAIL: WZAim runtime/observer is excluded from the synchronized target'
}
Need $build 'xcodebuild' 'package script does not compile the synchronized Xcode target'

$rows = [regex]::Matches($runtime, '\{\d+,\d+,[0-9.]+f,[0-9.]+f\}').Count
if ($rows -ne 51) { throw "FAIL: expected 51 Lulu hero/slot rows, got $rows" }

Write-Output 'WZ aim runtime static checks passed: exact table, lifecycle, whitelist, rollback, collector and Swift wiring'
