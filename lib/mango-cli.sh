#!/usr/bin/env bash
# Mango — shared CLI helpers for tool scripts

set -euo pipefail

if [[ -z "${MANGO_ROOT:-}" ]]; then
  MANGO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# shellcheck source=mango-deps.sh
source "$MANGO_ROOT/lib/mango-deps.sh"

MANGO_INPUT=""
MANGO_INPUTS=()
MANGO_OUTPUT=""
MANGO_MINIFY=0
MANGO_DECODE=0
MANGO_WIDTH=""
MANGO_QUALITY=""
MANGO_ROTATE=""
MANGO_FORMAT=""
MANGO_START=""
MANGO_END=""
MANGO_PASSWORD=""

mango_die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

mango_usage() {
  local synopsis="$1"
  shift
  echo "Usage: $synopsis" >&2
  while [[ $# -gt 0 ]]; do
    echo "  $1" >&2
    shift
  done
  exit 0
}

mango_abs_path() {
  local path="$1"
  path="${path/#\~/$HOME}"
  if [[ "$path" != /* ]]; then
    path="$(pwd)/$path"
  fi
  if command -v python3 &>/dev/null; then
    python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$path"
  else
    printf '%s' "$path"
  fi
}

mango_require_input() {
  local path="$1"
  [[ -n "$path" ]] || mango_die "Input file is required."
  path="$(mango_abs_path "$path")"
  [[ -f "$path" ]] || mango_die "Input file not found: $1"
  MANGO_INPUT="$path"
}

mango_require_inputs() {
  local -a raw=()
  if [[ $# -gt 0 ]]; then
    raw=("$@")
  elif [[ ${#MANGO_INPUTS[@]} -gt 0 ]]; then
    raw=("${MANGO_INPUTS[@]}")
  elif [[ -n "$MANGO_INPUT" ]]; then
    raw=("$MANGO_INPUT")
  fi
  [[ ${#raw[@]} -gt 0 ]] || mango_die "Input file or folder is required."

  local -a resolved=()
  local path
  for path in "${raw[@]}"; do
    path="$(mango_abs_path "$path")"
    if [[ -d "$path" || -f "$path" ]]; then
      resolved+=("$path")
    else
      mango_die "Input not found: $path"
    fi
  done
  MANGO_INPUTS=("${resolved[@]}")
  MANGO_INPUT="${MANGO_INPUTS[0]}"
}

mango_default_output() {
  local input="$1" new_ext="$2"
  local dir base
  dir=$(dirname "$input")
  base=$(basename "$input")
  base="${base%.*}"
  printf '%s/%s.%s' "$dir" "$base" "$new_ext"
}

mango_parse_io() {
  local positional=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output) MANGO_OUTPUT="$2"; shift 2 ;;
      -i|--input)  MANGO_INPUT="$2"; shift 2 ;;
      -h|--help)   return 2 ;;
      -m|--minify) MANGO_MINIFY=1; shift ;;
      -d|--decode) MANGO_DECODE=1; shift ;;
      -w|--width)  MANGO_WIDTH="$2"; shift 2 ;;
      -q|--quality) MANGO_QUALITY="$2"; shift 2 ;;
      -r|--rotate) MANGO_ROTATE="$2"; shift 2 ;;
      -f|--format) MANGO_FORMAT="$2"; shift 2 ;;
      -a|--algorithm) MANGO_FORMAT="$2"; shift 2 ;;
      -p|--password) MANGO_PASSWORD="$2"; shift 2 ;;
      -s|--start)  MANGO_START="$2"; shift 2 ;;
      -e|--end)    MANGO_END="$2"; shift 2 ;;
      --) shift; positional+=("$@"); break ;;
      -*) mango_die "Unknown option: $1" ;;
      *) positional+=("$1"); shift ;;
    esac
  done
  if [[ ${#positional[@]} -gt 0 ]]; then
    if [[ -z "$MANGO_OUTPUT" && ${#positional[@]} -eq 2 ]]; then
      [[ -z "$MANGO_INPUT" ]] && MANGO_INPUT="${positional[0]}"
      MANGO_OUTPUT="${positional[1]}"
      MANGO_INPUTS=("${positional[0]}")
    else
      [[ -z "$MANGO_INPUT" ]] && MANGO_INPUT="${positional[0]}"
      MANGO_INPUTS=("${positional[@]}")
    fi
  elif [[ -n "$MANGO_INPUT" ]]; then
    MANGO_INPUTS=("$MANGO_INPUT")
  fi
  return 0
}

mango_parse_io_or_die() {
  mango_parse_io "$@" || {
    local rc=$?
    [[ "$rc" -eq 2 ]] && return 2
    mango_die "Invalid arguments"
  }
}

mango_parse_args() {
  local usage_fn="$1"
  shift
  mango_parse_io_or_die "$@" || {
    local rc=$?
    [[ "$rc" -eq 2 ]] && "$usage_fn"
    return "$rc"
  }
}

mango_run_python() {
  local script="$1"
  shift
  local py
  py="$(mango_python)" || mango_die "Python 3 not found. Run: mango doctor"
  exec "$py" "$script" "$@"
}
