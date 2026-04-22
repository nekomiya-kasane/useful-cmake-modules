# ============================================================================
# CMakePrettyPrint.cmake — ANSI-colored CLI output utilities for CMake
# ============================================================================
#
# Provides a complete set of ANSI escape codes, semantic color aliases,
# box-drawing table primitives, and formatted message functions for
# producing readable, colorful CMake configure output.
#
# Usage:
#   include(CMakePrettyPrint)
#   pp_msg(INFO "Configuring target: MyLib")
#   pp_msg(OK   "All checks passed")
#   pp_msg(WARN "Deprecated API detected")
#   pp_msg(FAIL "Missing required dependency")
#
#   pp_table_begin("Build Configuration" COLUMNS 22 42)
#   pp_table_row("Compiler" "Clang 20.1")
#   pp_table_sep()
#   pp_table_row("C++ Standard" "23")
#   pp_table_end()
#
#   pp_list_begin("Enabled Features")
#   pp_list_item("Sanitizers" ON)
#   pp_list_item("Coverage"   OFF)
#   pp_list_end()
#
#   pp_header("Phase 2: Linking")
#   pp_kv("Target" "gin" "Platform" "win-x64")
#   pp_banner("BUILD COMPLETE" OK)
#
# All public symbols use the `pp_` prefix. All internal symbols use `_pp_`.
# ============================================================================

include_guard(GLOBAL)

# ── 1. Terminal capability detection ──────────────────────────────────
#
# Detect whether the current terminal supports ANSI escape sequences.
# On Windows, modern terminals (Windows Terminal, VS Code, ConEmu) all
# support VT100. Legacy cmd.exe with older Windows does not, but CMake
# 3.24+ sets CMAKE_COLOR_DIAGNOSTICS. We default to ON unless explicitly
# disabled or running in a known-dumb terminal.

if(DEFINED PP_FORCE_COLOR)
  set(_PP_COLOR_ENABLED ${PP_FORCE_COLOR})
elseif(DEFINED ENV{NO_COLOR})
  # https://no-color.org/ — respect the NO_COLOR convention
  set(_PP_COLOR_ENABLED OFF)
elseif(DEFINED ENV{TERM} AND "$ENV{TERM}" STREQUAL "dumb")
  set(_PP_COLOR_ENABLED OFF)
else()
  set(_PP_COLOR_ENABLED ON)
endif()

# ── 2. ANSI escape code definitions ──────────────────────────────────
#
# Raw escape character (ESC = 0x1B = ASCII 27).
# All codes follow the CSI (Control Sequence Introducer) format: ESC[ ... m

if(_PP_COLOR_ENABLED)
  string(ASCII 27 _PP_ESC)
else()
  set(_PP_ESC "")
endif()

# Helper: define an ANSI variable. No-op when color is disabled.
macro(_pp_def VAR CODE)
  if(_PP_COLOR_ENABLED)
    set(${VAR} "${_PP_ESC}[${CODE}m")
  else()
    set(${VAR} "")
  endif()
endmacro()

# ── 2.1 Reset ──
_pp_def(PP_RST    "0")

# ── 2.2 Text attributes ──
_pp_def(PP_BOLD   "1")
_pp_def(PP_DIM    "2")
_pp_def(PP_ITAL   "3")
_pp_def(PP_ULINE  "4")
_pp_def(PP_BLINK  "5")
_pp_def(PP_INVERT "7")
_pp_def(PP_HIDDEN "8")
_pp_def(PP_STRIKE "9")

# ── 2.3 Foreground colors (standard 8) ──
_pp_def(PP_FG_BLACK   "30")
_pp_def(PP_FG_RED     "31")
_pp_def(PP_FG_GREEN   "32")
_pp_def(PP_FG_YELLOW  "33")
_pp_def(PP_FG_BLUE    "34")
_pp_def(PP_FG_MAGENTA "35")
_pp_def(PP_FG_CYAN    "36")
_pp_def(PP_FG_WHITE   "37")

# ── 2.4 Foreground colors (bright / high-intensity) ──
_pp_def(PP_FG_BRIGHT_BLACK   "90")
_pp_def(PP_FG_BRIGHT_RED     "91")
_pp_def(PP_FG_BRIGHT_GREEN   "92")
_pp_def(PP_FG_BRIGHT_YELLOW  "93")
_pp_def(PP_FG_BRIGHT_BLUE    "94")
_pp_def(PP_FG_BRIGHT_MAGENTA "95")
_pp_def(PP_FG_BRIGHT_CYAN    "96")
_pp_def(PP_FG_BRIGHT_WHITE   "97")

