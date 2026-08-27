#!/usr/bin/env bash
# Mango uninstall — remove global commands and optional install directory
#
# Usage:
#   mango uninstall
#   mango uninstall --yes
#   mango uninstall --purge          # wrappers + install dir, no prompts
#   mango uninstall --keep-data      # wrappers only; keep ~/.local/share/mango
#   ./uninstall.sh                   # same flags from a clone
#
# Env overrides (for tests / custom installs):
#   MANGO_INSTALL_DIR   default: ~/.local/share/mango
#   MANGO_BIN_DIR       default: ~/.local/bin

set -euo pipefail

MANGO_INSTALL_DIR="${MANGO_INSTALL_DIR:-$HOME/.local/share/mango}"
MANGO_BIN_DIR="${MANGO_BIN_DIR:-$HOME/.local/bin}"

ASSUME_YES=0
KEEP_DATA=0
PURGE=0
SKIP_PATH_CLEAN=0
_INTERNAL_FINISH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1; shift ;;
    --keep-data) KEEP_DATA=1; shift ;;
    --purge) PURGE=1; ASSUME_YES=1; KEEP_DATA=0; shift ;;
    --no-path) SKIP_PATH_CLEAN=1; shift ;;
    --internal-finish) _INTERNAL_FINISH=1; shift ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

_mango_step() { echo ""; echo "==> $*"; }
_mango_info()  { echo "    $*"; }

