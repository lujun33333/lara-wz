$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$header = Get-Content -Raw (Join-Path $root 'lara/kexploit/wzesp.h')
$consumer = Get-Content -Raw (Join-Path $root 'lara/kexploit/wzesp.mm')
$collector = Get-Content -Raw (Join-Path $root 'lara/kexploit/wz/YuanbaoCollector.mm')
function Require([string]$text, [string]$pattern, [string]$reason) {
    if ($text -notmatch $pattern) { throw $reason }
}
Require $header 'WZESP_SHOW_HERO_VISION\s*=\s*1u\s*<<\s*15' 'AX hero vision needs its own flag'
Require $header 'WZESP_SHOW_SOLDIER_VISION\s*=\s*1u\s*<<\s*16' 'AX soldier vision needs its own flag'
Require $header 'WZESP_PRIMITIVE_EXPOSURE_POINT\s*=\s*4' 'AX exposure point primitive missing'
Require $collector 'offsets\[\]\{0x123FBC88, 0x138, 0x2C8, 0x48, 0x170\}' 'AX decoded host chain changed'
Require $collector 'AddAddress\(cursor, 0x150' 'Host position must use the terminal +0x150 address'
Require $collector 'position\[2\]\) / 1000\.0f' 'Host z must come from raw int32 xyz /1000'
Require $collector 'reader\.pointer\(actor, 0x1A0, &state\)' 'AX soldier HP owner changed'
Require $collector 'reader\.field\(state, 0x160, &raw\)' 'AX soldier HP field changed'
Require $collector 'entity->exposureState = raw / 8192' 'AX soldier HP scaling changed'
Require $collector 'heroOffsets\[\]\{0x268, 0x10, 0, 0x60\}' 'AX hero coordinates must use the recovered direct pointer chain'
Require $collector 'rawA / 8192000' 'AX own-state gate scaling changed'
Require $consumer 'wzax_touch_tap\(config.clickX, config.clickY,' 'Auto kill must call the recovered touch sender'
Require $consumer 'now \+ UINT64_C\(1000000000\)' 'Auto kill throttle must last one second'
Require $consumer 'input\.collectExposure && diagnostics\.hostPositionValid' 'Do not draw a fabricated safe dot when host position cannot be read'
Require $consumer 'hero && dx == 0\.0f && dz == 0\.0f' 'AX excludes coincident hero coordinates'
Require $consumer 'std::fma\(dx, dx, dz \* dz\) <= 144\.0f' 'AX exposure radius squared is exactly 144, with fused multiply-add'
Require $consumer 'item\.minimapExposureValid = 1' 'Minimap visibility must have a live producer'
Require $consumer 'exposed \? 0xFF0000FFu : 0xB40000FFu' 'AX minimap ring bright/dim colors changed'
Require $consumer 'const bool exposed = AXMinimapExposed' 'Do not replace geometric visibility with the legacy visibility byte'
Require $consumer 'config->minimapSize / 30\.0f' 'AX dot radius is mapsize/30'
Require $consumer 'exposed \? 0xFF0000FFu : 0x00FF00FFu' 'AX point must be red/green in the bridge RGBA layout'
Write-Output 'PASS: AX exposure source contracts (static only; no iOS compile or device test)'