# ── 2.5 Background colors (standard 8) ──
_pp_def(PP_BG_BLACK   "40")
_pp_def(PP_BG_RED     "41")
_pp_def(PP_BG_GREEN   "42")
_pp_def(PP_BG_YELLOW  "43")
_pp_def(PP_BG_BLUE    "44")
_pp_def(PP_BG_MAGENTA "45")
_pp_def(PP_BG_CYAN    "46")
_pp_def(PP_BG_WHITE   "47")

# ── 2.6 Background colors (bright / high-intensity) ──
_pp_def(PP_BG_BRIGHT_BLACK   "100")
_pp_def(PP_BG_BRIGHT_RED     "101")
_pp_def(PP_BG_BRIGHT_GREEN   "102")
_pp_def(PP_BG_BRIGHT_YELLOW  "103")
_pp_def(PP_BG_BRIGHT_BLUE    "104")
_pp_def(PP_BG_BRIGHT_MAGENTA "105")
_pp_def(PP_BG_BRIGHT_CYAN    "106")
_pp_def(PP_BG_BRIGHT_WHITE   "107")

# ── 2.7 Compound styles (bold + color) ──
_pp_def(PP_BOLD_RED     "1;31")
_pp_def(PP_BOLD_GREEN   "1;32")
_pp_def(PP_BOLD_YELLOW  "1;33")
_pp_def(PP_BOLD_BLUE    "1;34")
_pp_def(PP_BOLD_MAGENTA "1;35")
_pp_def(PP_BOLD_CYAN    "1;36")
_pp_def(PP_BOLD_WHITE   "1;37")

# ── 3. Semantic color aliases ─────────────────────────────────────────
#
# Use these for consistent meaning across all CMake output.
# Each alias maps to a raw ANSI code for easy customization.

_pp_def(PP_C_OK      "32")        # green — success, enabled, passed
_pp_def(PP_C_FAIL    "31")        # red — failure, disabled, error
_pp_def(PP_C_WARN    "33")        # yellow — warning, caution
_pp_def(PP_C_INFO    "36")        # cyan — informational
_pp_def(PP_C_DEBUG   "90")        # dim gray — debug / verbose
_pp_def(PP_C_ACCENT  "35")        # magenta — highlight, accent

_pp_def(PP_C_BOX     "90")        # dim gray — box-drawing characters
_pp_def(PP_C_TITLE   "1;36")      # bold cyan — titles, headers
_pp_def(PP_C_KEY     "1;37")      # bold white — key labels in tables
_pp_def(PP_C_VAL     "33")        # yellow — generic values
_pp_def(PP_C_ON      "32")        # green — TRUE / ON / enabled / included
_pp_def(PP_C_OFF     "31")        # red — FALSE / OFF / disabled
_pp_def(PP_C_PATH    "4;36")      # underline cyan — file paths
_pp_def(PP_C_NUM     "93")        # bright yellow — numbers
_pp_def(PP_C_TAG     "3;90")      # dim italic — section tags, annotations
_pp_def(PP_C_TARGET  "1;33")      # bold yellow — target names
_pp_def(PP_C_CMD     "1;32")      # bold green — command names
_pp_def(PP_C_PHASE   "1;35")      # bold magenta — build phases

# ── 4. Unicode glyphs ────────────────────────────────────────────────
#
# Common glyphs used as status prefixes. These require UTF-8 terminal
# support which is standard on all modern platforms.

set(PP_CHECK  "✓")
set(PP_CROSS  "✗")
set(PP_ARROW  "→")
set(PP_BULLET "•")
set(PP_DOT    "·")
set(PP_STAR   "★")
set(PP_WARN_ICON "⚠")
set(PP_INFO_ICON "ℹ")
set(PP_GEAR   "⚙")
set(PP_LOCK   "🔒")
set(PP_ROCKET "🚀")

# ── 5. Formatted message functions ───────────────────────────────────
#
#   pp_msg(<LEVEL> <text>...)
#
# LEVEL: OK | FAIL | WARN | INFO | DEBUG | NOTE | PHASE
# Prints a single-line message with a colored prefix icon.

