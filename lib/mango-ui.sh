#!/usr/bin/env bash
# Mango UI — shared terminal UI components

# Colors & styles
MANGO_BOLD=$'\e[1m'
MANGO_DIM=$'\e[2m'
MANGO_RESET=$'\e[0m'
MANGO_CYAN=$'\e[1;36m'
MANGO_YELLOW=$'\e[1;33m'
MANGO_GREEN=$'\e[1;32m'
MANGO_RED=$'\e[1;31m'
MANGO_MAGENTA=$'\e[1;35m'
MANGO_WHITE=$'\e[1;37m'
MANGO_BG_DARK=$'\e[48;5;235m'
MANGO_FG_MANGO=$'\e[38;5;214m'   # golden mango (distinct from Claude's rust orange)

MANGO_UI_WIDTH="${COLUMNS:-80}"
if [[ "$MANGO_UI_WIDTH" -lt 60 ]]; then
  MANGO_UI_WIDTH=60
elif [[ "$MANGO_UI_WIDTH" -gt 100 ]]; then
  MANGO_UI_WIDTH=100
fi

_mango_repeat() {
  local char="$1" count="$2" i
  for ((i = 0; i < count; i++)); do printf '%s' "$char"; done
}

_mango_pad_center() {
  local text="$1" width="$2"
  local len=${#text}
  local pad=$(( (width - len) / 2 ))
  printf '%*s%s%*s' "$pad" '' "$text" "$((width - len - pad))" ''
}

_mango_strip_ansi() {
  sed 's/\x1b\[[0-9;]*m//g'
}

# ── TUI primitives (alternate screen + in-place updates) ─────────────────────

_MANGO_TUI_ACTIVE=0
_MANGO_TUI_ROW=1

_mango_tui_enter() {
  _MANGO_TUI_ROW=1
  _MANGO_TUI_ACTIVE=1
  [[ -t 1 ]] || return 0
  printf '\033[?1049h\033[H\033[J\033[?25l'
}

_mango_tui_leave() {
  [[ "$_MANGO_TUI_ACTIVE" == "1" ]] || return 0
  [[ -t 1 ]] && printf '\033[?25h\033[?1049l'
  _MANGO_TUI_ACTIVE=0
}

_mango_tui_home() {
  [[ "$_MANGO_TUI_ACTIVE" == "1" ]] || return 0
  _MANGO_TUI_ROW=1
  [[ -t 1 ]] && printf '\033[H\033[J'
}

_mango_out() {
  echo -e "$1"
  if [[ "$_MANGO_TUI_ACTIVE" == "1" ]]; then
    _MANGO_TUI_ROW=$((_MANGO_TUI_ROW + 1))
  fi
}

_mango_cursor_to() {
  local row="$1"
  local col="${2:-1}"
  printf '\033[%d;%dH' "$row" "$col"
}

_mango_redraw_at() {
  local row="$1"
  local text="$2"
  _mango_cursor_to "$row" 1
  printf '\033[2K'
  echo -e "$text"
}

_mango_box_line_str() {
  local text="$1"
  local inner=$((MANGO_UI_WIDTH - 4))
  local plain
  plain=$(echo -e "$text" | _mango_strip_ansi)
  local pad=$((inner - 2 - ${#plain}))
  if [[ "$pad" -lt 0 ]]; then pad=0; fi
  printf '%s' "${MANGO_FG_MANGO}│${MANGO_RESET} ${text}$(_mango_repeat ' ' "$pad") ${MANGO_FG_MANGO}│${MANGO_RESET}"
}

ui_clear() {
  if [[ ! -t 1 ]]; then
    return
  fi
  if [[ "$_MANGO_TUI_ACTIVE" == "1" ]]; then
    _mango_tui_home
  else
    clear
  fi
}

ui_logo() {
  # Claude-style sparkle mascot (layout only — color is Mango gold, not Claude orange)
  _mango_out "${MANGO_FG_MANGO}${MANGO_BOLD} ▐▛███▜▌${MANGO_RESET}"
  _mango_out "${MANGO_FG_MANGO}${MANGO_BOLD}▝▜█████▛▘${MANGO_RESET}"
  _mango_out "${MANGO_FG_MANGO}${MANGO_BOLD}  ▘▘ ▝▝${MANGO_RESET}"
}

_ui_brand_lines() {
  ui_box_line "${MANGO_FG_MANGO}${MANGO_BOLD} ▐▛███▜▌${MANGO_RESET}   ${MANGO_WHITE}${MANGO_BOLD}Mango${MANGO_RESET}  ${MANGO_DIM}v1.0${MANGO_RESET}"
  ui_box_line "${MANGO_FG_MANGO}${MANGO_BOLD}▝▜█████▛▘${MANGO_RESET}  ${MANGO_DIM}My Toolkit Hub${MANGO_RESET}"
  ui_box_line "${MANGO_FG_MANGO}${MANGO_BOLD}  ▘▘ ▝▝${MANGO_RESET}    ${MANGO_DIM}offline · private · fast${MANGO_RESET}"
}

ui_header() {
  ui_clear
  _mango_out ""
  ui_box_open
  _ui_brand_lines
  ui_box_close
  _mango_out ""
}

ui_home_panel() {
  ui_clear
  echo ""
  ui_box_open
  _ui_brand_lines
  ui_box_rule
  ui_box_line "  ${MANGO_DIM}You are here:${MANGO_RESET} ${MANGO_FG_MANGO}${MANGO_BOLD}Home${MANGO_RESET}"
  ui_box_rule
  ui_box_line "  ${MANGO_WHITE}Use favorite tools from terminal.${MANGO_RESET}"
  ui_box_line "  ${MANGO_DIM}Pick a file and let Mango guide you.${MANGO_RESET}"
  ui_box_close
  echo ""
}

ui_title_bar() {
  local title="$1"
  local inner=$((MANGO_UI_WIDTH - 4))
  local line
  line=$(_mango_pad_center " $title " "$inner")

  _mango_out ""
  _mango_out "${MANGO_FG_MANGO}╔$(_mango_repeat '═' "$inner")╗${MANGO_RESET}"
  _mango_out "${MANGO_FG_MANGO}║${MANGO_RESET}${MANGO_YELLOW}${MANGO_BOLD}${line}${MANGO_RESET}${MANGO_FG_MANGO}║${MANGO_RESET}"
  _mango_out "${MANGO_FG_MANGO}╚$(_mango_repeat '═' "$inner")╝${MANGO_RESET}"
  _mango_out ""
}

ui_box_open() {
  local title="${1:-}"
  local inner=$((MANGO_UI_WIDTH - 4))

  _mango_out "${MANGO_FG_MANGO}┌$(_mango_repeat '─' "$inner")┐${MANGO_RESET}"
  if [[ -n "$title" ]]; then
    local label=" $title "
    local pad=$((inner - ${#label}))
    _mango_out "${MANGO_FG_MANGO}│${MANGO_RESET}${MANGO_YELLOW}${MANGO_BOLD}${label}${MANGO_RESET}$(_mango_repeat ' ' "$pad")${MANGO_FG_MANGO}│${MANGO_RESET}"
    _mango_out "${MANGO_FG_MANGO}├$(_mango_repeat '─' "$inner")┤${MANGO_RESET}"
  fi
}

ui_box_line() {
  local text="$1"
  _mango_out "$(_mango_box_line_str "$text")"
}

ui_box_close() {
  local inner=$((MANGO_UI_WIDTH - 4))
  _mango_out "${MANGO_FG_MANGO}└$(_mango_repeat '─' "$inner")┘${MANGO_RESET}"
}

ui_box_rule() {
  local inner=$((MANGO_UI_WIDTH - 4))
  _mango_out "${MANGO_FG_MANGO}├$(_mango_repeat '─' "$inner")┤${MANGO_RESET}"
}

ui_divider() {
  local inner=$((MANGO_UI_WIDTH - 4))
  _mango_out "${MANGO_DIM}$(_mango_repeat '─' "$inner")${MANGO_RESET}"
}

ui_menu() {
  local -a labels=()
  local -a descs=()
  local i=0

  while [[ $# -gt 0 ]]; do
    labels+=("$1")
    shift
    if [[ $# -gt 0 && "$1" != --* ]]; then
      descs+=("$1")
      shift
    else
      descs+=("")
    fi
  done

  ui_box_open "Main Menu"

  for i in "${!labels[@]}"; do
    local num=$((i + 1))
    local label="${labels[$i]}"
    local desc="${descs[$i]:-}"

    if [[ "$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]')" == "exit" ]]; then
      ui_box_line "  ${MANGO_RED}${MANGO_BOLD}${num})${MANGO_RESET} ${MANGO_RED}${label}${MANGO_RESET}"
    else
      ui_box_line "  ${MANGO_GREEN}${MANGO_BOLD}${num})${MANGO_RESET} ${MANGO_WHITE}${label}${MANGO_RESET}  ${MANGO_DIM}${desc}${MANGO_RESET}"
    fi
  done

  ui_box_close
  echo ""
}

# Optional hook: set to a function name to draw page content above an arrow menu.
_MANGO_PAGE_DRAW_FN=""
MANGO_MENU_FOOTER=""

_mango_menu_item_content() {
  local index="$1"
  local selected="$2"
  local style="$3"
  local item="$4"
  local label="${item%%|*}"
  local rest="${item#*|}"
  local lower marker desc status icon color

  lower=$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]')
  if [[ "$index" -eq "$selected" ]]; then
    marker="${MANGO_CYAN}${MANGO_BOLD}❯${MANGO_RESET}"
  else
    marker=" "
  fi

  if [[ "$style" == "main" ]]; then
    desc="$rest"
    if [[ "$lower" == "exit" ]]; then
      printf '%s' "  ${marker} ${MANGO_RED}${MANGO_BOLD}${label}${MANGO_RESET}"
    elif [[ "$lower" == "back" ]]; then
      printf '%s' "  ${marker} ${MANGO_DIM}← ${label}${MANGO_RESET}"
    else
      printf '%s' "  ${marker} ${MANGO_WHITE}${label}${MANGO_RESET}  ${MANGO_DIM}${desc}${MANGO_RESET}"
    fi
  else
    status="$rest"
    if [[ "$status" == "ready" ]]; then
      icon="●"
      color="$MANGO_GREEN"
    elif [[ "$status" == "soon" ]]; then
      icon="○"
      color="$MANGO_DIM"
    else
      icon="·"
      color="$MANGO_WHITE"
    fi

    if [[ "$lower" == "back" ]]; then
      printf '%s' "  ${marker} ${MANGO_DIM}← ${label}${MANGO_RESET}"
    elif [[ "$lower" == "exit" ]]; then
      printf '%s' "  ${marker} ${MANGO_RED}${MANGO_BOLD}${label}${MANGO_RESET}"
    else
      printf '%s' "  ${marker} ${color}${icon}${MANGO_RESET}  ${color}${label}${MANGO_RESET}"
    fi
  fi
}

_mango_menu_item_line() {
  local index="$1"
  local selected="$2"
  local style="$3"
  local item="$4"
  local content
  content=$(_mango_menu_item_content "$index" "$selected" "$style" "$item")
  _mango_box_line_str "$content"
}

_mango_menu_draw_prefix() {
  local layout="$1"

  _mango_out ""
  if [[ "$layout" == "home" ]]; then
    ui_box_open
    _ui_brand_lines
    ui_box_rule
    ui_box_line "  ${MANGO_DIM}You are here:${MANGO_RESET} ${MANGO_FG_MANGO}${MANGO_BOLD}Home${MANGO_RESET}"
    ui_box_rule
    ui_box_line "  ${MANGO_WHITE}Use favorite tools from terminal.${MANGO_RESET}"
    ui_box_line "  ${MANGO_DIM}Pick a file and let Mango guide you.${MANGO_RESET}"
    ui_box_close
    _mango_out ""
  elif [[ "$layout" == "page" && -n "${_MANGO_PAGE_DRAW_FN:-}" ]]; then
    "$_MANGO_PAGE_DRAW_FN"
  fi
}

_MANGO_ITEM_ROWS=()

_mango_menu_draw_full() {
  local layout="$1"
  local style="$2"
  local title="$3"
  local selected="$4"
  local footer="$5"
  shift 5
  local -a items=("$@")
  local i=0 item row_start

  _MANGO_ITEM_ROWS=()
  _mango_tui_home
  _mango_menu_draw_prefix "$layout"

  ui_box_open "$title"
  for item in "${items[@]}"; do
    row_start=$_MANGO_TUI_ROW
    ui_box_line "$(_mango_menu_item_content "$i" "$selected" "$style" "$item")"
    _MANGO_ITEM_ROWS+=("$row_start")
    ((i++)) || true
  done
  ui_box_rule
  ui_box_line "  ${MANGO_DIM}↑↓ navigate · Enter select${MANGO_RESET}"
  ui_box_close

  if [[ -n "$footer" ]]; then
    _mango_out "  ${footer}"
    _mango_out ""
  fi
}

_mango_menu_update_selection() {
  local old="$1"
  local new="$2"
  local style="$3"
  local old_row="$4"
  local new_row="$5"
  shift 5
  local -a items=("$@")

  _mango_redraw_at "$old_row" "$(_mango_menu_item_line "$old" "$new" "$style" "${items[$old]}")"
  _mango_redraw_at "$new_row" "$(_mango_menu_item_line "$new" "$new" "$style" "${items[$new]}")"
}

# Interactive arrow-key menu. Sets varname to 1-based index of selected item.
# layout: home (brand panel) | page (calls _MANGO_PAGE_DRAW_FN) | plain
# style: main (label|desc) | tools (label|ready|soon|empty)
ui_menu_select() {
  local varname="$1"
  local layout="$2"
  local style="$3"
  local title="$4"
  shift 4
  local -a items=("$@")
  local selected="${MANGO_MENU_INITIAL:-0}" count=${#items[@]} key footer="${MANGO_MENU_FOOTER:-}"
  local -a item_rows=()
  local old
  MANGO_MENU_INITIAL=0

  [[ "$count" -gt 0 ]] || return 1
  if [[ "$selected" -ge "$count" ]] || [[ "$selected" -lt 0 ]]; then
    selected=0
  fi

  _mango_tui_enter

  _mango_menu_draw_full "$layout" "$style" "$title" "$selected" "$footer" "${items[@]}"
  item_rows=("${_MANGO_ITEM_ROWS[@]}")

  while true; do
    key=$(_mango_read_nav_key)
    case "$key" in
      up)
        old=$selected
        selected=$(( (selected - 1 + count) % count ))
        if [[ "$old" != "$selected" ]]; then
          _mango_menu_update_selection "$old" "$selected" "$style" \
            "${item_rows[$old]}" "${item_rows[$selected]}" "${items[@]}"
        fi
        ;;
      down)
        old=$selected
        selected=$(( (selected + 1) % count ))
        if [[ "$old" != "$selected" ]]; then
          _mango_menu_update_selection "$old" "$selected" "$style" \
            "${item_rows[$old]}" "${item_rows[$selected]}" "${items[@]}"
        fi
        ;;
      enter)
        _mango_tui_leave
        printf -v "$varname" '%s' "$((selected + 1))"
        return 0
        ;;
    esac
  done
}

ui_footer() {
  local text="${1-}"
  if [[ -z "$text" ]]; then
    text="Mango · My Toolkit Hub"
  fi
  echo ""
  echo -e "${MANGO_FG_MANGO}$(_mango_repeat '─' "$MANGO_UI_WIDTH")${MANGO_RESET}"
  echo -e "${MANGO_DIM}"
  _mango_pad_center "$text" "$MANGO_UI_WIDTH"
  echo -e "${MANGO_RESET}"
}

ui_prompt() {
  local message="$1"
  local varname="$2"

  ui_box_open
  ui_box_line "${MANGO_CYAN}${MANGO_BOLD}❯${MANGO_RESET} ${message}"
  ui_box_close
  echo -ne "  ${MANGO_CYAN}❯${MANGO_RESET} "
  read -er "$varname"
}

ui_message() {
  local level="$1"
  local text="$2"
  local icon color

  case "$level" in
    success) icon="✔"; color="$MANGO_GREEN" ;;
    error)   icon="✖"; color="$MANGO_RED" ;;
    warning) icon="⚠"; color="$MANGO_YELLOW" ;;
    info)    icon="ℹ"; color="$MANGO_CYAN" ;;
    *)       icon="·"; color="$MANGO_WHITE" ;;
  esac

  ui_box_open
  ui_box_line "  ${color}${MANGO_BOLD}${icon}${MANGO_RESET}  ${text}"
  ui_box_close
}

ui_tool_header() {
  local name="$1"
  local category="$2"
  ui_clear
  ui_header
  ui_title_bar "$name"
  if [[ -n "$category" ]]; then
    _mango_out "  ${MANGO_DIM}Category:${MANGO_RESET} ${MANGO_MAGENTA}${category}${MANGO_RESET}"
    _mango_out ""
  fi
}

ui_pause() {
  local msg="${1:-Press Enter to return to the menu...}"
  echo ""
  ui_prompt "$msg" _MANGO_DUMMY
}

ui_run_tool() {
  local name="$1"
  shift
  echo ""
  ui_box_open "Running"
  ui_box_line "  ${MANGO_DIM}Executing:${MANGO_RESET} ${MANGO_WHITE}${MANGO_BOLD}${name}${MANGO_RESET}"
  ui_box_close
  echo ""
  echo -e "${MANGO_DIM}$(_mango_repeat '─' $((MANGO_UI_WIDTH - 4)))${MANGO_RESET}"
  echo ""

  if "$@"; then
    echo ""
    echo -e "${MANGO_DIM}$(_mango_repeat '─' $((MANGO_UI_WIDTH - 4)))${MANGO_RESET}"
    ui_message success "Done! ${name} completed successfully."
  else
    local code=$?
    echo ""
    echo -e "${MANGO_DIM}$(_mango_repeat '─' $((MANGO_UI_WIDTH - 4)))${MANGO_RESET}"
    ui_message error "${name} failed (exit code ${code})."
    return "$code"
  fi
}

ui_breadcrumb() {
  local -a crumbs=("$@")
  local trail="" i

  for i in "${!crumbs[@]}"; do
    if [[ -n "$trail" ]]; then
      trail+=" ${MANGO_DIM}›${MANGO_RESET} "
    fi
    if [[ "$i" -eq $((${#crumbs[@]} - 1)) ]]; then
      trail+="${MANGO_FG_MANGO}${MANGO_BOLD}${crumbs[$i]}${MANGO_RESET}"
    else
      trail+="${MANGO_DIM}${crumbs[$i]}${MANGO_RESET}"
    fi
  done

  _mango_out "  ${MANGO_DIM}You are here:${MANGO_RESET} ${trail}"
  _mango_out ""
}

ui_prompt_default() {
  local message="$1"
  local default="$2"
  local varname="$3"

  ui_box_open
  ui_box_line "${MANGO_CYAN}${MANGO_BOLD}❯${MANGO_RESET} ${message}"
  ui_box_line "  ${MANGO_DIM}(Enter = ${default})${MANGO_RESET}"
  ui_box_close
  echo -ne "  ${MANGO_CYAN}❯${MANGO_RESET} "
  local input
  read -er input
  if [[ -z "$input" ]]; then
    printf -v "$varname" '%s' "$default"
  else
    printf -v "$varname" '%s' "$input"
  fi
}

_mango_fmt_bytes() {
  local bytes="$1"
  if [[ "$bytes" -ge 1073741824 ]]; then
    awk -v b="$bytes" 'BEGIN { printf "%.1f GB", b/1073741824 }'
  elif [[ "$bytes" -ge 1048576 ]]; then
    awk -v b="$bytes" 'BEGIN { printf "%.1f MB", b/1048576 }'
  elif [[ "$bytes" -ge 1024 ]]; then
    awk -v b="$bytes" 'BEGIN { printf "%.1f KB", b/1024 }'
  else
    echo "${bytes} B"
  fi
}

_mango_file_size() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "—"
    return
  fi
  if stat -f%z "$path" &>/dev/null; then
    _mango_fmt_bytes "$(stat -f%z "$path")"
  elif stat -c%s "$path" &>/dev/null; then
    _mango_fmt_bytes "$(stat -c%s "$path")"
  else
    ls -lh "$path" 2>/dev/null | awk '{print $5}'
  fi
}

_mango_expand_path() {
  local path="$1"
  path="${path/#\~/$HOME}"
  if [[ "$path" != /* ]]; then
    path="$(pwd)/$path"
  fi
  # Resolve . and .. without requiring realpath
  if command -v python3 &>/dev/null; then
    python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$path" 2>/dev/null && return
  fi
  echo "$path"
}

_mango_collect_matching_files() {
  local -a exts=("$@")
  local -a found=()
  local f ext pattern

  shopt -s nullglob nocaseglob
  for ext in "${exts[@]}"; do
    ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    pattern="*.${ext}"
    for f in $pattern; do
      [[ -f "$f" ]] && found+=("$f")
    done
  done
  shopt -u nullglob nocaseglob

  if [[ ${#found[@]} -eq 0 ]]; then
    return 1
  fi

  local IFS=$'\n'
  found=($(printf '%s\n' "${found[@]}" | LC_ALL=C sort -fu))

  local item
  for item in "${found[@]}"; do
    printf '%s\n' "$item"
  done
  return 0
}

_mango_collect_matching_in_dir() {
  local dir="$1"
  shift
  local -a exts=("$@")
  local -a found=()
  local f ext pattern

  shopt -s nullglob nocaseglob
  for ext in "${exts[@]}"; do
    ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    pattern="${dir}/*.${ext}"
    for f in $pattern; do
      [[ -f "$f" ]] && found+=("$f")
    done
  done
  shopt -u nullglob nocaseglob

  if [[ ${#found[@]} -eq 0 ]]; then
    return 1
  fi

  local IFS=$'\n'
  found=($(printf '%s\n' "${found[@]}" | LC_ALL=C sort -fu))

  local item
  for item in "${found[@]}"; do
    printf '%s\n' "$item"
  done
  return 0
}

_mango_collect_all_files() {
  local f
  shopt -s nullglob
  for f in *; do
    [[ -f "$f" ]] && printf '%s\n' "$f"
  done
  shopt -u nullglob
  return 0
}

_mango_exts_is_any() {
  local ext
  for ext in "$@"; do
    ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    [[ "$ext" == "any" || "$ext" == "various" || "$ext" == "same" ]] && return 0
  done
  return 1
}

_mango_format_ext_label() {
  local -a parts=()
  local ext
  for ext in "$@"; do
    ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    if [[ "$ext" == "any" || "$ext" == "various" || "$ext" == "same" ]]; then
      printf '%s' "any file"
      return 0
    fi
    parts+=(".${ext}")
  done
  local joined
  joined=$(IFS=', '; echo "${parts[*]}")
  printf '%s' "$joined"
}

_mango_read_into_array() {
  local varname="$1"
  shift
  local -a _items=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && _items+=("$line")
  done < <(_mango_collect_matching_files "$@") || true
  if ((${#_items[@]} > 0)); then
    eval "$varname=(\"\${_items[@]}\")"
  else
    eval "$varname=()"
  fi
}

_mango_read_all_into_array() {
  local varname="$1"
  local -a _items=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && _items+=("$line")
  done < <(_mango_collect_all_files) || true
  if ((${#_items[@]} > 0)); then
    local IFS=$'\n'
    _items=($(printf '%s\n' "${_items[@]}" | LC_ALL=C sort -fu))
    eval "$varname=(\"\${_items[@]}\")"
  else
    eval "$varname=()"
  fi
}

_mango_short_path() {
  local p="$1" home="$HOME"
  if [[ "$p" == "$home" ]]; then
    printf '~'
    return 0
  fi
  if [[ "$p" == "$home/"* ]]; then
    printf '~%s' "${p#$home}"
    return 0
  fi
  printf '%s' "$p"
}

_mango_dir_has_matching_files() {
  local dir="$1"
  shift
  local -a exts=("$@")
  local ext

  if _mango_exts_is_any "${exts[@]}"; then
    [[ -n "$(find "$dir" -type f ! -name '.*' -print -quit 2>/dev/null)" ]]
    return $?
  fi

  for ext in "${exts[@]}"; do
    ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
    if [[ -n "$(find "$dir" -type f -iname "*.${ext}" ! -name '.*' -print -quit 2>/dev/null)" ]]; then
      return 0
    fi
  done
  return 1
}

_mango_browse_list_items() {
  local varname="$1"
  local current="$2"
  local root="$3"
  shift 3
  local -a exts=("$@")
  local -a _items=() dirs=() files=()
  local d f name ext

  if [[ "$current" != "$root" ]]; then
    _items+=("dir|..")
  fi

  shopt -s nullglob
  for d in "$current"/*/; do
    [[ -d "$d" ]] || continue
    name=$(basename "$d")
    [[ "$name" == .* ]] && continue
    if _mango_dir_has_matching_files "$d" "${exts[@]}"; then
      dirs+=("$name")
    fi
  done
  shopt -u nullglob

  if ((${#dirs[@]} > 0)); then
    local IFS=$'\n'
    dirs=($(printf '%s\n' "${dirs[@]}" | LC_ALL=C sort -f))
    for name in "${dirs[@]}"; do
      _items+=("dir|${name}")
    done
  fi

  if [[ ${#exts[@]} -eq 0 ]] || _mango_exts_is_any "${exts[@]}"; then
    shopt -s nullglob
    for f in "$current"/*; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f")
      [[ "$name" == .* ]] && continue
      files+=("$name")
    done
    shopt -u nullglob
  else
    shopt -s nullglob nocaseglob
    for ext in "${exts[@]}"; do
      ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
      for f in "$current"/*."${ext}"; do
        [[ -f "$f" ]] || continue
        files+=("$(basename "$f")")
      done
    done
    shopt -u nullglob nocaseglob
  fi

  if ((${#files[@]} > 0)); then
    local IFS=$'\n'
    files=($(printf '%s\n' "${files[@]}" | LC_ALL=C sort -fu))
    for name in "${files[@]}"; do
      _items+=("file|${name}")
    done
  fi

  if ((${#_items[@]} > 0)); then
    eval "$varname=(\"\${_items[@]}\")"
  else
    eval "$varname=()"
  fi
}

_MANGO_BROWSE_DIR=""

_mango_browse_item_content() {
  local index="$1"
  local selected="$2"
  local entry="$3"
  local browse_dir="$4"
  local typ="${entry%%|*}"
  local name="${entry#*|}"
  local marker text size

  if [[ "$index" -eq "$selected" ]]; then
    marker="${MANGO_CYAN}${MANGO_BOLD}❯${MANGO_RESET}"
  else
    marker=" "
  fi

  case "$typ" in
    dir)
      if [[ "$name" == ".." ]]; then
        text="${MANGO_YELLOW}../${MANGO_RESET}  ${MANGO_DIM}(parent)${MANGO_RESET}"
      else
        text="${MANGO_CYAN}${name}/${MANGO_RESET}  ${MANGO_DIM}folder${MANGO_RESET}"
      fi
      ;;
    use)
      text="${MANGO_GREEN}${MANGO_BOLD}✓ Use this folder${MANGO_RESET}  ${MANGO_DIM}${name}${MANGO_RESET}"
      ;;
    file)
      size=$(_mango_file_size "$browse_dir/$name")
      text="${MANGO_WHITE}${name}${MANGO_RESET}  ${MANGO_DIM}${size}${MANGO_RESET}"
      ;;
    *)
      text="${MANGO_DIM}${entry}${MANGO_RESET}"
      ;;
  esac
  printf '%s' "  ${marker} ${text}"
}

_mango_browse_item_line() {
  local index="$1"
  local selected="$2"
  local entry="$3"
  local browse_dir="$4"
  _mango_box_line_str "$(_mango_browse_item_content "$index" "$selected" "$entry" "$browse_dir")"
}

_mango_browse_picker_draw_full() {
  local title="$1"
  local browse_dir="$2"
  local selected="$3"
  shift 3
  local -a items=("$@")
  local i=0 row_start

  _MANGO_ITEM_ROWS=()
  _mango_tui_home
  _mango_out ""
  ui_box_open "$title"
  if ((${#items[@]} == 0)); then
    ui_box_line "  ${MANGO_DIM}No matching files under this folder.${MANGO_RESET}"
  else
    for i in "${!items[@]}"; do
      row_start=$_MANGO_TUI_ROW
      ui_box_line "$(_mango_browse_item_content "$i" "$selected" "${items[$i]}" "$browse_dir")"
      _MANGO_ITEM_ROWS+=("$row_start")
    done
  fi
  ui_box_rule
  if ((${#items[@]} == 0)); then
    ui_box_line "  ${MANGO_DIM}P type path · Q go back${MANGO_RESET}"
  else
    ui_box_line "  ${MANGO_DIM}↑↓ navigate · Enter open/select · P type path · Q go back${MANGO_RESET}"
  fi
  ui_box_close
  _mango_out ""
}

# Returns 0 on file/dir entry select, 2 to type a path, 3 to go back.
ui_arrow_select_browse() {
  local varname="$1"
  local title="$2"
  local browse_dir="$3"
  shift 3
  local -a items=("$@")
  local count=${#items[@]}
  local selected=0 key old
  local -a item_rows=()

  _MANGO_BROWSE_DIR="$browse_dir"
  _mango_tui_enter

  _mango_browse_picker_draw_full "$title" "$browse_dir" "$selected" "${items[@]+"${items[@]}"}"
  item_rows=("${_MANGO_ITEM_ROWS[@]}")

  while true; do
    key=$(_mango_read_nav_key)

    case "$key" in
      up)
        [[ "$count" -gt 0 ]] || continue
        old=$selected
        selected=$(( (selected - 1 + count) % count ))
        if [[ "$old" != "$selected" ]]; then
          _mango_redraw_at "${item_rows[$old]}" "$(_mango_browse_item_line "$old" "$selected" "${items[$old]}" "$browse_dir")"
          _mango_redraw_at "${item_rows[$selected]}" "$(_mango_browse_item_line "$selected" "$selected" "${items[$selected]}" "$browse_dir")"
        fi
        ;;
      down)
        [[ "$count" -gt 0 ]] || continue
        old=$selected
        selected=$(( (selected + 1) % count ))
        if [[ "$old" != "$selected" ]]; then
          _mango_redraw_at "${item_rows[$old]}" "$(_mango_browse_item_line "$old" "$selected" "${items[$old]}" "$browse_dir")"
          _mango_redraw_at "${item_rows[$selected]}" "$(_mango_browse_item_line "$selected" "$selected" "${items[$selected]}" "$browse_dir")"
        fi
        ;;
      enter|right)
        [[ "$count" -gt 0 ]] || continue
        _mango_tui_leave
        printf -v "$varname" '%s' "${items[$selected]}"
        return 0
        ;;
      p|P)
        _mango_tui_leave
        return 2
        ;;
      q|Q|esc)
        _mango_tui_leave
        return 3
        ;;
    esac
  done
}

# Returns 0 with full file path, 1 cancel, 2 type path manually.
ui_browse_for_file() {
  local varname="$1"
  shift
  local -a allowed_exts=("$@")
  local browse_dir browse_root filter_label title
  local -a items=()
  local _sel rc typ name full

  browse_dir=$(_mango_expand_path "$(pwd)")
  browse_root="$browse_dir"

  while true; do
    _mango_browse_list_items items "$browse_dir" "$browse_root" "${allowed_exts[@]}"

    if [[ ${#allowed_exts[@]} -gt 0 ]] && ! _mango_exts_is_any "${allowed_exts[@]}"; then
      filter_label=$(_mango_format_ext_label "${allowed_exts[@]}")
    else
      filter_label="any file"
    fi
    title="Select — ${filter_label} · $(_mango_short_path "$browse_dir")"

    ui_arrow_select_browse _sel "$title" "$browse_dir" "${items[@]+"${items[@]}"}"
    rc=$?

    if [[ "$rc" -eq 3 ]]; then
      return 1
    fi
    if [[ "$rc" -eq 2 ]]; then
      return 2
    fi

    typ="${_sel%%|*}"
    name="${_sel#*|}"

    case "$typ" in
      dir)
        if [[ "$name" == ".." ]]; then
          browse_dir=$(_mango_expand_path "$browse_dir/..")
        else
          browse_dir=$(_mango_expand_path "$browse_dir/$name")
        fi
        ;;
      file)
        full=$(_mango_expand_path "$browse_dir/$name")
        printf -v "$varname" '%s' "$full"
        return 0
        ;;
    esac
  done
}

_mango_read_nav_key() {
  local k k2 k3

  IFS= read -rsn1 k
  if [[ "$k" == $'\x1b' ]]; then
    if IFS= read -rsn1 -t 1 k2; then
      if [[ "$k2" == '[' ]]; then
        IFS= read -rsn1 k3
        case "$k3" in
          A) printf '%s' "up"; return 0 ;;
          B) printf '%s' "down"; return 0 ;;
          C) printf '%s' "right"; return 0 ;;
          D) printf '%s' "left"; return 0 ;;
        esac
      fi
    fi
    printf '%s' "esc"
    return 0
  fi

  if [[ -z "$k" || "$k" == $'\n' || "$k" == $'\r' ]]; then
    printf '%s' "enter"
    return 0
  fi

  printf '%s' "$k"
}

_mango_file_item_content() {
  local index="$1"
  local selected="$2"
  local file="$3"
  local size marker

  size=$(_mango_file_size "$file")
  if [[ "$index" -eq "$selected" ]]; then
    marker="${MANGO_CYAN}${MANGO_BOLD}❯${MANGO_RESET}"
  else
    marker=" "
  fi
  printf '%s' "  ${marker} ${MANGO_WHITE}${file}${MANGO_RESET}  ${MANGO_DIM}${size}${MANGO_RESET}"
}

_mango_file_item_line() {
  local index="$1"
  local selected="$2"
  local file="$3"
  _mango_box_line_str "$(_mango_file_item_content "$index" "$selected" "$file")"
}

_mango_file_picker_draw_full() {
  local title="$1"
  local selected="$2"
  shift 2
  local -a items=("$@")
  local i=0 row_start

  _MANGO_ITEM_ROWS=()
  _mango_tui_home
  _mango_out ""
  ui_box_open "$title"
  if ((${#items[@]} == 0)); then
    ui_box_line "  ${MANGO_DIM}No matching files in this directory.${MANGO_RESET}"
  else
    for i in "${!items[@]}"; do
      row_start=$_MANGO_TUI_ROW
      ui_box_line "$(_mango_file_item_content "$i" "$selected" "${items[$i]}")"
      _MANGO_ITEM_ROWS+=("$row_start")
    done
  fi
  ui_box_rule
  if ((${#items[@]} == 0)); then
    ui_box_line "  ${MANGO_DIM}P type path · Q go back${MANGO_RESET}"
  else
    ui_box_line "  ${MANGO_DIM}↑↓ navigate · Enter select · P type path · Q go back${MANGO_RESET}"
  fi
  ui_box_close
  _mango_out ""
}

# Returns 0 on select, 2 to type a path, 3 to go back.
ui_arrow_select_file() {
  local varname="$1"
  local title="$2"
  shift 2
  local -a items=("$@")
  local count=${#items[@]}
  local selected=0 key old
  local -a item_rows=()

  _mango_tui_enter

  _mango_file_picker_draw_full "$title" "$selected" "${items[@]}"
  item_rows=("${_MANGO_ITEM_ROWS[@]}")

  while true; do
    key=$(_mango_read_nav_key)

    case "$key" in
      up)
        [[ "$count" -gt 0 ]] || continue
        old=$selected
        selected=$(( (selected - 1 + count) % count ))
        if [[ "$old" != "$selected" ]]; then
          _mango_redraw_at "${item_rows[$old]}" "$(_mango_file_item_line "$old" "$selected" "${items[$old]}")"
          _mango_redraw_at "${item_rows[$selected]}" "$(_mango_file_item_line "$selected" "$selected" "${items[$selected]}")"
        fi
        ;;
      down)
        [[ "$count" -gt 0 ]] || continue
        old=$selected
        selected=$(( (selected + 1) % count ))
        if [[ "$old" != "$selected" ]]; then
          _mango_redraw_at "${item_rows[$old]}" "$(_mango_file_item_line "$old" "$selected" "${items[$old]}")"
          _mango_redraw_at "${item_rows[$selected]}" "$(_mango_file_item_line "$selected" "$selected" "${items[$selected]}")"
        fi
        ;;
      enter)
        [[ "$count" -gt 0 ]] || continue
        _mango_tui_leave
        printf -v "$varname" '%s' "${items[$selected]}"
        return 0
        ;;
      p|P)
        _mango_tui_leave
        return 2
        ;;
      q|Q|esc)
        _mango_tui_leave
        return 3
        ;;
    esac
  done
}

ui_list_matching_files() {
  local -a exts=("$@")
  local -a found=()

  _mango_read_into_array found "${exts[@]}"
  [[ ${#found[@]} -gt 0 ]] || return 1

  ui_box_open "Files in $(pwd)"
  local i=1
  for f in "${found[@]}"; do
    local size
    size=$(_mango_file_size "$f")
    ui_box_line "  ${MANGO_DIM}${i})${MANGO_RESET} ${MANGO_WHITE}${f}${MANGO_RESET}  ${MANGO_DIM}${size}${MANGO_RESET}"
    ((i++)) || true
  done
  ui_box_close
  echo ""
  return 0
}

ui_prompt_file() {
  local message="$1"
  local varname="$2"
  shift 2
  local -a allowed_exts=("$@")

  while true; do
    local rc path

    ui_browse_for_file "$varname" "${allowed_exts[@]}"
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      return 0
    elif [[ "$rc" -eq 1 ]]; then
      return 1
    fi

    ui_clear
    echo ""

    ui_prompt "$message" _MANGO_FILE_INPUT
    local raw="$_MANGO_FILE_INPUT"
    [[ -z "$raw" ]] && continue

    path=$(_mango_expand_path "$raw")

    if [[ ! -e "$path" ]]; then
      ui_message error "File not found: ${raw}"
      echo ""
      continue
    fi
    if [[ ! -f "$path" ]]; then
      ui_message error "Not a regular file: ${raw}"
      echo ""
      continue
    fi

    if [[ ${#allowed_exts[@]} -gt 0 ]] && ! _mango_exts_is_any "${allowed_exts[@]}"; then
      local ext="${path##*.}"
      ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
      local ok=0 allowed
      for allowed in "${allowed_exts[@]}"; do
        if [[ "$ext" == "$(printf '%s' "$allowed" | tr '[:upper:]' '[:lower:]')" ]]; then
          ok=1
          break
        fi
      done
      if [[ "$ok" -eq 0 ]]; then
        local joined
        joined=$(_mango_format_ext_label "${allowed_exts[@]}")
        ui_message warning "Expected ${joined}  (got .${ext})"
        echo ""
        continue
      fi
    fi

    printf -v "$varname" '%s' "$path"
    return 0
  done
}

# Multi-select image browser for Images → PDF.
# Space toggles images; Enter converts selection (or opens folders / uses whole folder).
# Returns 0 with selected paths in nameref array, 1 cancel, 2 type path.
ui_browse_for_image_folder() {
  local varname="$1"
  shift
  local -a allowed_exts=("$@")
  local browse_dir browse_root filter_label title
  local -a items=() files=() dirs=() checked=()
  local selected=0 key old i n typ name line count file_start

  browse_dir=$(_mango_expand_path "$(pwd)")
  browse_root="$browse_dir"

  _mango_img_picker_rebuild() {
    items=()
    files=()
    dirs=()
    checked=()
    n=0
    file_start=-1

    while IFS= read -r line; do
      [[ -n "$line" ]] && files+=("$line")
    done < <(_mango_collect_matching_in_dir "$browse_dir" "${allowed_exts[@]}") || true
    n=${#files[@]}

    if [[ "$n" -gt 0 ]]; then
      if [[ "$n" -eq 1 ]]; then
        items+=("use|1 image → one PDF")
      else
        items+=("use|${n} images → one PDF")
      fi
    fi

    if [[ "$browse_dir" != "$browse_root" ]]; then
      items+=("dir|..")
    fi

    shopt -s nullglob
    local d dname
    for d in "$browse_dir"/*/; do
      [[ -d "$d" ]] || continue
      dname=$(basename "$d")
      [[ "$dname" == .* ]] && continue
      if _mango_dir_has_matching_files "$d" "${allowed_exts[@]}"; then
        dirs+=("$dname")
      fi
    done
    shopt -u nullglob

    if ((${#dirs[@]} > 0)); then
      local IFS=$'\n'
      dirs=($(printf '%s\n' "${dirs[@]}" | LC_ALL=C sort -f))
      for dname in "${dirs[@]}"; do
        items+=("dir|${dname}")
      done
    fi

    file_start=${#items[@]}
    local f base
    for f in "${files[@]+"${files[@]}"}"; do
      base=$(basename "$f")
      items+=("file|${base}")
      checked+=("0")
    done
  }

  _mango_img_item_content() {
    local index="$1"
    local cur="$2"
    local entry="$3"
    local typ="${entry%%|*}"
    local name="${entry#*|}"
    local marker text size box=""
    local fi=$((index - file_start))

    if [[ "$index" -eq "$cur" ]]; then
      marker="${MANGO_CYAN}${MANGO_BOLD}❯${MANGO_RESET}"
    else
      marker=" "
    fi

    case "$typ" in
      use)
        text="${MANGO_GREEN}${MANGO_BOLD}✓ ${name}${MANGO_RESET}"
        ;;
      dir)
        if [[ "$name" == ".." ]]; then
          text="${MANGO_YELLOW}../${MANGO_RESET}  ${MANGO_DIM}(parent)${MANGO_RESET}"
        else
          text="${MANGO_CYAN}${name}/${MANGO_RESET}  ${MANGO_DIM}folder${MANGO_RESET}"
        fi
        ;;
      file)
        size=$(_mango_file_size "$browse_dir/$name")
        if [[ "${checked[$fi]}" == "1" ]]; then
          box="${MANGO_GREEN}[x]${MANGO_RESET} "
        else
          box="${MANGO_DIM}[ ]${MANGO_RESET} "
        fi
        text="${box}${MANGO_WHITE}${name}${MANGO_RESET}  ${MANGO_DIM}${size}${MANGO_RESET}"
        ;;
      *)
        text="${MANGO_DIM}${entry}${MANGO_RESET}"
        ;;
    esac
    printf '%s' "  ${marker} ${text}"
  }

  _mango_img_picker_draw() {
    local cur="$1"
    local i row_start
    _MANGO_ITEM_ROWS=()
    _mango_tui_home
    _mango_out ""
    ui_box_open "$title"
    if ((${#items[@]} == 0)); then
      ui_box_line "  ${MANGO_DIM}No matching images under this folder.${MANGO_RESET}"
    else
      for i in "${!items[@]}"; do
        row_start=$_MANGO_TUI_ROW
        ui_box_line "$(_mango_img_item_content "$i" "$cur" "${items[$i]}")"
        _MANGO_ITEM_ROWS+=("$row_start")
      done
    fi
    ui_box_rule
    ui_box_line "  ${MANGO_DIM}↑↓ move · Space toggle · Enter convert (needs [x]) · P path · Q cancel${MANGO_RESET}"
    ui_box_close
    _mango_out ""
  }

  while true; do
    _mango_img_picker_rebuild
    selected=0

    if [[ ${#allowed_exts[@]} -gt 0 ]] && ! _mango_exts_is_any "${allowed_exts[@]}"; then
      filter_label=$(_mango_format_ext_label "${allowed_exts[@]}")
    else
      filter_label="images"
    fi
    title="Pick images — ${filter_label} · $(_mango_short_path "$browse_dir")"

    _mango_tui_enter
    _mango_img_picker_draw "$selected"
    local -a item_rows=("${_MANGO_ITEM_ROWS[@]}")
    count=${#items[@]}

    while true; do
      key=$(_mango_read_nav_key)

      case "$key" in
        up)
          [[ "$count" -gt 0 ]] || continue
          old=$selected
          selected=$(( (selected - 1 + count) % count ))
          if [[ "$old" != "$selected" ]]; then
            _mango_redraw_at "${item_rows[$old]}" "$(_mango_box_line_str "$(_mango_img_item_content "$old" "$selected" "${items[$old]}")")"
            _mango_redraw_at "${item_rows[$selected]}" "$(_mango_box_line_str "$(_mango_img_item_content "$selected" "$selected" "${items[$selected]}")")"
          fi
          ;;
        down)
          [[ "$count" -gt 0 ]] || continue
          old=$selected
          selected=$(( (selected + 1) % count ))
          if [[ "$old" != "$selected" ]]; then
            _mango_redraw_at "${item_rows[$old]}" "$(_mango_box_line_str "$(_mango_img_item_content "$old" "$selected" "${items[$old]}")")"
            _mango_redraw_at "${item_rows[$selected]}" "$(_mango_box_line_str "$(_mango_img_item_content "$selected" "$selected" "${items[$selected]}")")"
          fi
          ;;
        " ")
          [[ "$count" -gt 0 ]] || continue
          typ="${items[$selected]%%|*}"
          if [[ "$typ" != "file" ]]; then
            continue
          fi
          i=$((selected - file_start))
          if [[ "${checked[$i]}" == "1" ]]; then
            checked[$i]=0
          else
            checked[$i]=1
          fi
          _mango_redraw_at "${item_rows[$selected]}" "$(_mango_box_line_str "$(_mango_img_item_content "$selected" "$selected" "${items[$selected]}")")"
          ;;
        enter|right)
          [[ "$count" -gt 0 ]] || continue
          typ="${items[$selected]%%|*}"
          name="${items[$selected]#*|}"

          if [[ "$typ" == "dir" ]]; then
            _mango_tui_leave
            if [[ "$name" == ".." ]]; then
              browse_dir=$(_mango_expand_path "$browse_dir/..")
            else
              browse_dir=$(_mango_expand_path "$browse_dir/$name")
            fi
            break
          fi

          if [[ "$typ" == "use" ]]; then
            _mango_tui_leave
            eval "$varname=(\"\${files[@]}\")"
            return 0
          fi

          if [[ "$typ" == "file" ]]; then
            local -a picked=()
            for ((i = 0; i < ${#files[@]}; i++)); do
              if [[ "${checked[$i]}" == "1" ]]; then
                picked+=("${files[$i]}")
              fi
            done
            if [[ ${#picked[@]} -eq 0 ]]; then
              # Nothing selected yet — mark the highlighted image; Enter again to convert.
              i=$((selected - file_start))
              checked[$i]=1
              _mango_redraw_at "${item_rows[$selected]}" "$(_mango_box_line_str "$(_mango_img_item_content "$selected" "$selected" "${items[$selected]}")")"
              continue
            fi
            _mango_tui_leave
            eval "$varname=(\"\${picked[@]}\")"
            return 0
          fi
          ;;
        p|P)
          _mango_tui_leave
          return 2
          ;;
        q|Q|esc)
          _mango_tui_leave
          return 1
          ;;
      esac
    done
  done
}

# Resolve selected images: multi-select in a folder, or type a folder/file path.
# Fills nameref array with chosen image paths (selection order / name order for whole folder).
ui_prompt_image_folder() {
  local message="$1"
  local varname="$2"
  shift 2
  local -a allowed_exts=("$@")

  _mango_load_images_from_dir() {
    local dir="$1"
    local -a dir_files=()
    local line
    while IFS= read -r line; do
      [[ -n "$line" ]] && dir_files+=("$line")
    done < <(_mango_collect_matching_in_dir "$dir" "${allowed_exts[@]}") || true
    if [[ ${#dir_files[@]} -eq 0 ]]; then
      return 1
    fi
    eval "$varname=(\"\${dir_files[@]}\")"
    return 0
  }

  while true; do
    local rc path dir

    ui_browse_for_image_folder "$varname" "${allowed_exts[@]}"
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      return 0
    elif [[ "$rc" -eq 1 ]]; then
      return 1
    fi

    ui_clear
    echo ""

    ui_prompt "$message" _MANGO_FILE_INPUT
    local raw="$_MANGO_FILE_INPUT"
    [[ -z "$raw" ]] && continue

    path=$(_mango_expand_path "$raw")
    if [[ ! -e "$path" ]]; then
      ui_message error "Not found: ${raw}"
      echo ""
      continue
    fi
    if [[ -d "$path" ]]; then
      dir="$path"
    elif [[ -f "$path" ]]; then
      dir="$(dirname "$path")"
    else
      ui_message error "Not a file or folder: ${raw}"
      echo ""
      continue
    fi
    if _mango_load_images_from_dir "$dir"; then
      return 0
    fi
    ui_message error "No matching images in folder: ${dir}"
    echo ""
  done
}

ui_conversion_preview() {
  local input="$1"
  local output="$2"
  local label="${3:-Conversion}"

  local in_base out_base in_ext out_ext
  in_base=$(basename "$input")
  out_base=$(basename "$output")
  in_ext="${in_base##*.}"
  out_ext="${out_base##*.}"
  local in_size
  in_size=$(_mango_file_size "$input")

  ui_box_open "$label"
  ui_box_line "  ${MANGO_DIM}From:${MANGO_RESET}  ${MANGO_WHITE}${in_base}${MANGO_RESET}  ${MANGO_DIM}${in_size}${MANGO_RESET}"
  ui_box_line "  ${MANGO_DIM}       ${MANGO_FG_MANGO}↓${MANGO_RESET}"
  ui_box_line "  ${MANGO_DIM}To:${MANGO_RESET}    ${MANGO_GREEN}${out_base}${MANGO_RESET}  ${MANGO_DIM}.${out_ext}${MANGO_RESET}"
  ui_box_close
  echo ""
}

ui_conversion_preview_multi() {
  local output="$1"
  local label="$2"
  shift 2
  local -a files=("$@")
  local n=${#files[@]}
  local out_base first
  out_base=$(basename "$output")
  first=$(basename "${files[0]}")

  ui_box_open "$label"
  if [[ "$n" -eq 1 ]]; then
    local in_size
    in_size=$(_mango_file_size "${files[0]}")
    ui_box_line "  ${MANGO_DIM}From:${MANGO_RESET}  ${MANGO_WHITE}${first}${MANGO_RESET}  ${MANGO_DIM}${in_size}${MANGO_RESET}"
  else
    ui_box_line "  ${MANGO_DIM}From:${MANGO_RESET}  ${MANGO_WHITE}${n} images${MANGO_RESET}  ${MANGO_DIM}in $(basename "$(dirname "${files[0]}")")${MANGO_RESET}"
  fi
  ui_box_line "  ${MANGO_DIM}       ${MANGO_FG_MANGO}↓${MANGO_RESET}"
  ui_box_line "  ${MANGO_DIM}To:${MANGO_RESET}    ${MANGO_GREEN}${out_base}${MANGO_RESET}  ${MANGO_DIM}.pdf${MANGO_RESET}"
  ui_box_close
  echo ""
}

ui_confirm() {
  local message="${1:-Proceed?}"
  local varname="${2:-_MANGO_CONFIRM}"
  echo -ne "  ${MANGO_YELLOW}?${MANGO_RESET} ${message} ${MANGO_DIM}[y/N]${MANGO_RESET} "
  local answer
  read -r answer
  case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')" in
    y|yes) printf -v "$varname" '%s' "yes"; return 0 ;;
    *) printf -v "$varname" '%s' "no"; return 1 ;;
  esac
}

ui_menu_numbered() {
  local title="$1"
  shift
  local -a items=("$@")

  ui_box_open "$title"
  local i=1
  for item in "${items[@]}"; do
    local label status icon color
    label="${item%%|*}"
    status="${item#*|}"

    if [[ "$status" == "ready" ]]; then
      icon="●"
      color="$MANGO_GREEN"
    elif [[ "$status" == "soon" ]]; then
      icon="○"
      color="$MANGO_DIM"
    else
      icon="·"
      color="$MANGO_WHITE"
    fi

    if [[ "$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]')" == "back" ]]; then
      ui_box_line "  ${MANGO_DIM}${i})${MANGO_RESET} ${MANGO_DIM}← ${label}${MANGO_RESET}"
    elif [[ "$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]')" == "exit" ]]; then
      ui_box_line "  ${MANGO_RED}${MANGO_BOLD}${i})${MANGO_RESET} ${MANGO_RED}${label}${MANGO_RESET}"
    else
      ui_box_line "  ${color}${icon}${MANGO_RESET}  ${MANGO_GREEN}${MANGO_BOLD}${i})${MANGO_RESET} ${color}${label}${MANGO_RESET}"
    fi
    ((i++)) || true
  done
  ui_box_close
  echo ""
}

ui_suggest_output() {
  local input="$1"
  local new_ext="$2"
  local dir base
  dir=$(dirname "$input")
  base=$(basename "$input")
  base="${base%.*}"
  echo "${dir}/${base}.${new_ext}"
}

# Unique dated name for multi-file outputs: merged_pdf_2026-08-27_162745.pdf
ui_suggest_merged_output() {
  local dir="$1"
  local prefix="${2:-merged_pdf}"
  local ext="${3:-pdf}"
  local stamp candidate n=0
  stamp=$(date '+%Y-%m-%d_%H%M%S')
  candidate="${dir}/${prefix}_${stamp}.${ext}"
  while [[ -e "$candidate" ]]; do
    n=$((n + 1))
    candidate="${dir}/${prefix}_${stamp}_${n}.${ext}"
  done
  printf '%s' "$candidate"
}

# Resolve a typed output: bare names land next to the source folder; add .ext if missing.
ui_resolve_output_path() {
  local raw="$1"
  local base_dir="$2"
  local default_ext="${3:-pdf}"
  local path

  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"
  [[ -n "$raw" ]] || {
    printf '%s' ""
    return 1
  }

  if [[ "$raw" == */* || "$raw" == ~* ]]; then
    path=$(_mango_expand_path "$raw")
  else
    path="${base_dir}/${raw}"
  fi

  if [[ "$path" != *.* ]]; then
    path="${path}.${default_ext}"
  fi
  printf '%s' "$path"
}
