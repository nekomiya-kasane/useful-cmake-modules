# ═══════════════════════════════════════════════════════════════════════
# CommonOptions.cmake — Global compiler/linker/platform configuration
#
# Sections:
#   1. Cache options
#   2. Platform detection
#   3. Platform defines
#   4. Compiler warnings
#   5. Build-type flags (multi-config safe)
#   6. Binary layout & linker (delegated to BinaryLayout.cmake)
#   7. Coverage & sanitizers (delegated to Coverage.cmake, Sanitizers.cmake)
#
# Related modules:
#   BinaryLayout.cmake — Stack/heap size, ASLR, DEP, CFG, LTO, hardening
#   Coverage.cmake    — Code coverage instrumentation & report generation
#   Sanitizers.cmake  — ASan / UBSan / TSan / MSan configuration
#   CatiaCompat.cmake — CATIA/3DEXPERIENCE platform defines (opt-in)
# ═══════════════════════════════════════════════════════════════════════
include_guard(GLOBAL)

# ── 1. Cache options ──────────────────────────────────────────────────
set(BUILD_CHECK_LEVEL 2 CACHE STRING "Warning strictness level (1-4)")
if(NOT BUILD_CHECK_LEVEL)
  set(BUILD_CHECK_LEVEL 2)
endif()

option(SHOW_INCLUDE_TREE "Show include tree during compilation"   OFF)

message(STATUS "BUILD_CHECK_LEVEL = ${BUILD_CHECK_LEVEL}")

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ── 3. Platform defines ──────────────────────────────────────────────
if(WIN32)
  add_compile_definitions(
    PLATFORM_WINDOWS
    _WIN64 WIN64
    _NOMINMAX NOMINMAX WIN32_LEAN_AND_MEAN
    _UNICODE UNICODE
    _CRT_SECURE_NO_WARNINGS _CRT_DECLARE_NONSTDC_NAMES
    _USE_DETAILED_FUNCTION_NAME_IN_SOURCE_LOCATION
  )
else()
  add_compile_definitions(PLATFORM_LINUX)
endif()

# ── 4. Compiler warnings ─────────────────────────────────────────────
if(MSVC)
  # Conformance & encoding
  add_compile_options(
    "$<$<COMPILE_LANGUAGE:C,CXX>:/Zc:__cplusplus>"
    "$<$<COMPILE_LANGUAGE:C,CXX>:/utf-8>"
    "$<$<COMPILE_LANGUAGE:C,CXX>:/validate-charset>"
    "$<$<COMPILE_LANGUAGE:C,CXX>:/permissive->"
  )
  # Warning level derived from BUILD_CHECK_LEVEL
  math(EXPR _wlevel "${BUILD_CHECK_LEVEL} - 1")
  add_compile_options(
    "$<$<COMPILE_LANGUAGE:C,CXX>:/W${_wlevel}>"
    "$<$<COMPILE_LANGUAGE:C,CXX>:/WX>"
  )
  # Promote specific warnings to errors
  add_compile_options(
    "$<$<COMPILE_LANGUAGE:C,CXX>:/we4005>"   # macro redefinition
    "$<$<COMPILE_LANGUAGE:C,CXX>:/we4006>"   # #undef expected identifier
    "$<$<COMPILE_LANGUAGE:C,CXX>:/we4010>"   # single-line comment contains line-continuation
    "$<$<COMPILE_LANGUAGE:C,CXX>:/we4013>"   # undefined; assuming extern returning int
    "$<$<COMPILE_LANGUAGE:C,CXX>:/we4015>"   # type of bit field must be integral
    "$<$<COMPILE_LANGUAGE:C,CXX>:/we4020>"   # too many actual parameters
    "$<$<COMPILE_LANGUAGE:C,CXX>:/we4828>"   # illegal character in source file
  )
  # Suppress noisy warnings
  add_compile_options(
    "$<$<COMPILE_LANGUAGE:C,CXX>:/wd4297>"   # function assumed not to throw
  )
  # Include tree
  if(SHOW_INCLUDE_TREE)
    add_compile_options(/showIncludes)
  endif()

