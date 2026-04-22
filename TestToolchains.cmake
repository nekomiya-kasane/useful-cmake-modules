# ═══════════════════════════════════════════════════════════════════════
# TestToolchains.cmake — Compiler & platform detection
#
# This module only DEFINES variables. Nothing is applied on include()
# other than setting the detection results.
#
# Derived from CMAKE_CXX_COMPILER_ID, CMAKE_SYSTEM_NAME, and
# CMAKE_CXX_SIMULATE_ID. No trial compilations are performed.
#
# Variables set (all CACHE INTERNAL):
#
#   Compiler family (exactly one is TRUE):
#     COMPILER_MSVC          — Microsoft Visual C++ (cl.exe)
#     COMPILER_CLANG         — LLVM Clang (clang / clang-cl)
#     COMPILER_APPLE_CLANG   — Apple Clang (Xcode)
#     COMPILER_GCC           — GNU GCC
#     COMPILER_INTEL_LLVM    — Intel oneAPI DPC++/C++ (icx)
#
#   Convenience aliases (backward compat, non-exclusive):
#     CLANG                  — TRUE if Clang or AppleClang
#     GCC                    — TRUE if GNU GCC
#
#   Combined toolchain (at most one is TRUE):
#     CLANG_CL               — Clang targeting MSVC ABI (clang-cl)
#     CLANG_MINGW            — Clang targeting MinGW
#     CLANG_CYGWIN           — Clang targeting Cygwin
#     CLANG_GNU              — Clang targeting GNU/Linux (plain clang++)
#
#   Platform:
#     PLATFORM_WINDOWS       — WIN32
#     PLATFORM_LINUX         — Linux
#     PLATFORM_MACOS         — macOS / Darwin
#     PLATFORM_UNIX          — Any Unix-like (Linux, macOS, BSD, ...)
#
#   Compiler version:
#     COMPILER_VERSION       — Full version string (e.g. "17.0.3")
#     COMPILER_VERSION_MAJOR — Major version number
#     COMPILER_VERSION_MINOR — Minor version number
#
#   Architecture:
#     HOST_ARCH              — Target architecture (x86_64, aarch64, ...)
#     HOST_BITS              — Pointer width (64 or 32)
#
# Usage:
#   include(TestToolchains)
# ═══════════════════════════════════════════════════════════════════════
include_guard(GLOBAL)

# ── Compiler family ────────────────────────────────────────────────
set(COMPILER_MSVC        FALSE CACHE INTERNAL "")
set(COMPILER_CLANG       FALSE CACHE INTERNAL "")
set(COMPILER_APPLE_CLANG FALSE CACHE INTERNAL "")
set(COMPILER_GCC         FALSE CACHE INTERNAL "")
set(COMPILER_INTEL_LLVM  FALSE CACHE INTERNAL "")

if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  set(COMPILER_MSVC TRUE CACHE INTERNAL "")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  set(COMPILER_CLANG TRUE CACHE INTERNAL "")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
  set(COMPILER_APPLE_CLANG TRUE CACHE INTERNAL "")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  set(COMPILER_GCC TRUE CACHE INTERNAL "")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "IntelLLVM")
  set(COMPILER_INTEL_LLVM TRUE CACHE INTERNAL "")
else()
  message(WARNING "TestToolchains: unrecognized compiler '${CMAKE_CXX_COMPILER_ID}'")
endif()

# ── Convenience aliases ────────────────────────────────────────────
# CLANG is TRUE for both Clang and AppleClang (both are clang-family)
if(COMPILER_CLANG OR COMPILER_APPLE_CLANG OR COMPILER_INTEL_LLVM)
  set(CLANG TRUE CACHE INTERNAL "Clang-family compiler")
else()
  set(CLANG FALSE CACHE INTERNAL "Clang-family compiler")
endif()

if(COMPILER_GCC)
  set(GCC TRUE CACHE INTERNAL "GNU GCC compiler")
else()
  set(GCC FALSE CACHE INTERNAL "GNU GCC compiler")
endif()

# ── Combined toolchain (Clang + target ABI) ───────────────────────
set(CLANG_CL     FALSE CACHE INTERNAL "")
set(CLANG_MINGW  FALSE CACHE INTERNAL "")
set(CLANG_CYGWIN FALSE CACHE INTERNAL "")
set(CLANG_GNU    FALSE CACHE INTERNAL "")

if(COMPILER_CLANG)
  if(CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC" OR MSVC)
    set(CLANG_CL TRUE CACHE INTERNAL "Clang targeting MSVC ABI (clang-cl)")
  elseif(MINGW)
    set(CLANG_MINGW TRUE CACHE INTERNAL "Clang targeting MinGW")
  elseif(CYGWIN)
    set(CLANG_CYGWIN TRUE CACHE INTERNAL "Clang targeting Cygwin")
  else()
    set(CLANG_GNU TRUE CACHE INTERNAL "Clang targeting GNU/Linux")
  endif()
endif()

# ── Platform detection ─────────────────────────────────────────────
set(PLATFORM_WINDOWS FALSE CACHE INTERNAL "")
set(PLATFORM_LINUX   FALSE CACHE INTERNAL "")
set(PLATFORM_MACOS   FALSE CACHE INTERNAL "")
set(PLATFORM_UNIX    FALSE CACHE INTERNAL "")

if(WIN32)
  set(PLATFORM_WINDOWS TRUE CACHE INTERNAL "")
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(PLATFORM_LINUX TRUE CACHE INTERNAL "")
endif()
if(APPLE)
  set(PLATFORM_MACOS TRUE CACHE INTERNAL "")
endif()
if(UNIX)
  set(PLATFORM_UNIX TRUE CACHE INTERNAL "")
endif()

# ── Compiler version ──────────────────────────────────────────────
set(COMPILER_VERSION       "${CMAKE_CXX_COMPILER_VERSION}" CACHE INTERNAL "")
set(COMPILER_VERSION_MAJOR "${CMAKE_CXX_COMPILER_VERSION_MAJOR}" CACHE INTERNAL "")
set(COMPILER_VERSION_MINOR "${CMAKE_CXX_COMPILER_VERSION_MINOR}" CACHE INTERNAL "")

# ── Architecture ──────────────────────────────────────────────────
if(CMAKE_SYSTEM_PROCESSOR)
  string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _arch)
else()
  set(_arch "unknown")
endif()

# Normalize common arch names
if(_arch MATCHES "^(x86_64|amd64|x64)$")
  set(_arch "x86_64")
elseif(_arch MATCHES "^(aarch64|arm64)$")
  set(_arch "aarch64")
elseif(_arch MATCHES "^(i[3-6]86|x86)$")
  set(_arch "x86")
elseif(_arch MATCHES "^(armv[0-9])")
  set(_arch "arm")
endif()

set(HOST_ARCH "${_arch}" CACHE INTERNAL "Target architecture")

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
  set(HOST_BITS 64 CACHE INTERNAL "Host pointer width")
elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
  set(HOST_BITS 32 CACHE INTERNAL "Host pointer width")
else()
  set(HOST_BITS 0 CACHE INTERNAL "Host pointer width (unknown)")
endif()

# ── 7. Summary (printed by CommonOptions.cmake) ──────────────────────