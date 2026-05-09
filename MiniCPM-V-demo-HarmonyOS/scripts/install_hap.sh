#!/usr/bin/env bash
# Install the most recent hap onto the first connected device.  Assumes
# DevEco Studio has already produced *signed* hap output (this happens
# automatically when the IDE has run "Automatically generate signature"
# at least once for this project).
#
# If only an unsigned hap is found, this script prints the steps required
# to enable command-line signing.

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$THIS_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$THIS_DIR/env.sh"

OUT="$PROJECT_ROOT/entry/build/default/outputs/default"
SIGNED_HAP="$(ls "$OUT"/*signed*.hap 2>/dev/null | grep -v unsigned | head -n 1 || true)"
UNSIGNED_HAP="$(ls "$OUT"/*unsigned*.hap 2>/dev/null | head -n 1 || true)"

DEVICE="$($HDC list targets | head -n 1 | awk '{print $1}')"
if [ -z "$DEVICE" ] || [ "$DEVICE" = "[Empty]" ]; then
  echo "[install_hap.sh] No device connected.  Plug in your phone and enable USB debugging." >&2
  exit 1
fi
echo ">>> Target device: $DEVICE"

if [ -n "$SIGNED_HAP" ]; then
  echo ">>> Installing signed hap: $SIGNED_HAP"
  "$HDC" -t "$DEVICE" install -r "$SIGNED_HAP"
  exit 0
fi

if [ -n "$UNSIGNED_HAP" ]; then
  cat <<EOF
[install_hap.sh] Only an unsigned hap is available:
    $UNSIGNED_HAP

HarmonyOS NEXT does not allow side-loading unsigned haps.  To proceed:

  1. Open the project in DevEco Studio:
     open -a "DevEco-Studio" "$PROJECT_ROOT"

  2. File > Project Structure > Signing Configs:
     check "Automatically generate signature" (login Huawei account once).

  3. Run > Run 'entry' once.  This produces a signed hap and the
     signing material is cached at ~/.ohos/config/auto_signing/.

  4. Future iterations can use the command line:
     $THIS_DIR/build_hap.sh && $THIS_DIR/install_hap.sh
EOF
  exit 1
fi

echo "[install_hap.sh] No hap found in $OUT.  Run build_hap.sh first." >&2
exit 1
