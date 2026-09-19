$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $root 'lara/views/app/ContentView.swift') -Raw -Encoding UTF8
$info = Get-Content -LiteralPath (Join-Path $root 'lara/Info.plist') -Raw -Encoding UTF8
$project = Get-Content -LiteralPath (Join-Path $root 'lara.xcodeproj/project.pbxproj') -Raw -Encoding UTF8

# AX 1.2.8 original executable SHA256:
# cc947605b97b90d898e784bf73dcab120c44c9281299fe840285dd67dfec1fb4
# Wu5ojXWpGE (0x100051600) builds the ten-item arranged-subview array.
# 0x1000545e8 passes 2.0 to STsFYTRP1C: (0x10005641c); that method
# returns an empty UIView with an active heightAnchor constraint.
$body = $source.Substring($source.IndexOf('var body: some View'))
$body = $body.Substring(0, $body.IndexOf('private var background:'))
$previous = -1
foreach ($token in @('Text("AX Pro")', 'Text("VERSION 1.2.8")',
                    '.frame(width: 56, height: 3)', 'supportCard',
                    'SecureField("请输入卡密"', 'actionButton("卡密激活"',
                    'statusCard', 'Color.clear.frame(height: 2)',
                    'actionButton("启动应用"', 'ProgressView(value:')) {
    $position = $body.IndexOf($token, [StringComparison]::Ordinal)
    if ($position -lt 0 -or $position -le $previous) {
        throw "FAIL: AX launcher item absent or out of order: $token"
    }
    $previous = $position
}
if ($source -match 'core-mountain|radialMenu|menuExpanded|三指|Text\("Core"\)|\.alert\("Core"') {
    throw 'FAIL: Core launcher or unsupported three-finger tutorial remains'
}
if ($body -notmatch 'actionButton\("启动应用"[\s\S]*?mgr\.launchWZGame\(\)') {
    throw 'FAIL: AX launch button is disconnected from the game launch flow'
}
if ($body -match '\.disabled\([^\r\n]*activationCode') {
    throw 'FAIL: UI introduced a fabricated activation-code launch gate'
}
foreach ($pattern in @('<string>AX Pro</string>', 'UIInterfaceOrientationLandscapeLeft',
                       'UIInterfaceOrientationLandscapeRight', 'UIInterfaceOrientationPortraitUpsideDown')) {
    if ($info -notmatch [regex]::Escape($pattern)) { throw "FAIL: AX Info.plist contract missing: $pattern" }
}
if ($project -notmatch 'MARKETING_VERSION = 1\.2\.8;' -or
    $project -notmatch 'CURRENT_PROJECT_VERSION = 1;') {
    throw 'FAIL: AX launcher bundle version is not 1.2.8 (build 1)'
}
if ($project -match 'INFOPLIST_KEY_UISupportedInterfaceOrientations_i(Phone|Pad) = UIInterfaceOrientationPortrait;') {
    throw 'FAIL: build settings override the AX four-orientation Info.plist contract'
}
$icons = @{
    'lara/AppIcon60x60@2x.png' = 'B5B43BE770B6514384393DEE2D0CECA9AAC9476FB32283D8D719F18525FDF2D0'
    'lara/AppIcon76x76@2x~ipad.png' = '67D418DE12C8C9521A80C6BAB887AE56E9E00DF757F2C0D4BEFB5B5D23832792'
}
foreach ($entry in $icons.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    if (-not (Test-Path -LiteralPath $path) -or
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.Value) {
        throw "FAIL: AX application icon is absent or changed: $($entry.Key)"
    }
}
if (Test-Path -LiteralPath (Join-Path $root 'lara/other/media.xcassets/AppIcon.appiconset')) {
    throw 'FAIL: obsolete Lara AppIcon asset catalog remains in the product'
}
Write-Output 'PASS: AX 1.2.8 launcher labels, order, spacer, and launch wiring'
