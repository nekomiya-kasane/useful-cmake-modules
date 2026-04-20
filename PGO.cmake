# ═══════════════════════════════════════════════════════════════════════
# PGO.cmake — Profile-Guided Optimization support
#
# Usage:
#   cmake -B build -DGIN_PGO_PHASE=generate -DCMAKE_BUILD_TYPE=Release
#   cmake --build build --config Release
#   <run training workload>
#   cmake -B build -DGIN_PGO_PHASE=use -DCMAKE_BUILD_TYPE=Release
#   cmake --build build --config Release
#
# Phases:
#   OFF      — Normal build (default)
#   generate — Instrumented build: produces .pgc/.profraw profile data
#   use      — Optimized build: reads profile data, enables LTO+PGO
#
# MSVC:   /GL + /GENPROFILE (generate), /GL + /USEPROFILE (use)
# GCC:    -fprofile-generate (generate), -fprofile-use + -flto (use)
# Clang:  -fprofile-instr-generate (generate), -fprofile-instr-use + -flto=thin (use)
#
# Functions:
#   pgo_apply(<target>)        — Apply PGO flags to a specific target
#   pgo_apply_global()         — Apply PGO flags globally
#   pgo_get_profile_dir()      — Returns the profile data directory
# ═══════════════════════════════════════════════════════════════════════
include_guard(GLOBAL)

set(GIN_PGO_PHASE "OFF" CACHE STRING "PGO phase: OFF, generate, or use")
set_property(CACHE GIN_PGO_PHASE PROPERTY STRINGS OFF generate use)

# Profile data directory — colocated with the build
set(PGO_PROFILE_DIR "${CMAKE_BINARY_DIR}/pgo_profiles" CACHE PATH "Directory for PGO profile data")

# ── Internal helpers ──────────────────────────────────────────────────

function(_pgo_add_compile target)
  set(_flags "")
  foreach(_f ${ARGN})
    list(APPEND _flags $<$<COMPILE_LANGUAGE:C,CXX>:${_f}>)
  endforeach()
  if(target STREQUAL "GLOBAL")
    add_compile_options(${_flags})
  else()
    target_compile_options(${target} PRIVATE ${_flags})
  endif()
endfunction()

function(_pgo_add_link target)
  set(_flags "")
  foreach(_f ${ARGN})
    list(APPEND _flags $<$<LINK_LANGUAGE:C,CXX>:${_f}>)
  endforeach()
  if(target STREQUAL "GLOBAL")
    add_link_options(${_flags})
  else()
    target_link_options(${target} PRIVATE ${_flags})
  endif()
endfunction()

# ── Phase: generate (instrumented build) ──────────────────────────────

function(_pgo_apply_generate target)
  file(MAKE_DIRECTORY "${PGO_PROFILE_DIR}")

  if(MSVC)
    _pgo_add_compile(${target} /GL)
    _pgo_add_link(${target} /LTCG /GENPROFILE /INCREMENTAL:NO)
    message(STATUS "PGO [${target}]: MSVC instrumented build (GENPROFILE)")
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    _pgo_add_compile(${target} -fprofile-instr-generate=${PGO_PROFILE_DIR}/default_%m.profraw)
    _pgo_add_link(${target} -fprofile-instr-generate=${PGO_PROFILE_DIR}/default_%m.profraw)
    message(STATUS "PGO [${target}]: Clang instrumented build (profile-instr-generate)")
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    _pgo_add_compile(${target} -fprofile-generate=${PGO_PROFILE_DIR})
    _pgo_add_link(${target} -fprofile-generate=${PGO_PROFILE_DIR})
    message(STATUS "PGO [${target}]: GCC instrumented build (profile-generate)")
  else()
    message(WARNING "PGO: Unsupported compiler for PGO")
  endif()
endfunction()

# ── Phase: use (optimized build with profile data) ────────────────────

function(_pgo_apply_use target)
  if(MSVC)
    _pgo_add_compile(${target} /GL)
    _pgo_add_link(${target} /LTCG /USEPROFILE /INCREMENTAL:NO)
    message(STATUS "PGO [${target}]: MSVC optimized build (USEPROFILE + LTCG)")
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # Merge .profraw -> .profdata first (user must run llvm-profdata merge)
    set(_profdata "${PGO_PROFILE_DIR}/merged.profdata")
    _pgo_add_compile(${target} -fprofile-instr-use=${_profdata} -flto=thin)
    _pgo_add_link(${target} -fprofile-instr-use=${_profdata} -flto=thin)
    message(STATUS "PGO [${target}]: Clang optimized build (profile-use + ThinLTO)")
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    _pgo_add_compile(${target} -fprofile-use=${PGO_PROFILE_DIR} -flto -fprofile-correction)
    _pgo_add_link(${target} -fprofile-use=${PGO_PROFILE_DIR} -flto -fprofile-correction)
    message(STATUS "PGO [${target}]: GCC optimized build (profile-use + LTO)")
  else()
    message(WARNING "PGO: Unsupported compiler for PGO")
  endif()
endfunction()

# ── Public API ────────────────────────────────────────────────────────

## Apply PGO compile flags globally (/GL for MSVC).
## Call this BEFORE defining OBJECT library targets so all .obj files get /GL.
function(pgo_apply_compile_global)
  if(NOT GIN_PGO_PHASE STREQUAL "OFF")
    if(MSVC)
      add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/GL>)
      message(STATUS "PGO [GLOBAL compile]: /GL enabled for all translation units")
    endif()
  endif()
endfunction()

## Apply PGO linker flags to a specific SHARED/EXECUTABLE target.
## Call this AFTER add_library(target SHARED) so the linker picks up /GENPROFILE or /USEPROFILE.
function(pgo_apply target)
  if(GIN_PGO_PHASE STREQUAL "generate")
    if(MSVC)
      target_link_options(${target} PRIVATE /LTCG /GENPROFILE /INCREMENTAL:NO)
      message(STATUS "PGO [${target}]: MSVC linker GENPROFILE")
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
      _pgo_apply_generate(${target})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
      _pgo_apply_generate(${target})
    endif()
  elseif(GIN_PGO_PHASE STREQUAL "use")
    if(MSVC)
      target_link_options(${target} PRIVATE /LTCG /USEPROFILE /INCREMENTAL:NO)
      message(STATUS "PGO [${target}]: MSVC linker USEPROFILE + LTCG")
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
      _pgo_apply_use(${target})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
      _pgo_apply_use(${target})
    endif()
  endif()
endfunction()

function(pgo_apply_global)
  pgo_apply_compile_global()
endfunction()

function(pgo_get_profile_dir out_var)
  set(${out_var} "${PGO_PROFILE_DIR}" PARENT_SCOPE)
endfunction()
