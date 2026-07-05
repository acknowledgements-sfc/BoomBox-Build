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
if [[ -f "$PLAN" ]]; then
  awk '
    /^### Phase [0-9]+ / { in_phase = 1; phase = $0; next }
    /^### Phase [0-9]+ —/ { in_phase = 1; phase = $0; next }
    /^## [0-9]+\./ { if ($0 !~ /^## [0-9]+\. Owner-only/) in_phase = 0 }
    /^---$/ && in_phase { in_phase = 0 }
    in_phase && /^- \[ \]/ { print phase ": " $0 }
    /^- \[ \] \*\*H[0-9]+\.\*\*/ { print "Global: " $0 }
  ' "$PLAN" | sort -u
else
  echo "(plan file not found)"
fi

exit "$BUILD_EXIT"
