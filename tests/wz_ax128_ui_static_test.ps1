$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $root 'lara/kexploit/WZHUDBridge.mm') -Raw
$project = Get-Content -LiteralPath (Join-Path $root 'lara.xcodeproj/project.pbxproj') -Raw
foreach ($framework in @('MetalKit','Metal')) {
    if ($project -notmatch "name = $framework\.framework; path = System/Library/Frameworks/$framework\.framework; sourceTree = SDKROOT" -or
        $project -notmatch "PBXFrameworksBuildPhase;[\s\S]*?$framework\.framework in Frameworks") {
        throw "FAIL: $framework.framework is not explicitly linked"
    }
}

function Require([string]$pattern, [string]$message) {
    if ($source -notmatch $pattern) { throw "FAIL: $message" }
}
function Reject([string]$pattern, [string]$message) {
    if ($source -match $pattern) { throw "FAIL: $message" }
}

# Independent reference: original AX 1.2.8 executable SHA256
# cc947605b97b90d898e784bf73dcab120c44c9281299fe840285dd67dfec1fb4.
# Menu construction: 0x10088bef4; checkbox group: 0x1008dfbbc;
# sliders: 0x100952488 / 0x100969dd8; geometry: 0x100a5960c.
Require 'CGRectMake\(0,0,560,360\)' 'AX panel dimensions changed'
Require 'CGRectMake\(0,3,126,319\)' 'AX sidebar dimensions changed'
Require 'CGRectMake\(127,3,433,319\)' 'AX content dimensions changed'
Require 'CGRectMake\(0,322,560,38\)' 'AX footer dimensions changed'
Require '@\[@"绘制功能",@"进阶功能",@"设置功能"\]' 'AX page order changed'
Require '@"AX PRO  ·  CONTROL PANEL"' 'AX footer title missing'
Require '@"VERSION 1\.2\.8"' 'AX version caption missing'
Require '@"退出 HUD"' 'AX exit action missing'
Require 'g_floatButton\.layer\.cornerRadius=20' 'AX floating button is not circular'
Require 'CGRectGetWidth\(bounds\)-30,CGRectGetHeight\(bounds\)\*\.5' 'AX initial floating center changed'
Reject 'CGRectMake\(0,\s*0,\s*900,\s*600\)|wzCore|@"CORE\.|S M O B A|WZHUDTouchProxy|update_fallback_snapshot|present_snapshot_metal' 'CORE presentation residue present'
Reject 'NSUserDefaults' 'AX settings incorrectly use UserDefaults'

foreach ($title in @('小地图绘制','小地图血量','小地图回城','小地图野怪','小地图兵线',
                    '召唤师技能','大地图射线','大地图方框','大地图头像',
                    '自动功能','人物视野','斩杀敌人','斩杀坐标设置',
                    '自身视野暴露点(兵线)','自身视野暴露点(敌人)','小地图敌人视野',
                    '技能大小','技能位置X','技能位置Y','地图大小','地图位置')) {
    Require ([regex]::Escape('@"' + $title + '"')) "AX control missing: $title"
}
Require 'maxima\[\] = \{70,400,300,300,250\}' 'AX slider limits changed'
Require 'index == 2 \? 0 : 50' 'AX slider defaults changed'
Require 'if \(ax_bool\(@"shiye\.hero"\)\) flags \|= WZESP_SHOW_HERO_VISION' 'Hero exposure key is not independent'
Require 'if \(ax_bool\(@"shiye\.soldier"\)\) flags \|= WZESP_SHOW_SOLDIER_VISION' 'Soldier exposure key is not independent'
Require 'item\.primitive==WZESP_PRIMITIVE_EXPOSURE_POINT[\s\S]{0,800}primitiveColorRGBA' 'Exposure primitive is not rendered'

# Keychain service: 0x10001d370; read: 0x10000ccd8; write: 0x10000fe1c.
Require 'stringByAppendingString:@"\.ax-settings"' 'AX settings service suffix changed'
Require 'kSecAttrAccount:@"settings"' 'AX settings account changed'
Require 'kSecMatchLimitOne' 'AX settings query does not request one result'
Require 'NSPropertyListBinaryFormat_v1_0' 'AX settings binary plist encoding missing'
Require 'kSecAttrAccessibleAfterFirstUnlock' 'AX keychain accessibility changed'
Require 'SecItemUpdate[\s\S]{0,200}errSecItemNotFound[\s\S]{0,250}SecItemAdd' 'AX keychain update/add sequence changed'
Require 'g_captureKillPoint && phase==WZHUDPointerPhaseBegan[\s\S]{0,800}click_coord_x[\s\S]{0,500}click_coord_y[\s\S]{0,500}ax_store_setting\(@"click_coord_space",@"fixed"\)' 'Physical coordinate capture is not persisted in fixed space'
Require 'objc_getClass\("FBSOrientationObserver"\)' 'AX orientation observer missing'
Require 'NSSelectorFromString\(@"activeInterfaceOrientation"\)' 'AX authoritative orientation getter missing'
Reject 'CMMotionManager|g_threeFinger|orientation_poll_timer|core_|wzCore' 'Non-AX orientation/input implementation remains'