function(pp_msg LEVEL)
  string(JOIN " " _text ${ARGN})

  if(LEVEL STREQUAL "OK")
    message(STATUS "${PP_C_OK}${PP_CHECK}${PP_RST} ${_text}")
  elseif(LEVEL STREQUAL "FAIL")
    message(STATUS "${PP_C_FAIL}${PP_CROSS}${PP_RST} ${_text}")
  elseif(LEVEL STREQUAL "WARN")
    message(STATUS "${PP_C_WARN}${PP_WARN_ICON}${PP_RST} ${_text}")
  elseif(LEVEL STREQUAL "INFO")
    message(STATUS "${PP_C_INFO}${PP_INFO_ICON}${PP_RST} ${_text}")
  elseif(LEVEL STREQUAL "DEBUG")
    message(STATUS "${PP_C_DEBUG}${PP_DOT}${PP_RST} ${PP_C_DEBUG}${_text}${PP_RST}")
  elseif(LEVEL STREQUAL "NOTE")
    message(STATUS "${PP_C_INFO}${PP_ARROW}${PP_RST} ${_text}")
  elseif(LEVEL STREQUAL "PHASE")
    message(STATUS "")
    message(STATUS "${PP_C_PHASE}${PP_GEAR} ${_text}${PP_RST}")
  else()
    message(STATUS "${_text}")
  endif()
endfunction()

# ── 6. Key-value pair output ─────────────────────────────────────────
#
#   pp_kv(<key1> <val1> [<key2> <val2>]...)
#
# Prints key-value pairs in a compact "key: value" format.
# Boolean values (TRUE/ON/FALSE/OFF) are auto-colored.

function(pp_kv)
  set(_args ${ARGN})
  list(LENGTH _args _len)
  math(EXPR _pairs "${_len} / 2")
  set(_idx 0)
  while(_idx LESS _len)
    math(EXPR _vidx "${_idx} + 1")
    list(GET _args ${_idx} _k)
    list(GET _args ${_vidx} _v)
    _pp_colorize_value(_cv "${_v}")
    message(STATUS "  ${PP_C_KEY}${_k}:${PP_RST} ${_cv}")
    math(EXPR _idx "${_idx} + 2")
  endwhile()
endfunction()

# ── 7. Box-drawing table primitives ──────────────────────────────────
#
# A stateful table system that tracks column widths. Usage:
#
#   pp_table_begin("My Title" [COLUMNS <key_w> <val_w>])
#   pp_table_row("Key" "Value")
#   pp_table_sep()
#   pp_table_row("Key2" "Value2")
#   pp_table_end()
#
# Default column widths: key=22, value=42.

function(pp_table_begin TITLE)
  cmake_parse_arguments(_T "" "" "COLUMNS" ${ARGN})
  if(_T_COLUMNS)
    list(GET _T_COLUMNS 0 _kw)
    list(GET _T_COLUMNS 1 _vw)
  else()
    set(_kw 22)
    set(_vw 42)
  endif()

  # Store state in parent scope (CMake functions create a new scope)
  set(_PP_TABLE_KEY_W ${_kw} PARENT_SCOPE)
  set(_PP_TABLE_VAL_W ${_vw} PARENT_SCOPE)

  # Build box-drawing strings
  string(REPEAT "─" ${_kw} _kl)
  string(REPEAT "─" ${_vw} _vl)

  math(EXPR _iw "${_kw} + 1 + ${_vw}")
  string(REPEAT "─" ${_iw} _full)

  # Center the title
  string(LENGTH "${TITLE}" _tlen)
  math(EXPR _tpad "${_iw} - ${_tlen}")
  if(_tpad LESS 0)
    set(_tpad 0)
  endif()
  math(EXPR _tlp "${_tpad} / 2")
  math(EXPR _trp "${_tpad} - ${_tlp}")
  string(REPEAT " " ${_tlp} _tl)
  string(REPEAT " " ${_trp} _tr)

  message(STATUS "")
  message(STATUS "${PP_C_BOX}┌${_full}┐${PP_RST}")
  message(STATUS "${PP_C_BOX}│${PP_RST}${_tl}${PP_C_TITLE}${TITLE}${PP_RST}${_tr}${PP_C_BOX}│${PP_RST}")

  string(REPEAT "─" ${_kw} _kl_sep)
  string(REPEAT "─" ${_vw} _vl_sep)
  message(STATUS "${PP_C_BOX}├${_kl_sep}┼${_vl_sep}┤${PP_RST}")
endfunction()