elseif(CLANG)
  # Diagnostics
  add_compile_options(
    -fcolor-diagnostics
    -fcaret-diagnostics
    -fdiagnostics-show-category=name
    -fdiagnostics-show-template-tree
  )
  # Level 4: treat all warnings as errors
  if(BUILD_CHECK_LEVEL EQUAL 4)
    add_compile_options(-Werror=all)
  endif()
  # Level 2-3: core error promotions + suppressed noise
  if(BUILD_CHECK_LEVEL GREATER_EQUAL 2)
    add_compile_options(
      -Werror=extra-tokens
      -Werror=braced-scalar-init
      -Werror=defaulted-function-deleted
      -Werror=strict-overflow
      -Werror=return-type
      -Werror=nonportable-include-path
      -Werror=address-of-temporary
    )
    add_compile_options(
      -Wno-unused
      -Wno-error=extra-semi
      -Wno-error=unknown-pragmas
      -Wno-error=gnu-include-next
      -Wno-unused-variable
      -Wno-error=deprecated-declarations
      -Wno-unused-function
      -Wno-unused-parameter
      -Wno-error=sign-compare
      -Wno-missing-designated-field-initializers
    )
  endif()
  # Level 3: exhaustive error promotions
  if(BUILD_CHECK_LEVEL EQUAL 3)
    add_compile_options(
      # Value / type safety
      -Werror=absolute-value
      -Werror=argument-outside-range
      -Werror=argument-undefined-behaviour
      -Werror=bool-conversions
      -Werror=bool-operation
      -Werror=cast-calling-convention
      -Werror=cast-function-type
      -Werror=cast-qual-unrelated
      -Werror=cast-qual
      -Werror=char-subscripts
      -Werror=compare-distinct-pointer-types
      -Werror=conditional-type-mismatch
      -Werror=conditional-uninitialized
      -Werror=div-by-zero
      -Werror=enum-compare
      -Werror=enum-compare-conditional
      -Werror=enum-enum-conversion
      -Werror=enum-float-conversion
      -Werror=enum-too-large
      -Werror=signed-enum-bitfield
      -Werror=bitfield-enum-conversion
      -Werror=bitfield-constant-conversion
      -Werror=bitfield-width
      -Werror=bitwise-instead-of-logical
      -Werror=bitwise-op-parentheses
      # Array / buffer
      -Werror=array-bounds
      -Werror=array-bounds-pointer-arithmetic
      -Werror=array-compare
      -Werror=array-parameter
      -Werror=sizeof-array-argument
      -Werror=sizeof-array-decay
      -Werror=sizeof-array-div
      -Werror=strncat-size
      # Class / OOP
      -Werror=abstract-final-class
      -Werror=call-to-pure-virtual-from-ctor-dtor
      -Werror=delete-non-virtual-dtor
      -Werror=overriding-method-mismatch
      -Werror=super-class-method-mismatch
      -Werror=reinterpret-base-class
      # Lifetime / move
      -Werror=dangling
      -Werror=return-local-addr
      -Werror=self-assign
      -Werror=self-move
      -Werror=redundant-move
      -Werror=sometimes-uninitialized
      -Werror=uninitialized
      -Werror=static-self-init
      # Shift
      -Werror=shift-bool
      -Werror=shift-count-negative
      -Werror=shift-negative-value
      -Werror=shift-op-parentheses
      # Macro / preprocessor
      -Werror=builtin-macro-redefined
      -Werror=builtin-memcpy-chk-size
      -Werror=builtin-requires-header
      -Werror=expansion-to-defined
      -Werror=keyword-macro
      -Werror=macro-redefined
      -Werror=embedded-directive
      -Werror=invalid-pp-token
      # Declaration / definition
      -Werror=ambiguous-delete
      -Werror=ambiguous-macro
      -Werror=ambiguous-ellipsis
      -Werror=ambiguous-member-template
      -Werror=ambiguous-reversed-operator
      -Werror=assign-enum
      -Werror=bad-function-cast
      -Werror=bind-to-temporary-copy
      -Werror=declaration-after-statement
      -Werror=defaulted-function-deleted
      -Werror=delayed-template-parsing-in-cxx20
      -Werror=delegating-ctor-cycles
      -Werror=dll-attribute-on-redeclaration
      -Werror=dtor-typedef
      -Werror=duplicate-decl-specifier
      -Werror=duplicate-enum
      -Werror=duplicate-method-arg
      -Werror=duplicate-method-match
      -Werror=duplicate-protocol
      -Werror=dynamic-exception-spec
      -Werror=empty-decomposition
      -Werror=exceptions
      -Werror=excess-initializers
      -Werror=extern-initializer
      -Werror=friend-enum
      -Werror=unsupported-friend
      -Werror=register
      -Werror=static-local-in-inline
      # Control flow / logic
      -Werror=align-mismatch
      -Werror=backslash-newline-escape
      -Werror=comma
      -Werror=compound-token-split-by-macro
      -Werror=compound-token-split-by-space
      -Werror=cxx-attribute-extension
      -Werror=extra
      -Werror=idiomatic-parentheses
      -Werror=ignored-optimization-argument
      -Werror=ignored-pragmas
      -Werror=implicit
      -Werror=invalid-utf8
      -Werror=invalid-static-assert-message
      -Werror=invalid-noreturn
      -Werror=invalid-constexpr
      -Werror=main
      -Werror=microsoft
      -Werror=missing-include-dirs
      -Werror=missing-method-return-type
      -Werror=parentheses
      -Werror=overloaded-shift-op-parentheses
      -Werror=pragmas
      -Werror=return-type
      -Werror=unknown-directives
      -Werror=zero-length-array
      -Werror=zero-as-null-pointer-constant
      # Compatibility
      -Werror=c++23-compat
      # Reachability (warning, not error)
      -Wunreachable-code-aggressive
    )
  endif()