# CA renderer: 0x10074d6b0..0x1007666a8. No full-frame snapshot bridge.
Require 'MTLPixelFormatRGBA8Unorm' 'AX per-image texture format changed'
Require 'kCGBitmapByteOrder32Big\|kCGImageAlphaPremultipliedLast' 'AX image bitmap format changed'
Require 'objc_setAssociatedObject\(texture,&kAXTextureImageKey,image,OBJC_ASSOCIATION_RETAIN_NONATOMIC\)' 'CA image association lifetime missing'
Require 'kWZHUDControlPanelDrag' 'Background sidebar drag state missing'
Require 'move_panel_main\(\[gesture translationInView:g_menuCanvas\]\)' 'UIKit/HID panel geometry no longer shared'
Require 'NSTimeInterval duration=\.3' 'AX observer fallback animation duration changed'
Require '@\[@"orientation",@"duration"\]' 'AX observer update fields missing'
Require 'item.screenY - 50\.0' 'AX world box offset changed'
Require 'CGPointMake\(width \* 0\.5, height \* 0\.5\)' 'AX ray origin is not screen center'
Require 'config.minimapSize / 15\.4f' 'AX world portrait radius changed'
Require 'config.minimapSize / 17\.0f' 'AX minimap portrait radius changed'
Require 'healthRing.lineWidth = 1\.8' 'AX health arc width changed'
Require 'endAngle:\(CGFloat\)\(-M_PI_2\+M_PI\*2\.0\*fmin\(1\.0,fmax\(0\.0,healthRatio\)\)\)' 'Health arc must be encoded in the path for both backends'
Require 'healthRing.strokeEnd = 1' 'Metal backend cannot consume implicit strokeEnd health clipping'
Require 'g_axFrameTime \+= \(double\)delta' 'AX animation clock is not advanced by the actual tick delta'
Require 'now-g_axLastTick' 'Background irregular frame spacing is ignored'
Require '@interface WZAXMetalRenderer : NSObject <MTKViewDelegate>' 'Foreground Metal delegate missing'
Require 'id<MTLCommandQueue> _commandQueue' 'Foreground command queue missing'
Require 'drawInMTKView:' 'Foreground drawable rendering missing'
Require 'if \(!rendererReady\) \{\s*set_error\([^;]+;\s*return NO;' 'Renderer creation failure is published as active'
Require 'if \(!create_hud_main\(\)\) \{\s*destroy_hud_main\(\)' 'Failed startup does not roll back local windows'
Require '\[command presentDrawable:drawable\]' 'Foreground drawable presentation missing'
Require '\[command commit\]' 'Foreground command buffer commit missing'
Require 'g_metalRenderer.view.hidden=!foreground' 'Foreground/background backend visibility switch missing'
Require '\[g_layerRenderer setVisible:!foreground\]' 'CA backend is not hidden in foreground'
Require 'orientationGeneration!=g_orientationGeneration.load\(\)' 'Stale rotation completion is not generation guarded'
Require 'rotation=\(float\)g_axFrameTime\*2\.5f' 'AX recall spin rate changed'
Require 'index<4' 'AX four recall arc groups missing'
Require '1\.0995573997497559f' 'AX primary recall sweep changed'
Require '0\.5497786998748779f' 'AX secondary recall sweep changed'
Require '0xFFFFDC64u' 'AX primary recall color changed'
Require '0xB4C87828u' 'AX secondary recall color changed'
Require '0x50DC8C3Cu' 'AX recall base-ring color changed'
Require 'AXMonsterPolicy::MinimapMarker' 'AX fixed-slot monster marker policy missing'
Require 'item.axMonsterSlot' 'Monster slot identity is lost across collection/rendering'
Require 'AXMonsterPolicy::TimerColor\(\(size_t\)item.axMonsterSlot\)' 'AX timer color is not consumed from shared policy'
Require 'AXMonsterPolicy::DrawableSlot\(item.axMonsterSlot\)' 'AX draw-slot filter is not consumed from shared policy'
Require 'AXMonsterPolicy::TimerOriginOffset' 'AX timer origin offset missing'
Require 'item.cooldownSeconds!=0' 'AX nonzero timer condition changed'
Reject 'WZYuanbaoDrawPolicy|monsterSubtype|showWorldMonster' 'Non-AX monster presentation remains'
Require '@implementation AXHUDCoreAnimationRenderer' 'AX CA renderer missing'
Require 'object_getClass\(layer\) != layerClass' 'Layer pool does not compare exact layer class'
Require '@"AXHUDBackgroundContent"' 'AX CA root name changed'
Require '@"Rajdhani-Bold"' 'AX font missing'
Require 'attempt<3 && data\.length<=1000' 'AX image retry or minimum-data boundary changed'
Require 'CFAbsoluteTimeGetCurrent\(\)\+5\.0' 'AX image failure cooldown changed'
Require 'rowX=config\.skillX\+\(size\+3\)\*skillIndex' 'AX skill row spacing is not consumed'
Require 'smallSize=\(size-5\)/2\.5' 'AX skill status dimensions changed'
Require 'summonerY=heroY\+size\+2' 'AX skill icon vertical stacking changed'
Require 'alpha:118\.0/255\.0' 'AX skill cooldown overlay opacity changed'
Require 'wzax_touch_set_host\(remoteCall\)' 'AX sender is not attached to completed hosts'
Require 'bool wzhud_unregister_springboard_hosts\(RemoteCall \*remoteCall\) \{\s*wzax_touch_shutdown\(\)' 'AX sender is not stopped before host cleanup'
Require 'kCALineCapButt' 'AX default line cap changed'
Require 'kCALineJoinRound' 'AX default line join changed'
Require 'kCAGravityResizeAspectFill' 'AX image gravity changed'
Require 'CGRectInset\(anchor,-4,-4\)' 'AX compact interaction padding changed'
Require 'g_activePointerTag==0 && g_geometryTransitions==0' 'Compact geometry ignores active interactions'
Require 'visible \? \.22 : \.18' 'AX panel animation duration changed'
Require 'CGAffineTransformMakeScale\(\.94,\.94\)' 'AX panel animation scale changed'
Require 'for \(double delay : \{\.15,\.65,1\.5\}\)' 'AX app-switch orientation retries changed'

Write-Output 'PASS: AX 1.2.8 UI static contracts; UIKit/device behavior remains unverified'