function(pp_table_row KEY VAL)
  _pp_pad(_rk "${KEY}" ${_PP_TABLE_KEY_W})
  _pp_pad(_rv "${VAL}" ${_PP_TABLE_VAL_W})
  _pp_value_color(_vc "${VAL}")
  message(STATUS "${PP_C_BOX}│${PP_RST} ${PP_C_KEY}${_rk}${PP_RST} ${PP_C_BOX}│${PP_RST} ${_vc}${_rv}${PP_RST} ${PP_C_BOX}│${PP_RST}")
endfunction()

function(pp_table_sep)
  string(REPEAT "─" ${_PP_TABLE_KEY_W} _kl)
  string(REPEAT "─" ${_PP_TABLE_VAL_W} _vl)
  message(STATUS "${PP_C_BOX}├${_kl}┼${_vl}┤${PP_RST}")
endfunction()

function(pp_table_end)
  string(REPEAT "─" ${_PP_TABLE_KEY_W} _kl)
  string(REPEAT "─" ${_PP_TABLE_VAL_W} _vl)
  message(STATUS "${PP_C_BOX}└${_kl}┴${_vl}┘${PP_RST}")
  message(STATUS "")
endfunction()

# ── 8. List output ───────────────────────────────────────────────────
#
#   pp_list_begin("Section Title")
#   pp_list_item("Feature Name" ON)
#   pp_list_item("Feature Name" "custom value")
#   pp_list_end()

function(pp_list_begin TITLE)
  message(STATUS "")
  message(STATUS "${PP_C_TITLE}${TITLE}${PP_RST}")
  string(LENGTH "${TITLE}" _tlen)
  string(REPEAT "─" ${_tlen} _underline)
  message(STATUS "${PP_C_BOX}${_underline}${PP_RST}")
endfunction()

function(pp_list_item NAME)
  set(_val "${ARGN}")
  if("${_val}" STREQUAL "")
    message(STATUS "  ${PP_C_INFO}${PP_BULLET}${PP_RST} ${NAME}")
  else()
    _pp_colorize_value(_cv "${_val}")
    message(STATUS "  ${PP_C_INFO}${PP_BULLET}${PP_RST} ${PP_C_KEY}${NAME}${PP_RST}: ${_cv}")
  endif()
endfunction()

function(pp_list_end)
  message(STATUS "")
endfunction()

# ── 9. Section header ────────────────────────────────────────────────
#
#   pp_header("Phase 2: Linking")
#
# Prints a full-width decorated section header.

function(pp_header TEXT)
  set(_total_w 66)
  string(LENGTH "${TEXT}" _tlen)
  math(EXPR _fill "${_total_w} - ${_tlen} - 4")
  if(_fill LESS 2)
    set(_fill 2)
  endif()
  string(REPEAT "─" ${_fill} _line)
  message(STATUS "")
  message(STATUS "${PP_C_BOX}── ${PP_RST}${PP_C_TITLE}${TEXT}${PP_RST} ${PP_C_BOX}${_line}${PP_RST}")
endfunction()

# ── 10. Banner ───────────────────────────────────────────────────────
#
#   pp_banner("BUILD COMPLETE" OK)
#   pp_banner("BUILD FAILED"   FAIL)
#
# Large, prominent single-line banner with full-width decoration.

function(pp_banner TEXT LEVEL)
  set(_w 66)
  string(REPEAT "═" ${_w} _bar)

  if(LEVEL STREQUAL "OK")
    set(_c ${PP_BOLD_GREEN})
    set(_icon "${PP_ROCKET} ")
  elseif(LEVEL STREQUAL "FAIL")
    set(_c ${PP_BOLD_RED})
    set(_icon "${PP_CROSS} ")
  elseif(LEVEL STREQUAL "WARN")
    set(_c ${PP_BOLD_YELLOW})
    set(_icon "${PP_WARN_ICON} ")
  else()
    set(_c ${PP_BOLD_CYAN})
    set(_icon "")
  endif()

  message(STATUS "")
  message(STATUS "${_c}${_bar}${PP_RST}")
  # Center the text
  string(LENGTH "${TEXT}" _tlen)
  math(EXPR _pad "${_w} - ${_tlen} - 2")
  if(_pad LESS 0)
    set(_pad 0)
  endif()
  math(EXPR _lp "${_pad} / 2")
  math(EXPR _rp "${_pad} - ${_lp}")
  string(REPEAT " " ${_lp} _ls)
  string(REPEAT " " ${_rp} _rs)
  message(STATUS "${_c}${_ls}${_icon}${TEXT}${_rs}${PP_RST}")
  message(STATUS "${_c}${_bar}${PP_RST}")
  message(STATUS "")