_mango_confirm() {
  local prompt="$1"
  [[ "$ASSUME_YES" -eq 1 ]] && return 0
  printf '%s [y/N] ' "$prompt"
  local ans
  read -r ans
  case "$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')" in
    y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

# Match wrappers written by setup.sh:
#   #!/usr/bin/env bash
#   exec "/path/.../bin/<tool>" "$@"
_mango_is_mango_wrapper() {
  local path="$1"
  [[ -f "$path" && -r "$path" ]] || return 1
  grep -Eq 'exec[[:space:]]+"[^"]*/(share/mango|mango)/bin/[^"]+"|exec[[:space:]]+"[^"]*/tools/bin/[^"]+"' "$path" 2>/dev/null
}

_mango_remove_wrappers() {
  local removed=0 path name
  [[ -d "$MANGO_BIN_DIR" ]] || {
    _mango_info "No bin dir at $MANGO_BIN_DIR"
    return 0
  }

  shopt -s nullglob
  for path in "$MANGO_BIN_DIR"/*; do
    [[ -f "$path" || -L "$path" ]] || continue
    name="$(basename "$path")"
    if _mango_is_mango_wrapper "$path"; then
      rm -f "$path"
      removed=$((removed + 1))
    fi
  done
  shopt -u nullglob

  _mango_info "Removed $removed command wrapper(s) from $MANGO_BIN_DIR"
}

_mango_strip_path_block() {
  local rc="$1"
  [[ -f "$rc" ]] || return 0
  if ! grep -q 'mango tools PATH' "$rc" 2>/dev/null; then
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  awk '
    /^# mango tools PATH$/ { skip=1; next }
    skip && /^export PATH=/ { skip=0; next }
    skip && NF==0 { next }
    { print }
  ' "$rc" >"$tmp"
  mv "$tmp" "$rc"
  _mango_info "Removed PATH block from $rc"
}

_mango_cleanup_shell_rc() {
  [[ "$SKIP_PATH_CLEAN" -eq 1 ]] && return 0
  local rc
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    _mango_strip_path_block "$rc"
  done
}

_mango_script_root() {
  local src="${BASH_SOURCE[0]:-$0}"
  while [[ -L "$src" ]]; do
    local dir
    dir="$(cd "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd "$(dirname "$src")" && pwd
}

_mango_delete_install_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || {
    _mango_info "Install dir not present: $dir"
    return 0
  }

  # Never delete a random path — only the configured install location.
  local abs
  abs="$(cd "$dir" && pwd)"
  if [[ "$abs" != "$MANGO_INSTALL_DIR" && "$abs" != "$(cd "$MANGO_INSTALL_DIR" 2>/dev/null && pwd)" ]]; then
    _mango_info "Refusing to delete unexpected path: $abs"
    return 1
  fi

  # If this script (or our live install) lives inside the dir, re-exec from /tmp.
  local here
  here="$(_mango_script_root)"
  case "$here" in
    "$abs"|"$abs"/*)
      if [[ "$_INTERNAL_FINISH" -ne 1 ]]; then
        local tmp
        tmp="$(mktemp -t mango-uninstall.XXXXXX)"
        cp "$here/uninstall.sh" "$tmp" 2>/dev/null || cp "${BASH_SOURCE[0]}" "$tmp"
        chmod +x "$tmp"
        _mango_info "Re-executing uninstall from $tmp (install lives under $abs)"
        local -a reexec=(--internal-finish)
        [[ "$ASSUME_YES" -eq 1 ]] && reexec+=(--yes)
        [[ "$PURGE" -eq 1 ]] && reexec+=(--purge)
        [[ "$KEEP_DATA" -eq 1 ]] && reexec+=(--keep-data)
        [[ "$SKIP_PATH_CLEAN" -eq 1 ]] && reexec+=(--no-path)
        exec env MANGO_INSTALL_DIR="$MANGO_INSTALL_DIR" MANGO_BIN_DIR="$MANGO_BIN_DIR" \
          "$tmp" "${reexec[@]}"
      fi
      ;;
  esac

  _mango_step "Removing $abs"
  rm -rf "$abs"
  _mango_info "Deleted"
}

# ── Main ───────────────────────────────────────────────────────────────────────

echo "Mango uninstall"
echo "  Wrappers: $MANGO_BIN_DIR"
echo "  Install:  $MANGO_INSTALL_DIR"
[[ "$PURGE" -eq 1 ]] && echo "  Mode:     purge (full wipe)"
[[ "$KEEP_DATA" -eq 1 ]] && echo "  Mode:     keep install data"

if [[ "$_INTERNAL_FINISH" -eq 1 ]]; then
  _mango_step "Removing command wrappers"
  _mango_remove_wrappers
  _mango_step "Cleaning shell PATH entries"
  _mango_cleanup_shell_rc
  if [[ "$KEEP_DATA" -eq 0 ]]; then
    _mango_delete_install_dir "$MANGO_INSTALL_DIR"
  fi
  rm -f "${BASH_SOURCE[0]}" 2>/dev/null || true
  echo ""
  echo "Done. Open a new terminal (or run: hash -r) so PATH refreshes."
  echo "  Reinstall: curl -fsSL https://raw.githubusercontent.com/tmarhguy/mango/main/setup.sh | bash -s -- --yes --link"
  echo ""
  exit 0
fi

if ! _mango_confirm "Remove Mango command wrappers from $MANGO_BIN_DIR?"; then
  echo "Cancelled."
  exit 0
fi

_mango_step "Removing command wrappers"
_mango_remove_wrappers

_mango_step "Cleaning shell PATH entries"
_mango_cleanup_shell_rc

if [[ "$KEEP_DATA" -eq 1 ]]; then
  _mango_info "Kept install data (--keep-data)"
elif [[ "$PURGE" -eq 1 ]]; then
  _mango_delete_install_dir "$MANGO_INSTALL_DIR"
elif [[ -d "$MANGO_INSTALL_DIR" ]]; then
  if _mango_confirm "Also delete install directory $MANGO_INSTALL_DIR?"; then
    _mango_delete_install_dir "$MANGO_INSTALL_DIR"
  else
    _mango_info "Kept $MANGO_INSTALL_DIR"
  fi
else
  _mango_info "No install directory at $MANGO_INSTALL_DIR"
fi

echo ""
echo "Done. Open a new terminal (or run: hash -r) so PATH refreshes."
echo "  Reinstall: curl -fsSL https://raw.githubusercontent.com/tmarhguy/mango/main/setup.sh | bash -s -- --yes --link"
echo "  Or from a clone: ./setup.sh --link --yes"
echo ""
