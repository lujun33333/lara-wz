#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP=lara
CONFIG=Release
DERIVED="$ROOT/build/DerivedDataWZ"

for arg in "$@"; do
    case "$arg" in
        --debug) CONFIG=Debug ;;
        *) echo "未知参数：$arg（可用：--debug）" >&2; exit 2 ;;
    esac
done

say() { printf '[*] %s\n' "$*"; }
ok()  { printf '[+] %s\n' "$*"; }
die() { printf '[!] %s\n' "$*" >&2; exit 1; }

command -v xcodebuild >/dev/null 2>&1 || die "缺少 xcodebuild"
command -v zip >/dev/null 2>&1 || die "缺少 zip"

need_files=(
    "lara/kexploit/wzmem.h"
    "lara/kexploit/wzmem.m"
    "lara/kexploit/wzmem_partial.h"
    "lara/kexploit/wzesp.h"
    "lara/kexploit/wzesp.mm"
    "lara/kexploit/wz/KoiTypes.h"
    "lara/kexploit/wz/KoiProjection.h"
    "lara/kexploit/wz/KoiProjection.mm"
    "lara/kexploit/wz/YuanbaoCollector.h"
    "lara/kexploit/wz/YuanbaoCollector.mm"
    "lara/kexploit/wz/WZAXActorCache.h"
    "lara/kexploit/wz/WZAXMonsterPolicy.h"
    "lara/kexploit/wz/WZAXTouch.h"
    "lara/kexploit/wz/WZAXTouch.mm"
    "lara/kexploit/WZAXFeatureRules.h"
    "lara/kexploit/WZHUDBridge.h"
    "lara/kexploit/WZHUDBridge.mm"
    "lara/kexploit/Partial.h"
    "lara/kexploit/Partial.m"
    "lara/Rajdhani Bold.otf"
    "lara/AXReference.bundle/Assets.car"
    "lara/AppIcon60x60@2x.png"
    "lara/AppIcon76x76@2x~ipad.png"
    "lara/classes/laramgr.swift"
)
for file in "${need_files[@]}"; do
    [[ -f "$ROOT/$file" ]] || die "缺文件：$file"
done

grep -q 'wzesp.h' "$ROOT/lara/lara-Bridging-Header.h" \
    || die "Swift 桥接头没有 wzesp.h"
grep -q 'wz_find_image_base' "$ROOT/lara/classes/laramgr.swift" \
    || die "laramgr 未按 UUID 定位 UnityFramework"
grep -q 'smoba' "$ROOT/lara/classes/laramgr.swift" \
    || die "laramgr 未绑定 smoba"
grep -q 'wzesp_tick' "$ROOT/lara/classes/laramgr.swift" \
    || die "王者只读采集未接入 worker"
grep -q 'wz_read' "$ROOT/lara/kexploit/wz/YuanbaoCollector.mm" \
    || die "王者采集器未接统一 transport"
grep -q 'wz_read' "$ROOT/lara/kexploit/wz/KoiProjection.mm" \
    || die "王者投影未接统一 transport"

rm -rf "$DERIVED"
mkdir -p "$ROOT/build"
SOURCE_COMMIT=$(git rev-parse --short=12 HEAD 2>/dev/null || echo nogit)
say "构建 lara-wz ($CONFIG)..."
set +e
xcodebuild \
    -project "$ROOT/$APP.xcodeproj" \
    -scheme "$APP" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED" \
    -destination 'generic/platform=iOS' \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_ENTITLEMENTS="" \
    CODE_SIGNING_ALLOWED=NO \
    clean build 2>&1 | tee "$ROOT/build/xcodebuild-wz.log" | tail -40
status=${PIPESTATUS[0]}
set -e
if [[ $status -ne 0 ]]; then
    grep -nE '(^|[[:space:]])(fatal )?error:' \
        "$ROOT/build/xcodebuild-wz.log" | tail -120 || true
    die "xcodebuild 失败，见 build/xcodebuild-wz.log"
fi

SRC_APP="$DERIVED/Build/Products/$CONFIG-iphoneos/$APP.app"
BIN="$SRC_APP/$APP"
[[ -f "$BIN" ]] || die "构建后未找到 $BIN"
INFO_PLIST="$SRC_APP/Info.plist"
[[ -f "$INFO_PLIST" ]] || die "构建后未找到 Info.plist"

say "使用 AX 本地双窗口权限签名 App（纯进程内托管，无 SpringBoard 注入）..."
ldid -S"$ROOT/Config/lara.entitlements" "$BIN"
entitlements=$(ldid -e "$BIN")
grep -q 'com.apple.QuartzCore.displayable-context' <<<"$entitlements" \
    || die "主 executable 签名缺少 displayable-context"
grep -q 'com.apple.springboard.accessibility-window-hosting' <<<"$entitlements" \
    || die "主 executable 签名缺少 accessibility-window-hosting"
/usr/libexec/PlistBuddy -c 'Delete :LARABuildSourceCommit' "$INFO_PLIST" \
    >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :LARABuildSourceCommit string $SOURCE_COMMIT" \
    "$INFO_PLIST"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LARABuildSourceCommit' "$INFO_PLIST")" == "$SOURCE_COMMIT" ]] \
    || die "Info.plist 未写入源码提交标识"

