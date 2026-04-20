# ═══════════════════════════════════════════════════════════════════════
# Sanitizers.cmake — Runtime sanitizer instrumentation
#
# This module only DEFINES functions. Nothing is applied on include().
# Every function takes a <target> as its first argument.
# Pass "GLOBAL" to apply to all targets; pass a real target name to
# apply only to that target.
#
# Functions:
#
#   sanitizer_enable(<target> <sanitizer1> [<sanitizer2> ...])
#     Enable one or more sanitizers: asan, ubsan, tsan, msan.
#
#   sanitizer_enable_msvc_debug_helpers(<target>)
#     Enable MSVC Debug helpers (_MSVC_STL_DESTRUCTOR_TOMBSTONES + /ZI).
#     Only useful when NO sanitizer is active (ZI is incompatible with ASan).
#
# Notes:
#   - ASan + TSan are mutually exclusive (both intercept memory ops).
#   - MSan is Clang-only and requires the entire dependency chain to
#     be built with MSan (including libc++).
#   - MSVC only supports ASan (/fsanitize=address).
#   - Edit-and-Continue (/ZI) is incompatible with ASan on MSVC;
#     when ASan is enabled, /Zi is used instead.
#
# Usage:
#   include(Sanitizers)
#   sanitizer_enable(GLOBAL asan ubsan)
#   sanitizer_enable(my_test asan)
#   sanitizer_enable_msvc_debug_helpers(GLOBAL)
# ═══════════════════════════════════════════════════════════════════════
include_guard(GLOBAL)

# ── Internal: dispatch global vs per-target ───────────────────────────
function(_san_add_compile target)
  set(_guarded "")
  foreach(_f ${ARGN})
    list(APPEND _guarded $<$<COMPILE_LANGUAGE:C,CXX>:${_f}>)
  endforeach()
  if(target STREQUAL "GLOBAL")
    add_compile_options(${_guarded})
  else()
    target_compile_options(${target} PRIVATE ${_guarded})
  endif()
endfunction()

function(_san_add_link target)
  set(_guarded "")
  foreach(_f ${ARGN})
    list(APPEND _guarded $<$<LINK_LANGUAGE:C,CXX>:${_f}>)
  endforeach()
  if(target STREQUAL "GLOBAL")
    add_link_options(${_guarded})
  else()
    target_link_options(${target} PRIVATE ${_guarded})
  endif()
endfunction()

function(_san_add_definitions target)
  set(_guarded "")
  foreach(_f ${ARGN})
    list(APPEND _guarded $<$<COMPILE_LANGUAGE:C,CXX>:${_f}>)
  endforeach()
  if(target STREQUAL "GLOBAL")
    add_compile_definitions(${_guarded})
  else()
    target_compile_definitions(${target} PRIVATE ${_guarded})
  endif()
endfunction()

# ── Internal: map sanitizer name → flags ──────────────────────────────
function(_san_get_flags sanitizer out_compile out_link out_defs)
  set(_cflags "")
  set(_lflags "")
  set(_defs   "")

  if(sanitizer STREQUAL "asan")
    if(MSVC)
      set(_cflags /fsanitize=address)
      set(_defs   _DISABLE_STRING_ANNOTATION=1 _DISABLE_VECTOR_ANNOTATION=1)
    else()
      set(_cflags -fsanitize=address -fno-omit-frame-pointer)
      set(_lflags -fsanitize=address)
    endif()

  elseif(sanitizer STREQUAL "ubsan")
    if(MSVC)
      message(WARNING "Sanitizers: UBSan is not supported on MSVC, skipping")
    else()
      set(_cflags -fsanitize=undefined)
      set(_lflags -fsanitize=undefined)
    endif()

  elseif(sanitizer STREQUAL "tsan")
    if(MSVC)
      message(WARNING "Sanitizers: TSan is not supported on MSVC, skipping")
    else()
      set(_cflags -fsanitize=thread)
      set(_lflags -fsanitize=thread)
    endif()

  elseif(sanitizer STREQUAL "msan")
    if(NOT CLANG)
      message(WARNING "Sanitizers: MSan is only supported on Clang, skipping")
    else()
      set(_cflags -fsanitize=memory -fno-omit-frame-pointer -fsanitize-memory-track-origins=2)
      set(_lflags -fsanitize=memory)
    endif()

  else()
    message(WARNING "Sanitizers: unknown sanitizer '${sanitizer}', skipping")
  endif()

  set(${out_compile} "${_cflags}" PARENT_SCOPE)
  set(${out_link}    "${_lflags}" PARENT_SCOPE)
  set(${out_defs}    "${_defs}"   PARENT_SCOPE)
endfunction()

# ── Internal: validate sanitizer combinations ─────────────────────────
function(_san_validate sanitizers)
  list(FIND sanitizers "asan" _has_asan)
  list(FIND sanitizers "tsan" _has_tsan)
  if(NOT _has_asan EQUAL -1 AND NOT _has_tsan EQUAL -1)
    message(FATAL_ERROR
      "Sanitizers: ASan and TSan are mutually exclusive.")
  endif()

  list(FIND sanitizers "msan" _has_msan)
  if(NOT _has_msan EQUAL -1 AND NOT _has_asan EQUAL -1)
    message(FATAL_ERROR
      "Sanitizers: ASan and MSan are mutually exclusive.")
  endif()
endfunction()

# ── Enable sanitizers ─────────────────────────────────────────────────
function(sanitizer_enable target)
  set(_sanitizers ${ARGN})
  if(NOT _sanitizers)
    message(FATAL_ERROR "sanitizer_enable: at least one sanitizer name required")
  endif()

  _san_validate("${_sanitizers}")

  # Check if asan is in the list (for MSVC /ZI → /Zi fallback)
  list(FIND _sanitizers "asan" _has_asan)

  foreach(_san ${_sanitizers})
    _san_get_flags(${_san} _cflags _lflags _defs)
    if(_cflags)
      _san_add_compile(${target} ${_cflags})
    endif()
    if(_lflags)
      _san_add_link(${target} ${_lflags})
    endif()
    if(_defs)
      _san_add_definitions(${target} ${_defs})
    endif()
  endforeach()

  # MSVC: ASan is incompatible with /ZI, use /Zi instead
  if(MSVC AND NOT _has_asan EQUAL -1)
    _san_add_compile(${target} $<$<CONFIG:Debug>:/Zi>)
  endif()

  message(STATUS "Sanitizers [${target}]: enabled [${_sanitizers}]")
endfunction()

# ── MSVC debug helpers (use when NO sanitizer is active) ──────────────
function(sanitizer_enable_msvc_debug_helpers target)
  if(NOT MSVC)
    return()
  endif()
  _san_add_definitions(${target} $<$<CONFIG:Debug>:_MSVC_STL_DESTRUCTOR_TOMBSTONES>)
  _san_add_compile(${target} $<$<CONFIG:Debug>:/ZI>)
endfunction()
