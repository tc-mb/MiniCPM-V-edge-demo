#!/usr/bin/env bash
# 一键 iOS UI 自动化测试脚本
#
# 用法:
#   bash scripts/run_uitest.sh sim                   # 跑模拟器（默认）
#   bash scripts/run_uitest.sh device                # 跑真机（自动选第一台已连接 iOS 设备）
#   bash scripts/run_uitest.sh device <test_method>  # 只跑某个测试方法
#
# 环境变量（可选）:
#   SIM_ID             模拟器 UDID（不设则用 xcrun simctl 第一台已开机/可用的 iPhone）
#   DEVICE_ID          真机 ECID/UDID（不设则用 xcodebuild -showdestinations 第一台 iOS 真机）
#   DEVELOPMENT_TEAM   真机签名 Team ID（真机测试必填）
#
# 跑完会自动：
#   1) 把 .xcresult 里的截屏导出到 build/screenshots_<mode>/
#   2) 生成 build/REPORT_<mode>.md 简短报告

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

MODE="${1:-sim}"
# 第二个参数：可选，特定 test 方法名（不填则跑全部 test）
ONLY_TEST="${2:-}"

# 自动选择默认 SIM_ID / DEVICE_ID（仅当未指定时）
if [ -z "${SIM_ID:-}" ]; then
  SIM_ID="$(xcrun simctl list devices available 2>/dev/null \
              | awk '/iPhone/ && match($0, /\(([0-9A-F-]{36})\)/, m) { print m[1]; exit }')"
fi

if [ -z "${DEVICE_ID:-}" ]; then
  DEVICE_ID="$(xcrun xctrace list devices 2>/dev/null \
                 | awk '/iPhone|iPad/ && !/Simulator/ && match($0, /\(([0-9A-Fa-f-]+)\)$/, m) { print m[1]; exit }')"
fi

if [ "$MODE" = "device" ]; then
  if [ -z "${DEVICE_ID:-}" ]; then
    echo "[run_uitest] ERROR: 未检测到已连接的 iOS 真机；请先连接设备或显式设置 DEVICE_ID。" >&2
    exit 2
  fi
  if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
    echo "[run_uitest] ERROR: 真机测试需要 DEVELOPMENT_TEAM=<你的 Team ID>。" >&2
    exit 2
  fi
  DEST="platform=iOS,id=$DEVICE_ID"
  DERIVED_DATA="build/uitest"
  RESULT_BUNDLE="build/uitest_result.xcresult"
  EXTRA_ARGS=(CODE_SIGN_STYLE=Automatic "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
elif [ "$MODE" = "sim" ]; then
  if [ -z "${SIM_ID:-}" ]; then
    echo "[run_uitest] ERROR: 未发现可用 iPhone 模拟器；请用 xcrun simctl create 创建一个，或显式设置 SIM_ID。" >&2
    exit 2
  fi
  DEST="platform=iOS Simulator,id=$SIM_ID"
  DERIVED_DATA="build/uitest_sim"
  RESULT_BUNDLE="build/uitest_sim_result.xcresult"
  EXTRA_ARGS=(CODE_SIGNING_ALLOWED=NO)

  if ! xcrun simctl list devices booted | grep -q "$SIM_ID"; then
    echo "[run_uitest] booting simulator $SIM_ID ..."
    xcrun simctl boot "$SIM_ID" || true
    open -a Simulator
    sleep 5
  fi
else
  echo "Usage: $0 <sim|device> [test_method]" >&2
  exit 2
fi

echo "[run_uitest] destination = $DEST"
echo "[run_uitest] step 1/3: build-for-testing"
mkdir -p "$DERIVED_DATA"
xcodebuild build-for-testing \
  -project MiniCPM-V-demo.xcodeproj \
  -scheme MiniCPM-V-demo \
  -configuration Debug \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED_DATA" \
  "${EXTRA_ARGS[@]}" \
  >> "$DERIVED_DATA/build.log" 2>&1

echo "[run_uitest] step 2/3: test-without-building"
rm -rf "$RESULT_BUNDLE"
set +e
TEST_FILTER_ARGS=()
if [ -n "$ONLY_TEST" ]; then
  TEST_FILTER_ARGS=( -only-testing:"MiniCPM-V-demoUITests/MiniCPMVDemoUITests/${ONLY_TEST}" )
else
  TEST_FILTER_ARGS=( -only-testing:"MiniCPM-V-demoUITests/MiniCPMVDemoUITests" )
fi
xcodebuild test-without-building \
  -project MiniCPM-V-demo.xcodeproj \
  -scheme MiniCPM-V-demo \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED_DATA" \
  -resultBundlePath "$RESULT_BUNDLE" \
  "${TEST_FILTER_ARGS[@]}" \
  "${EXTRA_ARGS[@]}" \
  | tee "$DERIVED_DATA/run.log"
TEST_EXIT=$?
set -e

echo "[run_uitest] step 3/3: export screenshots from $RESULT_BUNDLE"
SHOTS_DIR="build/screenshots_${MODE}"
rm -rf "$SHOTS_DIR"
mkdir -p "$SHOTS_DIR"
xcrun xcresulttool export attachments --path "$RESULT_BUNDLE" --output-path "$SHOTS_DIR" >/dev/null 2>&1

cd "$SHOTS_DIR"
python3 - <<'PY'
import json, os, shutil
data = json.load(open('manifest.json'))
inner = data[0]['attachments']
print(f'  found {len(inner)} attachments')
for item in inner:
    src = item.get('exportedFileName')
    dst = item.get('suggestedHumanReadableName', src)
    if not src or not os.path.exists(src):
        continue
    dst = dst.replace('/', '_').replace(' ', '_')
    if not (dst.endswith('.png') or dst.endswith('.mp4') or dst.endswith('.txt') or dst.endswith('.jpg')):
        ext = os.path.splitext(src)[1] or '.bin'
        dst = dst + ext
    if dst != src and not os.path.exists(dst):
        shutil.copy(src, dst)
PY
cd "$ROOT"

# 生成简易报告
REPORT="build/REPORT_${MODE}.md"
{
  echo "# MiniCPM-V iOS Demo · UI 自动化测试报告 ($MODE)"
  echo
  echo "- 时间: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- destination: \`$DEST\`"
  echo "- result bundle: \`$RESULT_BUNDLE\`"
  echo "- 截图目录: \`$SHOTS_DIR/\`"
  echo "- 测试退出码: $TEST_EXIT"
  echo
  echo "## 截图列表（按步骤排序）"
  echo
  for f in $(cd "$SHOTS_DIR" && ls *.png 2>/dev/null | grep -E "^[0-9]{2}[a-z]?_" | sort); do
    name=$(echo "$f" | sed -E 's/_[0-9]+_[A-F0-9-]{36}\.png$//')
    echo "- \`$name\` → $f"
  done
} > "$REPORT"

echo
echo "[run_uitest] DONE."
echo "  report:   $REPORT"
echo "  shots:    $SHOTS_DIR"
echo "  exit:     $TEST_EXIT"
exit $TEST_EXIT
