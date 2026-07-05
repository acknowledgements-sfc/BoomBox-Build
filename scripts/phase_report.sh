#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <from-tag>" >&2
  echo "Example: $(basename "$0") phase-0-start" >&2
  exit 1
fi

FROM_TAG="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAN="$ROOT/PARKJUKEBOX_BUILD_PLAN.md"

if [[ ! -f "$PLAN" ]]; then
  PLAN="$ROOT/docs/PARKJUKEBOX_BUILD_PLAN.md"
fi

cd "$ROOT"

if ! git rev-parse "$FROM_TAG" >/dev/null 2>&1; then
  echo "ERROR: tag or ref '$FROM_TAG' not found." >&2
  exit 1
fi

echo "ParkJukebox Phase Report"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Range: ${FROM_TAG}..HEAD"
echo "Branch: $(git branch --show-current)"
echo ""

echo "==> Commits"
git log --oneline "${FROM_TAG}..HEAD" || echo "(no commits in range)"
echo ""

echo "==> Diff stat"
git diff --stat "${FROM_TAG}..HEAD" || true
echo ""

echo "==> Build and test"
BUILD_LOG="$(mktemp)"
trap 'rm -f "$BUILD_LOG"' EXIT

set +e
"$ROOT/scripts/build_check.sh" 2>&1 | tee "$BUILD_LOG"
BUILD_EXIT=$?
set -e

if [[ "$BUILD_EXIT" -eq 0 ]]; then
  echo ""
  echo "Build/test gate: PASS"
else
  echo ""
  echo "Build/test gate: FAIL (exit $BUILD_EXIT)"
fi
echo ""

echo "==> Open HITL checklist items"
PHASE_NUM="${2:-}"
if [[ -z "$PHASE_NUM" ]] && [[ "$(git branch --show-current)" =~ phase-([0-9]+) ]]; then
  PHASE_NUM="${BASH_REMATCH[1]}"
fi

if [[ -f "$PLAN" ]]; then
  awk -v phase_num="$PHASE_NUM" '
    /^## 3\. Owner-only/ { in_owner = 1; next }
    /^## [0-9]+\./ { in_owner = 0 }
    in_owner && /^- \[ \]/ { print "Global: " $0 }
    phase_num != "" && $0 ~ "^### Phase " phase_num " " { in_phase = 1; phase = $0; next }
    phase_num != "" && $0 ~ "^### Phase " phase_num " —" { in_phase = 1; phase = $0; next }
    /^### Phase [0-9]+/ { in_phase = 0 }
    in_phase && /^- \[ \]/ { print phase ": " $0 }
  ' "$PLAN" | sort -u
  if [[ -z "$(awk -v phase_num="$PHASE_NUM" '
    /^## 3\. Owner-only/ { in_owner = 1; next }
    /^## [0-9]+\./ { in_owner = 0 }
    in_owner && /^- \[ \]/ { print "x" }
    phase_num != "" && $0 ~ "^### Phase " phase_num " " { in_phase = 1; next }
    phase_num != "" && $0 ~ "^### Phase " phase_num " —" { in_phase = 1; next }
    /^### Phase [0-9]+/ { in_phase = 0 }
    in_phase && /^- \[ \]/ { print "x" }
  ' "$PLAN")" ]]; then
    echo "(none for current phase)"
  fi
else
  echo "(plan file not found)"
fi

exit "$BUILD_EXIT"
