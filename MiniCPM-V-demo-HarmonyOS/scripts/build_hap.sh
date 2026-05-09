#!/usr/bin/env bash
# Command-line build for the HarmonyOS demo.  Produces an *unsigned* hap
# under entry/build/default/outputs/default/.  Pair with install_hap.sh to
# sign + install onto a connected device (requires that DevEco Studio has
# already cached signing material via "Automatically generate signature").

set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$THIS_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$THIS_DIR/env.sh"

cd "$PROJECT_ROOT"

echo ">>> ohpm install (root + entry)"
"$OHPM" install --all >/dev/null
( cd entry && "$OHPM" install --all >/dev/null )

BUILD_MODE="${1:-debug}"

echo ">>> hvigorw assembleHap product=default buildMode=$BUILD_MODE"
bash "$HVIGORW" assembleHap \
  -p product=default \
  -p buildMode="$BUILD_MODE" \
  --no-daemon

HAP="$(ls "$PROJECT_ROOT"/entry/build/default/outputs/default/*.hap 2>/dev/null | head -n 1)"
if [ -z "$HAP" ]; then
  echo "[build_hap.sh] ERROR: no .hap produced." >&2
  exit 1
fi

echo ""
echo "OK: $(du -h "$HAP" | awk '{print $1}')  $HAP"
