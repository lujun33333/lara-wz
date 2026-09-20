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

# ── 从源码构建 libxpf.dylib ──────────────────────────────────────────────────
# lara/lib/libxpf.dylib 曾经是一个提交进 git 的预编译二进制（2026-09-05），
# 早于 XPF 的 "Fix some metrics not working on higher versions of iOS 26 and on
# iOS 27 betas" 提交。旧版没有 arm_maxoffset 这条 fallback，于是
# xpf_find_pmap_bootstrap 的字符串查找失败、XPF_ASSERT 直接终止，
# pointer_mask 与 T1SZ_BOOT 都拿不到 —— 内核注入层的 call primitive 与
# task port 随之全部失效。这里改为每次构建都从 vendor/XPF 源码编译，
# 保证「修好的源码」真的进入出货二进制。
say "从源码构建 libxpf.dylib ..."
XPF_DIR="$ROOT/vendor/XPF"
[ -f "$XPF_DIR/src/common.c" ] || die "缺少 vendor/XPF/src"
[ -f "$XPF_DIR/Makefile" ]     || die "缺少 vendor/XPF/Makefile"
# AX 1.2.8 的入口只接收 kernelcache。Lara 侧同样只传一个参数，因此在编译
# 出货 dylib 前强制核对声明、实现和全部调用，禁止再次混入三参数 ABI。
XPF_SINGLE_DECL='int xpf_start_with_kernel_path(const char *kernelPath);'
LC_ALL=C grep -Fqx -- "$XPF_SINGLE_DECL" "$ROOT/lara/headers/xpf.h" \
    || die "Lara 的 XPF 声明不是 AX 1.2.8 单参数 ABI"
LC_ALL=C grep -Fqx -- "$XPF_SINGLE_DECL" "$XPF_DIR/src/xpf.h" \
    || die "vendor/XPF 的公开声明不是 AX 1.2.8 单参数 ABI"
LC_ALL=C grep -Fqx -- 'int xpf_start_with_kernel_path(const char *kernelPath)' "$XPF_DIR/src/xpf.c" \
    || die "vendor/XPF 的实现不是 AX 1.2.8 单参数 ABI"
if LC_ALL=C grep -nE 'xpf_start_with_kernel_path[[:space:]]*\([^)]*,' \
        "$ROOT/lara/headers/xpf.h" \
        "$ROOT/lara/kexploit/offsets.m" \
        "$ROOT/lara/kexploit/utils.m" \
        "$XPF_DIR/src/xpf.h" \
        "$XPF_DIR/src/xpf.c" \
        "$XPF_DIR/src/cli/main.c"; then
    die "检测到多参数 xpf_start_with_kernel_path，拒绝构建 ABI 混用产物"
fi
# Lara 会直接读取导出全局 gXPF 的字段；两份头文件的结构体必须逐字段一致。
# 2026-09-20 曾因 Lara 仍把 firstItem 当成 +0x110、而 dylib 已移到 +0x1a8，
# 将 kernelSandboxAuthStubSection 误作链表头并在 Mach-O 魔数地址上崩溃。
python3 - "$ROOT/lara/headers/xpf.h" "$XPF_DIR/src/xpf.h" <<'PY' \
    || die "Lara 与 vendor/XPF 的 gXPF 结构布局不一致"
import pathlib
import re
import sys

def struct_body(path):
    text = pathlib.Path(path).read_text(encoding="utf-8")
    match = re.search(r"typedef\s+struct\s+s_XPF\s*\{(.*?)\}\s*XPF\s*;", text, re.S)
    if not match:
        raise SystemExit(f"找不到 XPF 结构体: {path}")
    body = re.sub(r"/\*.*?\*/|//[^\r\n]*", "", match.group(1), flags=re.S)
    return re.sub(r"\s+", " ", body).strip()

if struct_body(sys.argv[1]) != struct_body(sys.argv[2]):
    raise SystemExit("gXPF layout mismatch")
