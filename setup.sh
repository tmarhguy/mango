#!/usr/bin/env bash
# Mango setup — local venv, Python deps, optional ffmpeg, global commands
#
# From a clone:
#   ./setup.sh
#
# One-liner (installs to ~/.local/share/mango):
#   curl -fsSL https://raw.githubusercontent.com/tmarhguy/tools/main/setup.sh | bash
#
# Options:
#   -y, --yes          Non-interactive (yes to prompts)
#   --fast             Skip work when already set up (default on re-run)
#   --doctor           Run mango doctor at the end (skipped when --fast and healthy)
#   --update           git pull before setup (remote installs only)
#   --no-ffmpeg        Skip ffmpeg install attempt
#   --no-link          Skip ~/.local/bin command wrappers
#   --link             Always install commands to ~/.local/bin
#   --no-path          Skip adding ~/.local/bin to shell config

set -euo pipefail

MANGO_REPO_URL="${MANGO_REPO_URL:-https://github.com/tmarhguy/tools.git}"
MANGO_INSTALL_DIR="${MANGO_INSTALL_DIR:-$HOME/.local/share/mango}"
MANGO_BIN_DIR="${MANGO_BIN_DIR:-$HOME/.local/bin}"
MANGO_BRANCH="${MANGO_BRANCH:-main}"

ASSUME_YES=0
FAST_MODE=0
RUN_DOCTOR=0
DO_GIT_UPDATE=0
SKIP_FFMPEG=0
SKIP_LINK=0
FORCE_LINK=0
SKIP_PATH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1; shift ;;
    --fast) FAST_MODE=1; shift ;;
    --doctor) RUN_DOCTOR=1; shift ;;
    --update) DO_GIT_UPDATE=1; shift ;;
    --no-ffmpeg) SKIP_FFMPEG=1; shift ;;
    --no-link) SKIP_LINK=1; shift ;;
    --link) FORCE_LINK=1; shift ;;
    --no-path) SKIP_PATH=1; shift ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Status goes to stderr so command substitutions (e.g. root="$(_mango_resolve_root)")
# only capture intentional return values on stdout.
_mango_step() { echo "" >&2; echo "==> $*" >&2; }
_mango_info()  { echo "    $*" >&2; }

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

_mango_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

_mango_resolve_root() {
  local script_dir=""
  if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" && "${BASH_SOURCE[0]}" != "-" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 2>/dev/null || true
  fi

  if [[ -n "$script_dir" && -f "$script_dir/requirements.txt" && -f "$script_dir/mango" ]]; then
    printf '%s' "$script_dir"
    return 0
  fi

  if [[ -f "./requirements.txt" && -f "./mango" ]]; then
    pwd
    return 0
  fi

  # Remote / curl install — use fixed install dir.
  # Only the path is printed on stdout (captured by callers).
  local dir="$MANGO_INSTALL_DIR"
  if [[ -d "$dir/.git" && -f "$dir/requirements.txt" ]]; then
    if [[ "$DO_GIT_UPDATE" -eq 1 ]]; then
      _mango_step "Updating existing install at $dir"
      git -C "$dir" pull --ff-only origin "$MANGO_BRANCH" 2>/dev/null || git -C "$dir" pull --ff-only 2>/dev/null || true
    fi
    printf '%s' "$dir"
    return 0
  fi

  if [[ ! -d "$dir" ]]; then
    _mango_step "Cloning Mango to $dir"
    command -v git &>/dev/null || { echo "Error: git is required for remote install." >&2; exit 1; }
    git clone --depth 1 --branch "$MANGO_BRANCH" "$MANGO_REPO_URL" "$dir"
  elif [[ ! -f "$dir/requirements.txt" || ! -f "$dir/mango" ]]; then
    echo "Error: $dir exists but is not a Mango install. Remove it or set MANGO_INSTALL_DIR." >&2
    exit 1
  fi

  printf '%s' "$dir"
}

_mango_check_python() {
  if ! command -v python3 &>/dev/null; then
    echo "Error: python3 not found. Install Python 3.9+ first." >&2
    case "$(_mango_os)" in
      macos)   echo "  brew install python3" >&2 ;;
      linux)   echo "  sudo apt install python3 python3-venv python3-pip" >&2 ;;
      windows) echo "  winget install Python.Python.3.12" >&2 ;;
    esac
    exit 1
  fi
  local ver
  ver="$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')"
  _mango_info "Python $ver"
}

_mango_req_hash() {
  local root="$1"
  if command -v shasum &>/dev/null; then
    shasum -a 256 "$root/requirements.txt" | awk '{print $1}'
  elif command -v sha256sum &>/dev/null; then
    sha256sum "$root/requirements.txt" | awk '{print $1}'
  else
    cksum "$root/requirements.txt" | awk '{print $1}'
  fi
}

