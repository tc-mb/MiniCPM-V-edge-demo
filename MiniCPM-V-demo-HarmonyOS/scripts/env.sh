#!/usr/bin/env bash
# Source this file from other scripts so they share the same toolchain
# resolution rules.  Intended for macOS where DevEco Studio is installed
# in the standard /Applications location.

DEVECO_BASE="${DEVECO_BASE:-/Applications/DevEco-Studio.app/Contents}"

if [ ! -d "$DEVECO_BASE" ]; then
  echo "[env.sh] DevEco Studio not found at $DEVECO_BASE" >&2
  echo "[env.sh] Please install DevEco Studio or override DEVECO_BASE." >&2
  return 1 2>/dev/null || exit 1
fi

export NODE_HOME="${NODE_HOME:-$DEVECO_BASE/tools/node}"
export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-$DEVECO_BASE/sdk}"
export JAVA_HOME="${JAVA_HOME:-$DEVECO_BASE/jbr/Contents/Home}"

export OHOS_BASE_SDK_HOME="$DEVECO_SDK_HOME/default/openharmony"
export HVIGORW="$DEVECO_BASE/tools/hvigor/bin/hvigorw"
export OHPM="$DEVECO_BASE/tools/ohpm/bin/ohpm"
export HDC="$OHOS_BASE_SDK_HOME/toolchains/hdc"
export PATH="$JAVA_HOME/bin:$DEVECO_BASE/tools/ohpm/bin:$NODE_HOME/bin:$OHOS_BASE_SDK_HOME/toolchains:$PATH"