PY
if [ ! -d "$XPF_DIR/external/ChOma/src" ]; then
    say "拉取 ChOma 子模块 ..."
    rm -rf "$XPF_DIR/external/ChOma"
    git clone --depth 1 https://github.com/opa334/ChOma \
        "$XPF_DIR/external/ChOma" >/dev/null 2>&1 || die "无法拉取 ChOma"
fi
command -v ldid >/dev/null 2>&1 || die "缺少 ldid（brew install ldid）"
mkdir -p "$ROOT/build"
if ! make -C "$XPF_DIR" output/ios/libxpf.dylib \
        >"$ROOT/build/xpf-build.log" 2>&1; then
    tail -40 "$ROOT/build/xpf-build.log" >&2
    die "libxpf 编译失败，见 build/xpf-build.log"
fi
cp "$XPF_DIR/output/ios/libxpf.dylib" "$ROOT/lara/lib/libxpf.dylib"
# 断言：出货 dylib 必须含 iOS 26 修复引入的 fallback，否则说明又编进了旧版。
LC_ALL=C grep -a -q -- "arm_maxoffset" "$ROOT/lara/lib/libxpf.dylib" \
    || die "libxpf.dylib 缺少 arm_maxoffset —— 仍会编译进旧版 XPF"
ok "libxpf.dylib 已由源码重建（含 arm_maxoffset）"

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
    "local-hosting draw/menu" \
    "hosting-probe" \
    create_local_hosting_controller \
    SBSAccessibilityWindowHostingController \
    registerWindowWithContextID:atLevel: \
    "SpringBoard CALayerHost ready" \
    "springboard dual-host ready" \
    "(xpf) 字典入口" \
    "(offs) XPF 未给出 T1SZ_BOOT" \
    "(xpf) 缺少 item" \
    "(partial) 目标成员" \
    Rajdhani-Bold; do
    LC_ALL=C grep -a -q -- "$marker" "$BIN" \
        || die "最终二进制缺少 AX 双窗口与托管标记：$marker"
done
# 真正退役的只有 helper / spawn / Core 三窗口这些；托管路径已按 AX 恢复，不得再列。
for forbidden in --wzhud-host posix_spawn direct_remote_ WZHUDFloatWindow; do
    LC_ALL=C grep -a -q -- "$forbidden" "$BIN" \
        && die "最终二进制仍混入已删除的 HUD 路径：$forbidden"
done

# 最终 App 内嵌的 libxpf 必须就是源码重建的那份（含 iOS 26 修复的 fallback）。
# 这条断言用于堵住「源码修了但出货二进制还是旧的」这一类静默复发。
XPF_EMBEDDED="$SRC_APP/Frameworks/libxpf.dylib"
[[ -f "$XPF_EMBEDDED" ]] || die "最终 App 未内嵌 libxpf.dylib"
LC_ALL=C grep -a -q -- "arm_maxoffset" "$XPF_EMBEDDED" \
    || die "内嵌 libxpf.dylib 缺少 arm_maxoffset —— 出货的是旧版 XPF"
[[ "$(shasum -a 256 "$XPF_EMBEDDED" | awk '{print $1}')" == \
   "$(shasum -a 256 "$ROOT/lara/lib/libxpf.dylib" | awk '{print $1}')" ]] \
    || die "内嵌 libxpf.dylib 与源码重建产物不一致"

# install name 必须让 dyld 找到 Frameworks/ 下的那份。
# 上游 XPF 的 Makefile 默认 -install_name @loader_path/libxpf.dylib；对主可执行文件
# 而言 @loader_path 是 lara.app/，会去找不存在的 lara.app/libxpf.dylib，
# 结果就是「打开即闪退，dyld: Library not loaded」。
LC_ALL=C grep -a -q -- "@loader_path/libxpf.dylib" "$BIN" \
    && die "主二进制以 @loader_path 引用 libxpf，运行时会解析到 lara.app/ 而非 Frameworks/"
LC_ALL=C grep -a -q -- "@executable_path/Frameworks/libxpf.dylib" "$BIN" \
    || die "主二进制未以 @executable_path/Frameworks/libxpf.dylib 引用 libxpf"
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
