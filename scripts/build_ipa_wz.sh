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
    "lara/kexploit/wz/YuanbaoIdentityPolicy.h"
    "lara/kexploit/wz/YuanbaoCollector.h"
    "lara/kexploit/wz/YuanbaoCollector.mm"
    "lara/kexploit/wz/WZYuanbaoDrawPolicy.h"
    "lara/kexploit/WZHUDBridge.h"
    "lara/kexploit/WZHUDBridge.mm"
    "lara/heroatlas.bin"
    "lara/core-mountain.png"
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

HUD_HELPER="$SRC_APP/WZHUDHostHelper"
say "编译独立 HUD context 托管 helper..."
xcrun --sdk iphoneos clang \
    -arch arm64 \
    -miphoneos-version-min=15.0 \
    -fobjc-arc -fmodules \
    "$ROOT/scripts/WZHUDHostHelper.m" \
    -framework Foundation -framework UIKit \
    -o "$HUD_HELPER"
chmod 0755 "$HUD_HELPER"

say "使用 TrollSpeed/assistivetouchd 权限签名 App 与 HUD helper..."
ldid -S"$ROOT/Config/lara.entitlements" "$BIN"
ldid -S"$ROOT/Config/lara.entitlements" "$HUD_HELPER"
for signed in "$BIN" "$HUD_HELPER"; do
    entitlements=$(ldid -e "$signed")
    grep -q 'com.apple.QuartzCore.displayable-context' <<<"$entitlements" \
        || die "签名缺少 displayable-context：$signed"
    grep -q 'com.apple.springboard.accessibility-window-hosting' <<<"$entitlements" \
        || die "签名缺少 accessibility-window-hosting：$signed"
done
/usr/libexec/PlistBuddy -c 'Delete :LARABuildSourceCommit' "$INFO_PLIST" \
    >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :LARABuildSourceCommit string $SOURCE_COMMIT" \
    "$INFO_PLIST"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LARABuildSourceCommit' "$INFO_PLIST")" == "$SOURCE_COMMIT" ]] \
    || die "Info.plist 未写入源码提交标识"

for object in wzmem.o wzesp.o KoiProjection.o YuanbaoCollector.o WZHUDBridge.o laramgr.o; do
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
LC_ALL=C grep -a -q 'visual=draw/input=control contextValidation=450ms' "$BIN" \
    || die "最终二进制没有 Core 绘制/输入分层"
LC_ALL=C grep -a -q '_setAllWindowsKeepContextInBackground:' "$BIN" \
    && die "最终二进制仍混入不属于 QXA105 菜单链的全局窗口策略"
for marker in setDisableUpdateMask: \
    _contextId \
    firstCommitContent= \
    sceneState=active \
    WZHUDHostHelper \
    hosting=ready\ target=helper \
    noRemoteCall=1 \
    hosted-ca; do
    LC_ALL=C grep -a -q "$marker" "$BIN" \
        || die "最终二进制缺少王者 HUD 标记：$marker"
done
for marker in SBSAccessibilityWindowHostingController \
    registerWindowWithContextID:atLevel: \
    unregisterWindowWithContextID:; do
    LC_ALL=C grep -a -q "$marker" "$HUD_HELPER" \
        || die "HUD helper 缺少 context 托管标记：$marker"
done
LC_ALL=C grep -a -q 'direct-input=' "$BIN" \
    && die "最终二进制仍混入会导致 SpringBoard 重载的远端输入轮询"
[[ -f "$SRC_APP/heroatlas.bin" ]] \
    || die "最终 App 未包含英雄头像图集"
[[ -f "$SRC_APP/core-mountain.png" ]] \
    || die "最终 App 未包含 Core 启动页山景资产"

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
