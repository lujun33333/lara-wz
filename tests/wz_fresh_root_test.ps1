$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Read-Source([string]$Path) {
    return Get-Content -LiteralPath (Join-Path $root $Path) -Raw -Encoding UTF8
}

function Require-Text([string]$Path, [string]$Pattern, [string]$Message) {
    if ((Read-Source $Path) -notmatch $Pattern) {
        throw "FAIL: $Message ($Path)"
    }
}

function Reject-Text([string]$Path, [string]$Pattern, [string]$Message) {
    if ((Read-Source $Path) -match $Pattern) {
        throw "FAIL: $Message ($Path)"
    }
}

Require-Text 'lara/kexploit/wzmem.h' `
    'wz_read_fresh_root\s*\(' `
    '缺少一级根 fresh-read API'
Require-Text 'lara/kexploit/wzmem.m' `
    'wz_mcache_evict_page_locked[\s\S]*entry->page != page[\s\S]*wz_release_mapping' `
    'mapped-pages 未精确淘汰目标页'
Require-Text 'lara/kexploit/wzmem.m' `
    'wz_read_fresh_root[\s\S]*pthread_mutex_lock\(&g_wzMemoryLock\)[\s\S]*wz_mcache_evict_page_locked\(g_wzDefaultPages, page\)[\s\S]*wz_mapped_page\(g_wzDefaultPages, page\)' `
    'fresh-read 未在同一锁内淘汰并重建目标页'
Require-Text 'lara/kexploit/wzmem.m' `
    'WZ_TRANSPORT_MACH_TASK[\s\S]*wz_mach_read_locked\(addr, buffer, size\)' `
    'Mach task 路径未保持直接读取'
Require-Text 'lara/kexploit/wz/KoiProjection.mm' `
    'kFreshRootIntervalNanoseconds\s*=\s*UINT64_C\(750000000\)' `
    '矩阵根 fresh-read 未按 750ms 限频'
Require-Text 'lara/kexploit/wz/KoiProjection.mm' `
    'root == 0 \|\| !IsReadablePointer\(root\)[\s\S]*RefreshInvalidMatrixRoot' `
    '矩阵根并非只在 zero/invalid 时 fresh-read'
Require-Text 'lara/kexploit/wz/YuanbaoCollector.mm' `
    'root == 0 \|\| !IsPointer\(root\)[\s\S]*gActorFreshRootProbe' `
    'Actor 根并非只在 zero/invalid 时 fresh-read'
Require-Text 'lara/kexploit/wz/YuanbaoCollector.mm' `
    'root == 0 \|\| !IsPointer\(root\)[\s\S]*gMonsterFreshRootProbe' `
    'Monster 根并非只在 zero/invalid 时 fresh-read'
Require-Text 'lara/kexploit/wz/KoiProjection.mm' `
    'fresh-root matrix cached=0x%llx[\s\S]*fresh=0x%llx rebuild=%llu' `
    '矩阵 fresh-read 缺少 cached/fresh/rebuild 诊断'
Require-Text 'lara/kexploit/wz/YuanbaoCollector.mm' `
    'fresh-root %s cached=0x%llx[\s\S]*fresh=0x%llx rebuild=%llu' `
    '实体 fresh-read 缺少 cached/fresh/rebuild 诊断'

$readOnlyFiles = @(
    'lara/kexploit/wz/KoiProjection.mm',
    'lara/kexploit/wz/YuanbaoCollector.mm',
    'lara/kexploit/wzesp.mm'
)
foreach ($path in $readOnlyFiles) {
    Reject-Text $path '\bwz_write\s*\(' "一级根修复不得写目标进程: $path"
}

Write-Host 'PASS: WZ root slots use rate-limited, read-only mapped-page refresh.'