_mango_deps_current() {
  local root="$1" hash stored
  [[ -x "$root/.venv/bin/python" ]] || return 1
  [[ -f "$root/.venv/.mango-deps-hash" ]] || return 1
  hash="$(_mango_req_hash "$root")"
  stored="$(cat "$root/.venv/.mango-deps-hash")"
  [[ "$hash" == "$stored" ]]
}

_mango_pip_install() {
  local root="$1"
  export PIP_DISABLE_PIP_VERSION_CHECK=1
  export PYTHONDONTWRITEBYTECODE=1
  if command -v uv &>/dev/null; then
    uv pip install -r "$root/requirements.txt" -q
  else
    pip install -r "$root/requirements.txt" -q --disable-pip-version-check
  fi
}

_mango_setup_venv() {
  local root="$1"
  cd "$root"

  local created_venv=0
  if [[ ! -d .venv ]]; then
    _mango_step "Creating virtual environment"
    python3 -m venv .venv
    created_venv=1
  fi

  if [[ "$created_venv" -eq 0 ]] && _mango_deps_current "$root"; then
    _mango_info "Python packages up to date (skipped pip)"
    return 0
  fi

  _mango_step "Installing Python packages"
  # shellcheck disable=SC1091
  source .venv/bin/activate
  _mango_pip_install "$root"
  _mango_req_hash "$root" > .venv/.mango-deps-hash
  _mango_info "Done (Pillow, pypdf, pdf2docx, pymupdf)"
}

_mango_chmod_scripts() {
  local root="$1"
  _mango_step "Making scripts executable"
  chmod +x "$root/mango" "$root/bin/"* 2>/dev/null || true
  find "$root/tools" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
}

_mango_try_ffmpeg() {
  [[ "$SKIP_FFMPEG" -eq 1 ]] && return 0
  command -v ffmpeg &>/dev/null && { _mango_info "ffmpeg already installed"; return 0; }

  _mango_step "ffmpeg not found (needed for video tools)"
  case "$(_mango_os)" in
    macos)
      if command -v brew &>/dev/null; then
        _mango_confirm "Install ffmpeg with Homebrew?" && brew install ffmpeg
      else
        _mango_info "Install manually: brew install ffmpeg"
      fi
      ;;
    linux)
      if command -v apt-get &>/dev/null; then
        _mango_confirm "Install ffmpeg with apt?" && sudo apt-get install -y ffmpeg
      elif command -v dnf &>/dev/null; then
        _mango_confirm "Install ffmpeg with dnf?" && sudo dnf install -y ffmpeg
      else
        _mango_info "Install ffmpeg with your package manager"
      fi
      ;;
    windows)
      if command -v winget &>/dev/null; then
        _mango_confirm "Install ffmpeg with winget?" && winget install Gyan.FFmpeg
      else
        _mango_info "Install manually: winget install Gyan.FFmpeg"
      fi
      ;;
    *)
      _mango_info "See https://ffmpeg.org/download.html"
      ;;
  esac
}

_mango_write_wrapper() {
  local dest="$1" target="$2"
  rm -f "$dest"
  cat >"$dest" <<EOF
#!/usr/bin/env bash
exec "$target" "\$@"
EOF
  chmod +x "$dest"
}

_mango_link_bin() {
  local root="$1"
  [[ "$SKIP_LINK" -eq 1 && "$FORCE_LINK" -eq 0 ]] && return 0

  local do_link=0
  if [[ "$FORCE_LINK" -eq 1 ]]; then
    do_link=1
  elif _mango_confirm "Install mango commands to $MANGO_BIN_DIR? (mango, format-json, merge-pdf, …)"; then
    do_link=1
  fi

  [[ "$do_link" -eq 1 ]] || return 0

  mkdir -p "$MANGO_BIN_DIR"

  _mango_write_wrapper "$MANGO_BIN_DIR/mango" "$root/bin/mango"

  local tool count=0
  for tool in "$root/bin/"*; do
    [[ -f "$tool" ]] || continue
    local name
    name="$(basename "$tool")"
    [[ "$name" == "mango" ]] && continue
    _mango_write_wrapper "$MANGO_BIN_DIR/$name" "$tool"
    count=$((count + 1))
  done

  _mango_info "Installed: mango + $count tools → $MANGO_BIN_DIR"
}

