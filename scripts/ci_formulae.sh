#!/usr/bin/env bash
# shellcheck disable=SC2317  # functions called via dispatch
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FORMULA_DIR="${FORMULA_DIR:-$REPO_ROOT/Formula}"

# ---- Helpers ----

discover_formulae() {
  local names=""
  local count=0
  local f name
  for f in "$FORMULA_DIR"/*.rb; do
    [ -f "$f" ] || continue
    count=$((count + 1))
    name="$(basename "$f" .rb)"
    case "$name" in
      ''|*[!a-z0-9_-]*)
        echo "ERROR: invalid formula name: $name" >&2
        return 1
        ;;
    esac
    names="${names:+$names }$name"
  done
  if [ "$count" -eq 0 ]; then
    echo "ERROR: no formula files found in $FORMULA_DIR" >&2
    return 1
  fi
  echo "$names"
}

# ---- Commands ----

prepare_runner() {
  if brew tap 2>/dev/null | grep -Fxq 'aws/tap'; then
    brew untap --force aws/tap >/dev/null 2>&1
  fi
}

audit() {
  local names formula
  names="$(discover_formulae)" || exit 1
  for formula in $names; do
    brew audit --strict --online --formula "adyranov/tap/$formula"
  done
}

livecheck() {
  local names formula
  names="$(discover_formulae)" || exit 1
  for formula in $names; do
    brew livecheck --formula "adyranov/tap/$formula"
  done
}

install_test() {
  local names formula
  names="$(discover_formulae)" || exit 1
  for formula in $names; do
    brew install --formula "adyranov/tap/$formula"
    brew test "adyranov/tap/$formula"
  done
}

verify_bins() {
  local names formula formula_out line found
  names="$(discover_formulae)" || exit 1
  for formula in $names; do
    found=0
    formula_out="$(brew ls --formula "adyranov/tap/$formula")"
    while IFS= read -r line; do
      case "$line" in
        */bin/*)
          found=1
          if ! test -x "$line"; then
            echo "ERROR: $formula: $line missing or not executable" >&2
            exit 1
          fi
          ;;
      esac
    done <<< "$formula_out"
    if [ "$found" -eq 0 ]; then
      echo "ERROR: $formula: no bin files packaged" >&2
      exit 1
    fi
  done
}

linkage() {
  local names formula
  names="$(discover_formulae)" || exit 1
  for formula in $names; do
    brew linkage --test --strict "adyranov/tap/$formula"
  done
}

verify_arch() {
  local expected_arch="${1:-}"
  case "$expected_arch" in
    arm64|x86_64) ;;
    *)
      echo "ERROR: invalid architecture: '$expected_arch' (use arm64 or x86_64)" >&2
      exit 1
      ;;
  esac
  local names formula formula_out line ftype
  names="$(discover_formulae)" || exit 1
  for formula in $names; do
    formula_out="$(brew ls --formula "adyranov/tap/$formula")"
    while IFS= read -r line; do
      case "$line" in
        */bin/*)
          ftype="$(file -b "$line")"
          case "$ftype" in
            *Mach-O*"$expected_arch"*) ;;
            *)
              echo "ERROR: $formula: $line is not Mach-O $expected_arch (file: $ftype)" >&2
              exit 1
              ;;
          esac
          ;;
      esac
    done <<< "$formula_out"
  done
}

conflicts() {
  local log
  log="$(mktemp)" || exit 1
  trap 'rm -f "$log"' EXIT

  # llama.cpp vs tap llama-cpp
  if brew install --formula llama.cpp >"$log" 2>&1; then
    cat "$log"
    echo "ERROR: expected conflict: llama.cpp succeeded unexpectedly" >&2
    exit 1
  fi
  grep -Fq 'llama.cpp' "$log" || {
    cat "$log"
    echo "ERROR: missing expected diagnostic in llama.cpp failure: llama.cpp" >&2
    exit 1
  }
  grep -Fq 'llama-cpp' "$log" || {
    cat "$log"
    echo "ERROR: missing expected diagnostic in llama.cpp failure: llama-cpp" >&2
    exit 1
  }

  # whisper-cpp core vs tap
  if brew install --formula whisper-cpp >"$log" 2>&1; then
    cat "$log"
    echo "ERROR: expected conflict: whisper-cpp succeeded unexpectedly" >&2
    exit 1
  fi
  grep -Fq 'whisper-cpp' "$log" || {
    cat "$log"
    echo "ERROR: missing expected diagnostic in whisper-cpp failure: whisper-cpp" >&2
    exit 1
  }
  grep -Fq 'different taps' "$log" || {
    cat "$log"
    echo "ERROR: missing expected diagnostic in whisper-cpp failure: different taps" >&2
    exit 1
  }

  rm -f "$log"
  trap - EXIT
}

renames() {
  local prefix
  prefix="$(brew --prefix)"

  test -x "$prefix/bin/ace-quantize"
  test -x "$prefix/bin/ace-mp3-codec"
  test -x "$prefix/bin/ace-neural-codec"
  test -x "$prefix/bin/omnivoice-quantize"
  test -x "$prefix/bin/omnivoice-tts-server"
  if test -e "$prefix/bin/quantize"; then
    echo "ERROR: bare quantize binary should not exist after rename" >&2
    exit 1
  fi
  test -x "$prefix/bin/parakeet-cli"
}

# ---- Dispatch ----

case "${1:-}" in
  prepare-runner) prepare_runner ;;
  audit) audit ;;
  livecheck) livecheck ;;
  install-test) install_test ;;
  verify-bins) verify_bins ;;
  linkage) linkage ;;
  verify-arch) verify_arch "${2:-}" ;;
  conflicts) conflicts ;;
  renames) renames ;;
  *)
    echo "ERROR: unknown ci_formulae command: ${1:-}" >&2
    echo "Usage: $0 <command> [args]" >&2
    exit 1
    ;;
esac
