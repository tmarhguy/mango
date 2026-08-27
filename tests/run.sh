#!/usr/bin/env bash
# Run all Mango tests — lint, unit, browse, smoke

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RUN_LINT=1
RUN_UNIT=1
RUN_BROWSE=1
RUN_SMOKE=1

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  echo ""
  echo "Options:"
  echo "  --lint-only    Run static analysis only"
  echo "  --unit-only    Run pytest only"
  echo "  --quick        Lint + unit + browse (skip smoke)"
  echo "  -h, --help     Show this help"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lint-only) RUN_UNIT=0; RUN_BROWSE=0; RUN_SMOKE=0; shift ;;
    --unit-only) RUN_LINT=0; RUN_BROWSE=0; RUN_SMOKE=0; shift ;;
    --quick) RUN_SMOKE=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

echo "Mango test suite"
echo "════════════════"

if [[ "$RUN_LINT" -eq 1 ]]; then
  echo ""
  "$ROOT/tests/lint.sh"
fi

if [[ "$RUN_UNIT" -eq 1 ]]; then
  echo ""
  echo "Unit tests (pytest)"
  echo "─────────────────"
  PY="$ROOT/.venv/bin/python"
  if [[ ! -x "$PY" ]]; then
    echo "  Creating venv..."
    python3 -m venv "$ROOT/.venv"
    PY="$ROOT/.venv/bin/python"
  fi
  "$PY" -m pip install -q -r "$ROOT/requirements.txt" -r "$ROOT/requirements-dev.txt"
  "$PY" -m pytest "$ROOT/tests/unit" -v --tb=short
fi

if [[ "$RUN_BROWSE" -eq 1 ]]; then
  echo ""
  "$ROOT/tests/test_browse.sh"
fi

if [[ "$RUN_SMOKE" -eq 1 ]]; then
  echo ""
  "$ROOT/tests/test_install_uninstall.sh"
  echo ""
  "$ROOT/tests/smoke.sh"
fi

echo ""
echo "All requested tests passed."
