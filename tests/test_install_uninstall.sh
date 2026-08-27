#!/usr/bin/env bash
# Install / uninstall round-trip in isolated temp dirs (never touches real ~/.local).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  ✔ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✖ $1"; FAIL=$((FAIL + 1)); }

write_wrapper() {
  local dest="$1" target="$2"
  cat >"$dest" <<EOF
#!/usr/bin/env bash
exec "$target" "\$@"
EOF
  chmod +x "$dest"
}

echo "Install / uninstall"
echo "───────────────────"

TMP="$(mktemp -d -t mango-install-test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

export MANGO_BIN_DIR="$TMP/bin"
export MANGO_INSTALL_DIR="$TMP/share/mango"
export HOME="$TMP/home"
mkdir -p "$MANGO_BIN_DIR" "$MANGO_INSTALL_DIR/bin" "$HOME"
# Fake install tree (minimal)
cp "$ROOT/bin/mango" "$MANGO_INSTALL_DIR/bin/mango"
cp "$ROOT/bin/mango-doctor" "$MANGO_INSTALL_DIR/bin/mango-doctor"
cp "$ROOT/bin/jpg-to-pdf" "$MANGO_INSTALL_DIR/bin/jpg-to-pdf"
cp "$ROOT/uninstall.sh" "$MANGO_INSTALL_DIR/uninstall.sh"
chmod +x "$MANGO_INSTALL_DIR/bin/"* "$MANGO_INSTALL_DIR/uninstall.sh"
mkdir -p "$MANGO_INSTALL_DIR/lib"
# wrappers like setup.sh
write_wrapper "$MANGO_BIN_DIR/mango" "$MANGO_INSTALL_DIR/bin/mango"
write_wrapper "$MANGO_BIN_DIR/mango-doctor" "$MANGO_INSTALL_DIR/bin/mango-doctor"
write_wrapper "$MANGO_BIN_DIR/jpg-to-pdf" "$MANGO_INSTALL_DIR/bin/jpg-to-pdf"
# decoy non-mango binary must survive
echo '#!/bin/sh' >"$MANGO_BIN_DIR/unrelated-tool"
echo 'echo hi' >>"$MANGO_BIN_DIR/unrelated-tool"
chmod +x "$MANGO_BIN_DIR/unrelated-tool"
# PATH block in fake zshrc
cat >"$HOME/.zshrc" <<EOF
# stuff
# mango tools PATH
export PATH="\$PATH:$MANGO_BIN_DIR"
# more stuff
EOF

# Also a clone-style wrapper pointing at tools/bin
write_wrapper "$MANGO_BIN_DIR/format-json" "$ROOT/bin/format-json"

[[ -x "$MANGO_BIN_DIR/mango" ]] && pass "wrappers installed" || fail "wrappers missing after install sim"

# keep-data: wrappers gone, install remains, decoy remains, path stripped
MANGO_BIN_DIR="$MANGO_BIN_DIR" MANGO_INSTALL_DIR="$MANGO_INSTALL_DIR" HOME="$HOME" \
  "$ROOT/uninstall.sh" --yes --keep-data --no-path >/dev/null

if [[ ! -e "$MANGO_BIN_DIR/mango" && ! -e "$MANGO_BIN_DIR/jpg-to-pdf" && ! -e "$MANGO_BIN_DIR/format-json" ]]; then
  pass "keep-data removed mango wrappers"
else
  fail "keep-data left mango wrappers behind"
fi
[[ -x "$MANGO_BIN_DIR/unrelated-tool" ]] && pass "keep-data left unrelated binaries" || fail "keep-data deleted unrelated binary"
[[ -d "$MANGO_INSTALL_DIR" ]] && pass "keep-data kept install dir" || fail "keep-data deleted install dir"

# reinstall wrappers
write_wrapper "$MANGO_BIN_DIR/mango" "$MANGO_INSTALL_DIR/bin/mango"
write_wrapper "$MANGO_BIN_DIR/mango-doctor" "$MANGO_INSTALL_DIR/bin/mango-doctor"
write_wrapper "$MANGO_BIN_DIR/jpg-to-pdf" "$MANGO_INSTALL_DIR/bin/jpg-to-pdf"
cat >"$HOME/.zshrc" <<EOF
# mango tools PATH
export PATH="\$PATH:$MANGO_BIN_DIR"
EOF

# purge via mango uninstall subcommand
MANGO_BIN_DIR="$MANGO_BIN_DIR" MANGO_INSTALL_DIR="$MANGO_INSTALL_DIR" HOME="$HOME" \
  "$MANGO_INSTALL_DIR/bin/mango" uninstall --purge >/dev/null

if [[ ! -e "$MANGO_BIN_DIR/mango" && ! -e "$MANGO_BIN_DIR/jpg-to-pdf" ]]; then
  pass "purge removed wrappers"
else
  fail "purge left wrappers"
fi
[[ -x "$MANGO_BIN_DIR/unrelated-tool" ]] && pass "purge left unrelated binaries" || fail "purge deleted unrelated binary"
if [[ ! -d "$MANGO_INSTALL_DIR" ]]; then
  pass "purge deleted install dir"
else
  fail "purge left install dir"
fi
if ! grep -q 'mango tools PATH' "$HOME/.zshrc" 2>/dev/null; then
  pass "purge stripped PATH block from shell rc"
else
  fail "purge left PATH block in shell rc"
fi

# mango help should not need a TTY
if out="$("$ROOT/bin/mango" help 2>&1)"; then
  echo "$out" | grep -q 'uninstall' && pass "mango help lists uninstall" || fail "mango help missing uninstall"
else
  fail "mango help failed"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