for object in wzmem.o wzesp.o KoiProjection.o YuanbaoCollector.o WZAXTouch.o WZHUDBridge.o laramgr.o; do
    find "$DERIVED" -name "$object" -print -quit | grep -q . \
        || die "$object 未参与编译"
done

LARAMGR_OBJ=$(find "$DERIVED" -name 'laramgr.o' -print -quit)
LC_ALL=C grep -a -q 'wzesp_tick' "$LARAMGR_OBJ" \
    || die "laramgr.o 未引用 wzesp_tick"
LC_ALL=C grep -a -q 'wz_find_image_base' "$LARAMGR_OBJ" \
    || die "laramgr.o 未引用 UnityFramework 精确定位"
LC_ALL=C grep -a -q 'mach-task-readonly' "$BIN" \
    || die "最终二进制没有 Mach task 只读 backend"
LC_ALL=C grep -a -q 'lara.wz.local-hud' "$BIN" \
    || die "最终二进制没有王者托管 HUD"
LC_ALL=C grep -a -q '_setAllWindowsKeepContextInBackground:' "$BIN" \
    && die "最终二进制仍混入不属于 QXA105 菜单链的全局窗口策略"
for marker in WZHUDDrawWindow \
    WZHUDMenuWindow \
    BackBoardServices.framework/BackBoardServices \
    setDisableUpdateMask: \
    IOHIDEventSystemClientDispatchEvent \
    "local-hosting ready (system-window)" \
    "hosting-probe" \
    "(xpf) 字典入口" \
    "(offs) XPF 未能给出 T1SZ_BOOT" \
    "(partial) 目标成员" \
    Rajdhani-Bold; do
    LC_ALL=C grep -a -q -- "$marker" "$BIN" \
        || die "最终二进制缺少 AX 本地双窗口标记：$marker"
done
# 已归档/删除的 SpringBoard 跨进程路径不得回到二进制里。
for forbidden in --wzhud-host posix_spawn direct_remote_ WZHUDFloatWindow \
    SBMainWorkspace \
    SBSAccessibilityWindowHostingController \
    registerWindowWithContextID:atLevel: \
    unregisterWindowWithContextID:atLevel: \
    "AX hosting class ready" \
    "springboard dual-host ready"; do
    LC_ALL=C grep -a -q -- "$forbidden" "$BIN" \
        && die "最终二进制仍混入已删除的 HUD 路径：$forbidden"
done
[[ -f "$SRC_APP/Rajdhani Bold.otf" ]] \
    || die "最终 App 未包含 AX Rajdhani 字体"
[[ "$(shasum -a 256 "$SRC_APP/Rajdhani Bold.otf" | awk '{print $1}')" == \
   "03d4c893f1406cb68cf0c26c1c3112f2758e5e836d7b9cd3825b974f452ff261" ]] \
    || die "AX Rajdhani 字体摘要不一致"
[[ -f "$SRC_APP/AXReference.bundle/Assets.car" ]] \
    || die "最终 App 未包含 AX 原始资源 catalog"
[[ "$(shasum -a 256 "$SRC_APP/AXReference.bundle/Assets.car" | awk '{print $1}')" == \
   "214c984a048adf3131f39afd95fc883a4f9edef48a08feccb51bd2beb63bf4cb" ]] \
    || die "AX 原始资源 catalog 摘要不一致"
[[ "$(shasum -a 256 "$SRC_APP/AppIcon60x60@2x.png" | awk '{print $1}')" == \
   "b5b43be770b6514384393dee2d0ceca9aac9476fb32283d8d719f18525fdf2d0" ]] \
    || die "AX iPhone 图标摘要不一致"
[[ "$(shasum -a 256 "$SRC_APP/AppIcon76x76@2x~ipad.png" | awk '{print $1}')" == \
   "67d418de12c8c9521a80c6bab887ae56e9e00df757f2c0d4befb5b5d23832792" ]] \
    || die "AX iPad 图标摘要不一致"

WZ_UUID="6a838f46-a5e8-3ec9-bbce-6b01ab2ffad4"
FINGERPRINT=$(shasum -a 256 \
    "$ROOT/lara/kexploit/wzmem.m" \
    "$ROOT/lara/kexploit/wzesp.mm" \
    "$ROOT/lara/kexploit/wz/YuanbaoCollector.mm" \
    "$ROOT/lara/classes/laramgr.swift" | shasum -a 256 | awk '{print substr($1,1,12)}')
PACKAGE_STEM="lara-wz-${SOURCE_COMMIT}-${FINGERPRINT}-${WZ_UUID}"
STAGE="$ROOT/build/package-wz"
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload"
cp -R "$SRC_APP" "$STAGE/Payload/$APP.app"
(cd "$STAGE" && zip -qry "$ROOT/$PACKAGE_STEM.ipa" Payload)

cat > "$ROOT/$PACKAGE_STEM.json" <<JSON
{
  "targetProcess": "smoba",
  "targetBundle": "com.tencent.smoba",
  "targetVersion": "11.4.10103",
  "unityFrameworkUUID": "$WZ_UUID",
  "sourceCommit": "$SOURCE_COMMIT",
  "sourceFingerprint": "$FINGERPRINT",
  "transportPolicy": "mach-task-readonly-or-mapped-pages",
  "writeFeaturesEnabled": false
}
JSON

ok "输出：$PACKAGE_STEM.ipa"
ok "清单：$PACKAGE_STEM.json"
