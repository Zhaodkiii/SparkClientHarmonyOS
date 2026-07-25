#!/usr/bin/env bash
# HarmonyOS entry assembleHap — 使用 DevEco 自带 JBR，避免 macOS「Unable to locate a Java Runtime」。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVECO_APP="${DEVECO_APP:-/Applications/DevEco-Studio.app}"
DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-${DEVECO_APP}/Contents/sdk}"
JAVA_HOME="${JAVA_HOME:-${DEVECO_APP}/Contents/jbr/Contents/Home}"
HVIGORW="${HVIGORW:-${DEVECO_APP}/Contents/tools/hvigor/bin/hvigorw}"
NODE_BIN="${DEVECO_APP}/Contents/tools/node/bin"

if [[ ! -x "${JAVA_HOME}/bin/java" ]]; then
  echo "ERROR: Java not found at ${JAVA_HOME}/bin/java" >&2
  echo "Install DevEco Studio or set JAVA_HOME to a JDK 17+/21." >&2
  exit 1
fi

if [[ ! -x "${HVIGORW}" ]]; then
  echo "ERROR: hvigorw not found at ${HVIGORW}" >&2
  exit 1
fi

export DEVECO_SDK_HOME
export JAVA_HOME
export PATH="${JAVA_HOME}/bin:${NODE_BIN}:${DEVECO_APP}/Contents/tools/hvigor/bin:${PATH}"

cd "${ROOT}"
echo "JAVA_HOME=${JAVA_HOME}"
"${JAVA_HOME}/bin/java" -version
exec "${HVIGORW}" --mode module -p module=entry@default -p product=default assembleHap "$@"
