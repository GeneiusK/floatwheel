#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

prepend_first_match() {
  local result_var="$1"
  shift
  local pattern
  local matches=()

  for pattern in "$@"; do
    shopt -s nullglob
    matches=( $pattern )
    shopt -u nullglob

    if ((${#matches[@]})); then
      PATH="${matches[0]}:$PATH"
      printf -v "$result_var" '%s' "${matches[0]}"
      return 0
    fi
  done

  printf -v "$result_var" ''
  return 1
}

if ! command -v cbuild >/dev/null 2>&1 || ! command -v cpackget >/dev/null 2>&1; then
  cmsis_toolbox_bin=""
  prepend_first_match cmsis_toolbox_bin \
    "$HOME/.vcpkg/artifacts/*/tools.open.cmsis.pack.cmsis.toolbox/2.13.0/bin" \
    "$HOME/.vcpkg/artifacts/*/tools.open.cmsis.pack.cmsis.toolbox/2.12.0/bin" || true

  if [[ -n "${cmsis_toolbox_bin:-}" ]]; then
    export CMSIS_COMPILER_ROOT="$(cd "$cmsis_toolbox_bin/../etc" && pwd)"
  fi
fi

if [[ -z "${AC6_TOOLCHAIN_6_23_0:-}" ]]; then
  ac6_bin=""
  prepend_first_match ac6_bin "$HOME/.vcpkg/artifacts/*/compilers.arm.armclang/6.23.0/bin" || true

  if [[ -n "${ac6_bin:-}" ]]; then
    export AC6_TOOLCHAIN_6_23_0="$ac6_bin"
  fi
fi

if ! command -v cmake >/dev/null 2>&1; then
  cmake_bin=""
  prepend_first_match cmake_bin "$HOME/.vcpkg/artifacts/*/tools.kitware.cmake/3.31.5/bin" || true
fi

if ! command -v ninja >/dev/null 2>&1; then
  ninja_bin=""
  prepend_first_match ninja_bin \
    "$HOME/.vcpkg/artifacts/*/tools.ninja.build.ninja/1.13.2" \
    "$HOME/.vcpkg/artifacts/*/tools.ninja.build.ninja/1.12.0" || true
fi

missing=()
for tool in cbuild cpackget armclang cmake ninja; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing+=("$tool")
  fi
done

if ((${#missing[@]})); then
  printf 'Missing required build tool(s): %s\n' "${missing[*]}" >&2
  printf 'Install or activate CMSIS-Toolbox, Arm Compiler 6.23, CMake, and Ninja, then retry.\n' >&2
  exit 127
fi

solution="Project/MDK5/LCM_Light_Control_IO_WS2812_New.csolution.yml"
project="LCM_Light_Control_IO_WS2812_New"
targets=(ADV2 ADV-P42A ADV-DG40 GTV PintV XRV)

for target in "${targets[@]}"; do
  context="$project.Release+$target"
  output_dir="Project/MDK5/out/$project/$target/Release"

  cbuild "$solution" --context "$context" --packs

  hex_files=("$output_dir"/*.hex)
  if [[ ! -e "${hex_files[0]}" ]]; then
    printf 'Build succeeded but no hex files were found in %s\n' "$output_dir" >&2
    exit 1
  fi

  cp "${hex_files[@]}" ./
done