else() # GCC
  add_compile_options(-fdiagnostics-color=always)
  if(BUILD_CHECK_LEVEL EQUAL 4)
    add_compile_options(-Werror=all)
  elseif(BUILD_CHECK_LEVEL GREATER_EQUAL 2)
    add_compile_options(-Werror=infinite-recursion)
  endif()
endif()

# ── 5. Build-type flags (multi-config safe) ───────────────────────────
add_compile_definitions(
  $<$<CONFIG:Debug>:_DEBUG>
  $<$<CONFIG:Debug>:DEBUG>
  $<$<NOT:$<CONFIG:Debug>>:_NDEBUG>
  $<$<NOT:$<CONFIG:Debug>>:NDEBUG>
)

if(MSVC)
  add_compile_options(
    $<$<CONFIG:Debug>:/JMC>
    $<$<CONFIG:Debug>:/Od>
  )
elseif(CLANG)
  add_compile_options(
    $<$<CONFIG:Debug>:-g3>
    $<$<CONFIG:Debug>:-O0>
    $<$<CONFIG:Debug>:-fdebug-macro>
    $<$<CONFIG:Debug>:-fstandalone-debug>
    $<$<CONFIG:Debug>:-fno-omit-frame-pointer>
  )
else() # GCC
  add_compile_options(
    $<$<CONFIG:Debug>:-g3>
    $<$<CONFIG:Debug>:-O0>
    $<$<CONFIG:Debug>:-fno-omit-frame-pointer>
  )
endif()

# ── 6. Binary layout, linker & security (delegated) ──────────────────
include(BinaryLayout)
binary_enable_default_binary_layout(GLOBAL)

# ── 7. Coverage & sanitizers (delegated) ─────────────────────────────
include(Coverage)
include(Sanitizers)
sanitizer_enable_msvc_debug_helpers(GLOBAL)