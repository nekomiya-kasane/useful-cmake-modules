# ═══════════════════════════════════════════════════════════════════════
# CatiaCompat.cmake — CATIA/3DEXPERIENCE compatibility defines
#
# This module only DEFINES functions. Nothing is applied on include().
# Pass "GLOBAL" to apply to all targets; pass a real target name to
# apply only to that target.
#
# Functions:
#
#   catia_enable_compat(<target>)
#     Add all CATIA/3DEXPERIENCE preprocessor definitions.
#
# Usage:
#   include(CatiaCompat)
#   catia_enable_compat(GLOBAL)
#   catia_enable_compat(my_catia_plugin)
# ═══════════════════════════════════════════════════════════════════════
include_guard(GLOBAL)

# ── Internal: dispatch global vs per-target ───────────────────────────
function(_catia_add_definitions target)
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

# ── Public API ────────────────────────────────────────────────────────
function(catia_enable_compat target)
  message(STATUS "CatiaCompat [${target}]: enabling CATIA compatibility defines")

  # Endianness (required by CATIA SDK)
  include(TestBigEndian)
  test_big_endian(_catia_big_endian)
  if(_catia_big_endian)
    _catia_add_definitions(${target} _ENDIAN_BIG)
  else()
    _catia_add_definitions(${target} _ENDIAN_LITTLE)
  endif()

  # CATIA platform identification
  _catia_add_definitions(${target}
    _MK_MODNAME_=999
    CNEXT_CLIENT
    CATIAV5R19
    _AFXDLL
    NATIVE_EXCEPTION
    CAT_ENABLE_NATIVE_EXCEPTION
    _CAT_ANSI_STREAMS
  )

  # CATIA platform geometry
  _catia_add_definitions(${target}
    _DS_PLATEFORME_64
    DS_PLATEFORME_64
    PLATEFORME_DS64
  )

  # CATIA Linux-specific
  if(UNIX AND NOT APPLE)
    _catia_add_definitions(${target} _LINUX_SOURCE)
  endif()

  # CATIA Windows-specific
  if(WIN32)
    _catia_add_definitions(${target}
      _WINDOWS_QT_SOURCE
      _WINNT_SOURCE
      _WIN64_SOURCE
      _X86_SOURCE
      _MFC_VER=0x0800
      OS_Windows_NT
      _AMD64_=1
    )
  endif()
endfunction()