endfunction()

# ── 11. Progress indicator ───────────────────────────────────────────
#
#   pp_progress(<current> <total> <label>)
#
# Prints a text-based progress bar: [████████░░░░░░░░] 50% label

function(pp_progress CURRENT TOTAL LABEL)
  set(_bar_w 30)
  if(TOTAL GREATER 0)
    math(EXPR _pct "(${CURRENT} * 100) / ${TOTAL}")
    math(EXPR _filled "(${CURRENT} * ${_bar_w}) / ${TOTAL}")
  else()
    set(_pct 0)
    set(_filled 0)
  endif()
  math(EXPR _empty "${_bar_w} - ${_filled}")
  string(REPEAT "█" ${_filled} _bar_filled)
  string(REPEAT "░" ${_empty} _bar_empty)

  if(_pct LESS 33)
    set(_c ${PP_C_FAIL})
  elseif(_pct LESS 66)
    set(_c ${PP_C_WARN})
  else()
    set(_c ${PP_C_OK})
  endif()

  message(STATUS "  ${PP_C_BOX}[${PP_RST}${_c}${_bar_filled}${PP_RST}${PP_C_BOX}${_bar_empty}]${PP_RST} ${_c}${_pct}%${PP_RST} ${LABEL}")
endfunction()

# ── 12. Scope / context label ────────────────────────────────────────
#
#   pp_scope("Coverage" "target" "gin")
#
# Prints: Coverage [gin]: <subsequent text>
# This is the pattern used by PGO, Sanitizers, Coverage modules.

function(pp_scope MODULE TARGET TEXT)
  message(STATUS "${PP_C_CMD}${MODULE}${PP_RST} [${PP_C_TARGET}${TARGET}${PP_RST}]: ${TEXT}")
endfunction()

# ── 13. Indented detail block ────────────────────────────────────────
#
#   pp_detail("Linking with: libfoo.so, libbar.so")
#
# For secondary information under a primary message.

function(pp_detail TEXT)
  message(STATUS "  ${PP_C_DEBUG}${PP_DOT} ${TEXT}${PP_RST}")
endfunction()

# ── 14. Horizontal rule ─────────────────────────────────────────────
#
#   pp_hr([<width>])

function(pp_hr)
  if(ARGC GREATER 0)
    set(_w ${ARGV0})
  else()
    set(_w 66)
  endif()
  string(REPEAT "─" ${_w} _line)
  message(STATUS "${PP_C_BOX}${_line}${PP_RST}")
endfunction()

# ── Internal helpers ─────────────────────────────────────────────────

# Pad a string to exactly WIDTH characters (right-padded with spaces).
macro(_pp_pad OUT_VAR IN_STR WIDTH)
  set(_pp_pv "${IN_STR}")
  string(LENGTH "${_pp_pv}" _pp_pv_len)
  if(_pp_pv_len LESS ${WIDTH})
    math(EXPR _pp_ppad "${WIDTH} - ${_pp_pv_len}")
    string(REPEAT " " ${_pp_ppad} _pp_psp)
    set(${OUT_VAR} "${_pp_pv}${_pp_psp}")
  else()
    string(SUBSTRING "${_pp_pv}" 0 ${WIDTH} ${OUT_VAR})
  endif()
endmacro()

# Choose a color code based on value semantics.
macro(_pp_value_color OUT_VAR RAW_VAL)
  if("${RAW_VAL}" STREQUAL "TRUE" OR "${RAW_VAL}" STREQUAL "ON" OR "${RAW_VAL}" STREQUAL "included" OR "${RAW_VAL}" STREQUAL "enabled")
    set(${OUT_VAR} "${PP_C_ON}")
  elseif("${RAW_VAL}" STREQUAL "FALSE" OR "${RAW_VAL}" STREQUAL "OFF" OR "${RAW_VAL}" STREQUAL "disabled")
    set(${OUT_VAR} "${PP_C_OFF}")
  else()
    set(${OUT_VAR} "${PP_C_VAL}")
  endif()
endmacro()

# Colorize a value string (returns the colored string, not just the code).
macro(_pp_colorize_value OUT_VAR RAW_VAL)
  _pp_value_color(_pp_cv_code "${RAW_VAL}")
  set(${OUT_VAR} "${_pp_cv_code}${RAW_VAL}${PP_RST}")
endmacro()
