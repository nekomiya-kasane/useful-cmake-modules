# ═══════════════════════════════════════════════════════════════════════
# BinaryLayout.cmake — Binary output properties & linker tuning
#
# This module only DEFINES functions. Nothing is applied on include().
# Every function takes a <target> as its first argument.
# Pass "GLOBAL" to apply to all targets; pass a real target name to
# apply only to that target via target_*() commands.
#
# Functions:
#
#   binary_enable_stack_size(<target> <bytes>)
#   binary_enable_heap_size(<target> <bytes>)          — Windows only
#   binary_enable_aslr(<target>)
#   binary_enable_dep(<target>)
#   binary_enable_cfg(<target>)                        — MSVC only
#   binary_enable_ltcg(<target>)
#   binary_enable_incremental_link(<target>)           — MSVC only
#   binary_enable_hardening(<target>)
#   binary_enable_subsystem(<target> <CONSOLE|WINDOWS>) — Windows only
#
#   binary_enable_default_binary_layout(<target>)
#     Convenience: stack 16MB + ASLR + DEP + incremental link + hardening.
#
# Usage:
#   include(BinaryLayout)
#   binary_enable_default_binary_layout(GLOBAL)
#   binary_enable_stack_size(my_app 33554432)
#   binary_enable_cfg(my_app)
#   binary_enable_subsystem(my_app WINDOWS)
# ═══════════════════════════════════════════════════════════════════════
include_guard(GLOBAL)
include(CMakePrettyPrint)

# ── Internal: dispatch global vs per-target ───────────────────────────

# _bl_add_link(<target> <flags...>)
function(_bl_add_link target)
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

# _bl_add_compile(<target> <flags...>)
function(_bl_add_compile target)
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

# _bl_add_definitions(<target> <defs...>)
function(_bl_add_definitions target)
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

# ── Stack size ────────────────────────────────────────────────────────
function(binary_enable_stack_size target size)
  if(WIN32)
    if(MSVC)
      _bl_add_link(${target} /STACK:${size})
    else()
      _bl_add_link(${target} -Wl,/STACK:${size})
    endif()
  else()
    _bl_add_link(${target} -Wl,-z,stack-size=${size})
  endif()
  pp_scope("BinaryLayout" "${target}" "stack size = ${size}")
endfunction()

# ── Heap size (Windows only) ──────────────────────────────────────────
function(binary_enable_heap_size target size)
  if(NOT WIN32)
    message(WARNING "binary_enable_heap_size: heap reserve is a Windows-only concept, ignoring")
    return()
  endif()
  if(MSVC)
    _bl_add_link(${target} /HEAP:${size})
  else()
    _bl_add_link(${target} -Wl,/HEAP:${size})
  endif()
  pp_scope("BinaryLayout" "${target}" "heap size = ${size}")
endfunction()

# ── ASLR ──────────────────────────────────────────────────────────────
function(binary_enable_aslr target)
  if(MSVC)
    _bl_add_link(${target} /DYNAMICBASE /HIGHENTROPYVA)
  elseif(UNIX)
    if(target STREQUAL "GLOBAL")
      set(CMAKE_POSITION_INDEPENDENT_CODE ON PARENT_SCOPE)
    else()
      set_target_properties(${target} PROPERTIES POSITION_INDEPENDENT_CODE ON)
    endif()
  endif()
endfunction()

# ── DEP / NX ─────────────────────────────────────────────────────────
function(binary_enable_dep target)
  if(MSVC)
    _bl_add_link(${target} /NXCOMPAT)
  elseif(UNIX)
    _bl_add_link(${target} -Wl,-z,noexecstack)
  endif()
endfunction()

# ── Control Flow Guard (MSVC only) ───────────────────────────────────
function(binary_enable_cfg target)
  if(MSVC)
    _bl_add_compile(${target} /guard:cf)
    _bl_add_link(${target} /guard:cf)
    pp_scope("BinaryLayout" "${target}" "Control Flow Guard enabled")
  else()
    message(WARNING "binary_enable_cfg: CFG is only supported on MSVC, ignoring")
  endif()
endfunction()

# ── Link-Time Code Generation / LTO ──────────────────────────────────
function(binary_enable_ltcg target)
  if(MSVC)
    _bl_add_compile(${target} /GL)
    _bl_add_link(${target} /LTCG)
    pp_scope("BinaryLayout" "${target}" "LTCG enabled")
  elseif(CLANG)
    _bl_add_compile(${target} -flto=thin)
    _bl_add_link(${target} -flto=thin)
    pp_scope("BinaryLayout" "${target}" "ThinLTO enabled")
  elseif(GCC)
    _bl_add_compile(${target} -flto)
    _bl_add_link(${target} -flto)
    pp_scope("BinaryLayout" "${target}" "LTO enabled")
  else()
    message(WARNING "binary_enable_ltcg: unsupported compiler, ignoring")
  endif()
endfunction()

# ── Incremental linking (MSVC) ────────────────────────────────────────
function(binary_enable_incremental_link target)
  if(MSVC)
    _bl_add_link(${target}
      $<$<CONFIG:Debug>:/INCREMENTAL>
      $<$<NOT:$<CONFIG:Debug>>:/INCREMENTAL:NO>
    )
  endif()
endfunction()

# ── Misc hardening ────────────────────────────────────────────────────
function(binary_enable_hardening target)
  if(UNIX AND NOT APPLE)
    _bl_add_link(${target} -Wl,-z,relro -Wl,-z,now)
  endif()
  if(MSVC)
    _bl_add_link(${target} /Brepro)
  endif()
endfunction()

# ── Subsystem (Windows only) ─────────────────────────────────────────
function(binary_enable_subsystem target subsystem)
  if(NOT WIN32)
    return()
  endif()
  string(TOUPPER "${subsystem}" _sub)
  if(NOT _sub STREQUAL "CONSOLE" AND NOT _sub STREQUAL "WINDOWS")
    message(FATAL_ERROR "binary_enable_subsystem: unknown subsystem '${subsystem}', "
      "expected CONSOLE or WINDOWS")
  endif()
  if(MSVC)
    _bl_add_link(${target} /SUBSYSTEM:${_sub})
  else()
    _bl_add_link(${target} -Wl,/SUBSYSTEM:${_sub})
  endif()
endfunction()

# ── Convenience: sensible defaults ────────────────────────────────────
macro(binary_enable_default_binary_layout target)
  binary_enable_stack_size(${target} 16777216)
  binary_enable_aslr(${target})
  binary_enable_dep(${target})
  binary_enable_incremental_link(${target})
  binary_enable_hardening(${target})
endmacro()
