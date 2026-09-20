$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $root 'lara/kexploit/WZHUDBridge.mm') -Raw -Encoding UTF8
$project = Get-Content -LiteralPath (Join-Path $root 'lara.xcodeproj/project.pbxproj') -Raw -Encoding UTF8
$imguiRoot = Join-Path $root 'lara/third_party/imgui'

$pinnedFiles = [ordered]@{
    'imgui.h' = 'cfb1ad68fc69fba743aafc5b446b4d5e9137948a45019fdb94231db11e9dd6eb'
    'imconfig.h' = '6e5687893594ebfaf8569280cfea83d025904a8a4e23bec073086f6c5bc8f7fb'
    'imgui_internal.h' = '77ede7b9745dc81b93e4509e5da4c309df31b1862298853df8cfe24fc03d2634'
    'imstb_rectpack.h' = '2efa3d5f7d003c19743b15155dad9f46d9f9fc783a18893d703b431d3c990972'
    'imstb_textedit.h' = 'a985f5fa0ed97353d493b497961e9eef52082edcd045cf6954b69990ec9d0741'
    'imstb_truetype.h' = '88f0a25e27f5eefd6ec50c42fc5fe3026aa8170603efa08aa18d622db8660923'
    'imgui.cpp' = '3799eaad52055fe999d2e984df242d6ff418177ebd533994f6d0025d00605acd'
    'imgui_draw.cpp' = 'c04a6abc385b2bc0ea1012f2e165eec0f8619acb66b494de52a56e7274bee1bc'
    'imgui_tables.cpp' = '00827be09da0c458d55c1e5383c56909c4cf6ae86c4f8c7f50ee2bb407cd8106'
    'imgui_widgets.cpp' = '76c93645fc873f46957c07c60ce818860645951f1785e3cd4d9631b78c30283d'
    'LICENSE.txt' = 'c80c5789748d955c4a650562baa0d750494e2c7128c2ca66aaebe2e3c4e198bf'
    'backends/imgui_impl_metal.h' = '0d542dd0147b7dfc767008da0eb9fca22ac579988c63cc302a23d149264159d2'
    'backends/imgui_impl_metal.mm' = 'c04fab400207a331ac86a1c8f6179d5d70a543aecf06ac93f69fb8e18af18765'
}
foreach ($entry in $pinnedFiles.GetEnumerator()) {
    $path = Join-Path $imguiRoot $entry.Key
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "FAIL: missing vendored ImGui file $($entry.Key)" }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $entry.Value) { throw "FAIL: ImGui snapshot drift in $($entry.Key): $actual" }
}

$imgui = Get-Content -LiteralPath (Join-Path $imguiRoot 'imgui.h') -Raw -Encoding UTF8
$backend = Get-Content -LiteralPath (Join-Path $imguiRoot 'backends/imgui_impl_metal.mm') -Raw -Encoding UTF8
if ($imgui -notmatch '#define IMGUI_VERSION\s+"1\.92\.5 WIP"' -or
    $imgui -notmatch '#define IMGUI_VERSION_NUM\s+19248') {
    throw 'FAIL: vendored Dear ImGui version is not the pinned 1.92.5 WIP snapshot'
}
if ($imgui -notmatch 'typedef unsigned short ImDrawIdx' -or
    $imgui -notmatch 'struct ImDrawVert[\s\S]{0,180}ImVec2\s+pos;[\s\S]{0,80}ImVec2\s+uv;[\s\S]{0,80}ImU32\s+col;') {
    throw 'FAIL: ImDraw index/vertex declaration drifted'
}
foreach ($pattern in @(
    'sourceRGBBlendFactor = MTLBlendFactorSourceAlpha',
    'destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha',
    'sourceAlphaBlendFactor = MTLBlendFactorOne',
    'destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha',
    'setScissorRect:scissorRect',
    'offsetof\(ImDrawVert, pos\)',
    'offsetof\(ImDrawVert, uv\)',
    'offsetof\(ImDrawVert, col\)',
    'ImGui_ImplMetal_UpdateTexture'
)) {
    if ($backend -notmatch $pattern) { throw "FAIL: Metal backend contract missing: $pattern" }
}

foreach ($pattern in @(
    'static_assert\(sizeof\(ImGuiIO\) == 0xbd8 && sizeof\(ImGuiStyle\) == 0x4ec',
    'offsetof\(ImDrawVert,pos\) == 0',
    'offsetof\(ImDrawVert,uv\) == 8',
    'offsetof\(ImDrawVert,col\) == 0x10',
    'sizeof\(ImDrawIdx\) == 2 && sizeof\(ImTextureID\) == 8',
    'ImGui_ImplMetal_Init\(_device\)',
    'AddFontFromFileTTF\(fontPath\.fileSystemRepresentation,18\.0f,nullptr',
    'GetGlyphRangesDefault\(\)',
    'io\.DisplayFramebufferScale=ImVec2',
    'io\.DeltaTime=kAXImGuiDeltaTime',
    'ImGui::NewFrame\(\)',
    'ImGui::Render\(\)',
    'ImGui_ImplMetal_RenderDrawData\(ImGui::GetDrawData\(\),command,encoder\)',
    'submitCommands:\(const AXHUDRenderCommands \*\)commands',
    'submitCommands:&frame\.commands',
    'ax_build_render_commands\(latest, latestCount, current_wz_config\(\)',
    'for \(const AXHUDRenderCommand &command : \*_commands\)',
    'buildDirectDrawList:\(ImDrawList \*\)drawList',
    'drawList->PushClipRect',
    'drawList->PathStroke',
    'drawList->PathArcTo',
    'drawList->AddLine',
    'drawList->AddRect',
    'drawList->AddCircleFilled',
    'drawList->AddCircle',
    'drawList->AddText',
    'drawList->AddImageRounded'
)) {
    if ($source -notmatch $pattern) { throw "FAIL: foreground ImGui contract missing: $pattern" }
}
if ($source -match 'textureForCommand|setVertexBytes:vertices|drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6|CGPathApply|for \(CALayer \*layer in _commands\)|appendShapeLayer') {
    throw 'FAIL: legacy per-layer CoreGraphics/CGPath foreground renderer remains'
}
if (($project | Select-String -Pattern '\$\(SRCROOT\)/lara/third_party/imgui' -AllMatches).Matches.Count -ne 2) {
    throw 'FAIL: Debug/Release ImGui header search paths are not both present'
}
if ($project -notmatch 'PBXFileSystemSynchronizedRootGroup[\s\S]{0,300}path = lara;' -or
    $project -notmatch 'membershipExceptions = \([\s\S]{0,500}third_party/imgui/LICENSE\.txt' -or
    $project -match 'membershipExceptions = \([\s\S]{0,500}third_party/imgui/(imgui|imconfig|imstb|backends)') {
    throw 'FAIL: vendored ImGui sources are not covered by the synchronized lara source group'
}

Write-Output 'PASS: pinned ImGui 1.92.5 WIP snapshot, ABI/layout and Metal draw-data contracts'
