# ═══════════════════════════════════════════════════════════════════════
# Coverage.cmake — Code coverage instrumentation and report generation
#
# This module only DEFINES functions. Nothing is applied on include().
# Every function takes a <target> as its first argument.
# Pass "GLOBAL" to apply to all targets; pass a real target name to
# apply only to that target.
#
# Functions:
#
#   coverage_enable(<target>)
#     Enable coverage instrumentation (Clang source-based or GCC gcov).
#     MSVC is not supported and will emit a warning.
#
#   coverage_add_report(
#     NAME <name>
#     TARGETS <target1> [<target2> ...]
#     [EXCLUDE <pattern1> [<pattern2> ...]]
#   )
#     Add a custom target that runs tests and generates an HTML report.
#     Supports llvm-cov (Clang) and gcovr (GCC).
#
# Usage:
#   include(Coverage)
#   coverage_enable(GLOBAL)
#   coverage_enable(my_test_lib)
#   coverage_add_report(NAME coverage TARGETS my_test EXCLUDE "thirdparty/*")
# ═══════════════════════════════════════════════════════════════════════
include_guard(GLOBAL)
include(CMakePrettyPrint)

# ── Internal: dispatch global vs per-target ───────────────────────────
function(_cov_add_compile target)
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

function(_cov_add_link target)
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

# ── Enable coverage instrumentation ──────────────────────────────────
function(coverage_enable target)
  if(MSVC)
    message(WARNING "coverage_enable [${target}]: MSVC has no native coverage support. "
      "Consider using OpenCppCoverage as an external tool.")
    return()
  endif()

  if(CLANG)
    _cov_add_compile(${target} -fprofile-instr-generate -fcoverage-mapping)
    _cov_add_link(${target} -fprofile-instr-generate -fcoverage-mapping)
    pp_scope("Coverage" "${target}" "enabled (Clang source-based)")
  elseif(GCC)
    _cov_add_compile(${target} --coverage -fprofile-arcs -ftest-coverage)
    _cov_add_link(${target} --coverage)
    pp_scope("Coverage" "${target}" "enabled (GCC gcov)")
  else()
    message(WARNING "coverage_enable [${target}]: unsupported compiler ${CMAKE_CXX_COMPILER_ID}")
  endif()
endfunction()

# ── Coverage report target ────────────────────────────────────────────
function(coverage_add_report)
  cmake_parse_arguments(COV "" "NAME" "TARGETS;EXCLUDE" ${ARGN})

  if(NOT COV_NAME)
    message(FATAL_ERROR "coverage_add_report: NAME is required")
  endif()
  if(NOT COV_TARGETS)
    message(FATAL_ERROR "coverage_add_report: TARGETS is required")
  endif()

  set(_report_dir "${CMAKE_BINARY_DIR}/coverage/${COV_NAME}")

  if(CLANG)
    # ── llvm-cov workflow ───────────────────────────────────────────
    find_program(LLVM_PROFDATA llvm-profdata)
    find_program(LLVM_COV llvm-cov)
    if(NOT LLVM_PROFDATA OR NOT LLVM_COV)
      message(WARNING "coverage_add_report: llvm-profdata/llvm-cov not found, "
        "report target '${COV_NAME}' will not be created")
      return()
    endif()

    set(_profraw "${CMAKE_BINARY_DIR}/${COV_NAME}.profraw")
    set(_profdata "${CMAKE_BINARY_DIR}/${COV_NAME}.profdata")

    # Build -object flags for each target
    set(_obj_flags "")
    foreach(_tgt ${COV_TARGETS})
      list(APPEND _obj_flags -object $<TARGET_FILE:${_tgt}>)
    endforeach()

    # Build -ignore-filename-regex flags
    set(_ignore_flags "")
    foreach(_pat ${COV_EXCLUDE})
      list(APPEND _ignore_flags -ignore-filename-regex=${_pat})
    endforeach()

    add_custom_target(${COV_NAME}
      COMMENT "Generating coverage report: ${COV_NAME}"
      # 1. Run tests with profiling
      COMMAND ${CMAKE_COMMAND} -E env
        LLVM_PROFILE_FILE=${_profraw}
        ${CMAKE_CTEST_COMMAND} --output-on-failure -C $<CONFIG>
      # 2. Merge raw profiles
      COMMAND ${LLVM_PROFDATA} merge -sparse ${_profraw} -o ${_profdata}
      # 3. Generate HTML report
      COMMAND ${CMAKE_COMMAND} -E make_directory ${_report_dir}
      COMMAND ${LLVM_COV} show
        ${_obj_flags}
        -instr-profile=${_profdata}
        -format=html
        -output-dir=${_report_dir}
        ${_ignore_flags}
      # 4. Print summary
      COMMAND ${LLVM_COV} report
        ${_obj_flags}
        -instr-profile=${_profdata}
        ${_ignore_flags}
      WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
      DEPENDS ${COV_TARGETS}
      VERBATIM
    )
    pp_scope("Coverage" "${COV_NAME}" "report target created (llvm-cov)")

  elseif(GCC)
    # ── gcovr workflow ──────────────────────────────────────────────
    find_program(GCOVR gcovr)
    if(NOT GCOVR)
      message(WARNING "coverage_add_report: gcovr not found, "
        "report target '${COV_NAME}' will not be created")
      return()
    endif()

    # Build --exclude flags
    set(_exclude_flags "")
    foreach(_pat ${COV_EXCLUDE})
      list(APPEND _exclude_flags --exclude ${_pat})
    endforeach()

    add_custom_target(${COV_NAME}
      COMMENT "Generating coverage report: ${COV_NAME}"
      # 1. Run tests
      COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure -C $<CONFIG>
      # 2. Generate HTML report
      COMMAND ${CMAKE_COMMAND} -E make_directory ${_report_dir}
      COMMAND ${GCOVR}
        --root ${CMAKE_SOURCE_DIR}
        --object-directory ${CMAKE_BINARY_DIR}
        --html --html-details
        --output ${_report_dir}/index.html
        ${_exclude_flags}
      # 3. Print summary
      COMMAND ${GCOVR}
        --root ${CMAKE_SOURCE_DIR}
        --object-directory ${CMAKE_BINARY_DIR}
        ${_exclude_flags}
      WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
      DEPENDS ${COV_TARGETS}
      VERBATIM
    )
    pp_scope("Coverage" "${COV_NAME}" "report target created (gcovr)")

  else()
    message(WARNING "coverage_add_report: unsupported compiler, "
      "report target '${COV_NAME}' will not be created")
  endif()
endfunction()