_mango_shell_rc_files() {
  local -a rcs=()
  case "${SHELL:-}" in
    */zsh)  rcs+=("$HOME/.zshrc") ;;
    */bash) rcs+=("$HOME/.bashrc") ;;
  esac
  [[ -f "$HOME/.zshrc" ]] && rcs+=("$HOME/.zshrc")
  [[ -f "$HOME/.bashrc" ]] && rcs+=("$HOME/.bashrc")
  [[ -f "$HOME/.profile" ]] && rcs+=("$HOME/.profile")

  local rc seen="" deduped=()
  for rc in "${rcs[@]}"; do
  [[ -n "$rc" ]] || continue
    case ":$seen:" in *":$rc:"*) continue ;; esac
    seen="${seen:+$seen:}$rc"
    deduped+=("$rc")
  done
  printf '%s\n' "${deduped[@]}"
}

_mango_path_configured() {
  local rc line
  while IFS= read -r rc; do
    [[ -f "$rc" ]] || continue
    while IFS= read -r line; do
      [[ "$line" == *"mango tools PATH"* ]] && return 0
    done <"$rc"
  done < <(_mango_shell_rc_files)
  return 1
}

_mango_configure_path() {
  [[ "$SKIP_PATH" -eq 1 ]] && return 0

  case ":$PATH:" in
    *":$MANGO_BIN_DIR:"*) return 0 ;;
  esac

  _mango_path_configured && return 0

  local do_path=0
  if [[ "$FORCE_LINK" -eq 1 || "$ASSUME_YES" -eq 1 ]]; then
    do_path=1
  elif _mango_confirm "Add $MANGO_BIN_DIR to your shell PATH?"; then
    do_path=1
  fi

  [[ "$do_path" -eq 1 ]] || return 0

  local rc block
  block="# mango tools PATH
export PATH=\"\$PATH:$MANGO_BIN_DIR\""

  local wrote=0
  while IFS= read -r rc; do
    [[ -f "$rc" ]] || continue
    if grep -q 'mango tools PATH' "$rc" 2>/dev/null; then
      continue
    fi
    printf '\n%s\n' "$block" >>"$rc"
    _mango_info "Updated: $rc"
    wrote=1
  done < <(_mango_shell_rc_files)

  if [[ "$wrote" -eq 0 ]]; then
    _mango_info "Add to PATH: export PATH=\"\$PATH:$MANGO_BIN_DIR\""
  else
    _mango_info "Restart your terminal or run: source ~/.zshrc"
  fi
}

main() {
  echo ""
  echo "Mango Setup"
  echo "───────────"

  _mango_check_python
  local root
  root="$(_mango_resolve_root)"
  _mango_info "Install directory: $root"

  local already_ready=0
  if _mango_deps_current "$root"; then
    already_ready=1
    [[ "$FAST_MODE" -eq 0 ]] && FAST_MODE=1
  fi

  if [[ "$FAST_MODE" -eq 1 && "$already_ready" -eq 1 ]]; then
    _mango_chmod_scripts "$root"
    if [[ "$FORCE_LINK" -eq 1 ]]; then
      _mango_link_bin "$root"
      _mango_configure_path
    elif [[ -x "$MANGO_BIN_DIR/mango" ]]; then
      _mango_info "Commands: $MANGO_BIN_DIR/mango (+ tools)"
    fi
    echo ""
    echo "Already up to date."
    echo ""
    echo "  cd $root && ./mango"
    if [[ -x "$MANGO_BIN_DIR/mango" ]]; then
      echo "  mango                          # or run globally"
    fi
    echo ""
    return 0
  fi

  _mango_setup_venv "$root"
  _mango_chmod_scripts "$root"

  if [[ "$FAST_MODE" -eq 0 ]]; then
    _mango_try_ffmpeg
  else
    command -v ffmpeg &>/dev/null && _mango_info "ffmpeg already installed" || _mango_info "ffmpeg not found (use --no-ffmpeg or full setup for install prompt)"
  fi

  if [[ "$RUN_DOCTOR" -eq 1 || "$already_ready" -eq 0 ]]; then
    _mango_step "Running mango doctor"
    "$root/bin/mango-doctor" --quick || true
  fi

  _mango_link_bin "$root"
  _mango_configure_path

  echo ""
  echo "Setup complete."
  echo ""
  if [[ -x "$MANGO_BIN_DIR/mango" ]]; then
    echo "  mango                          # interactive UI (anywhere)"
    echo "  format-json --help             # run any tool directly"
  else
    echo "  cd $root && ./mango            # interactive UI"
    echo "  $root/bin/to_gif --help        # run a tool directly"
    echo "  ./setup.sh --link              # install commands globally"
  fi
  echo ""
  if [[ "$root" == "$MANGO_INSTALL_DIR" ]]; then
    echo "  Installed to $MANGO_INSTALL_DIR (offline after setup)"
  fi
  echo ""
}

main "$@"
