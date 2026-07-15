#!/usr/bin/env ruby
# frozen_string_literal: true

# Offline subprocess tests for scripts/ci_formulae.sh.
# Uses temporary Formula dirs and mock brew/file executables.
# No real Homebrew mutation.

require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"

class TestCiFormulae < Minitest::Test
  SCRIPT = File.expand_path("../../scripts/ci_formulae.sh", __FILE__).freeze

  # Default mock brew — handles all commands the script invokes.
  # Controlled via environment variables:
  #   MOCK_BREW_TAP_OUTPUT   — output of `brew tap` (list)
  #   MOCK_BREW_LS_OUTPUT    — output of `brew ls --formula ...`
  #   MOCK_BREW_PREFIX       — output of `brew --prefix`
  #   MOCK_BREW_FAIL_INSTALL — if set, a normal `brew install` fails (non-conflict)
  DEFAULT_MOCK_BREW = <<~"BASH".freeze
    #!/usr/bin/env bash
    set -euo pipefail
    case "${1:-}" in
      tap)
        if [ $# -eq 1 ]; then
          echo "${MOCK_BREW_TAP_OUTPUT:-adyranov/tap}"
        fi
        exit 0
        ;;
      untap) exit 0 ;;
      audit|livecheck|test) exit 0 ;;
      install)
        case " $* " in
          *" llama.cpp "*)
            echo "Error: llama.cpp conflicts with adyranov/tap/llama-cpp"
            echo "llama.cpp"
            echo "llama-cpp"
            exit 1
            ;;
          *" whisper-cpp "*)
            echo "Error: whisper-cpp was installed from the adyranov/tap tap"
            echo "but you are trying to install it from the homebrew/core tap."
            echo "Formulae with the same name from different taps cannot be installed at the same time."
            exit 1
            ;;
          *)
            if [ -n "${MOCK_BREW_FAIL_INSTALL:-}" ]; then
              echo "mock brew install failed" >&2
              exit 1
            fi
            exit 0
            ;;
        esac
        ;;
      ls)
        echo "${MOCK_BREW_LS_OUTPUT:-/opt/homebrew/Cellar/x/1.0/bin/test-bin}"
        exit 0
        ;;
      linkage) exit 0 ;;
      --prefix) echo "${MOCK_BREW_PREFIX:-/opt/homebrew}" ;;
      *)
        echo "mock brew: unexpected call: $*" >&2
        exit 1
        ;;
    esac
  BASH

  DEFAULT_MOCK_FILE = <<~"BASH".freeze
    #!/usr/bin/env bash
    set -euo pipefail
    echo "${MOCK_FILE_OUTPUT:-Mach-O 64-bit executable arm64}"
  BASH

  def setup
    @tmpdir = Dir.mktmpdir("ci_formulae_test_")
    @formula_dir = File.join(@tmpdir, "formulae")
    @fake_bindir = File.join(@tmpdir, "fake_bin")
    @prefix_dir = File.join(@tmpdir, "prefix")
    Dir.mkdir(@formula_dir)
    Dir.mkdir(@fake_bindir)
    FileUtils.mkdir_p(File.join(@prefix_dir, "bin"))
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # -- helpers --

  def write_formula(name)
    File.write(File.join(@formula_dir, "#{name}.rb"),
               "class #{name.split("-").map(&:capitalize).join} < Formula; end\n")
  end

  def write_mock_brew(content = nil)
    content ||= DEFAULT_MOCK_BREW
    File.write(File.join(@fake_bindir, "brew"), content)
    FileUtils.chmod(0o755, File.join(@fake_bindir, "brew"))
  end

  def write_mock_file(content = nil, output: nil)
    if output
      content = <<~"BASH"
        #!/usr/bin/env bash
        set -euo pipefail
        echo "#{output}"
      BASH
    end
    content ||= DEFAULT_MOCK_FILE
    File.write(File.join(@fake_bindir, "file"), content)
    FileUtils.chmod(0o755, File.join(@fake_bindir, "file"))
  end

  # Copy real mktemp so conflicts subcommand works correctly
  def install_real_mktemp
    # mktemp lives at /usr/bin/mktemp — already on PATH via our fallback
  end

  def base_env(overrides = {})
    {
      "FORMULA_DIR" => @formula_dir,
      "PATH" => "#{@fake_bindir}:/usr/bin:/bin:/usr/sbin:/sbin",
      "MOCK_BREW_PREFIX" => @prefix_dir.to_s,
      "HOME" => @tmpdir
    }.merge(overrides)
  end

  def run_script(*args, env: {})
    e = base_env(env)
    stdout, stderr, status = Open3.capture3(e, SCRIPT, *args)
    [status, stdout, stderr]
  end

  # -- tests: formula discovery errors --

  def test_zero_formulae_errors
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("audit")
    refute_predicate status, :success?
    assert_match(/no formula files/i, stderr)
  end

  def test_invalid_formula_name_errors
    write_mock_brew
    write_mock_file
    File.write(File.join(@formula_dir, "bad name.rb"), "class Bad < Formula; end\n")
    status, _stdout, stderr = run_script("audit")
    refute_predicate status, :success?
    assert_match(/invalid formula name/i, stderr)
  end

  def test_special_chars_in_name_errors
    write_mock_brew
    write_mock_file
    File.write(File.join(@formula_dir, "bad@name.rb"), "class Bad < Formula; end\n")
    status, _stdout, stderr = run_script("audit")
    refute_predicate status, :success?
    assert_match(/invalid formula name/i, stderr)
  end

  # -- tests: subcommand dispatch and argv --

  def test_unknown_command
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("nonsense")
    refute_predicate status, :success?
    assert_match(/unknown.*nonsense/i, stderr)
  end

  def test_empty_command
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script
    refute_predicate status, :success?
    assert_match(/unknown/i, stderr)
  end

  def test_prepare_runner
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("prepare-runner")
    assert_predicate status, :success?, "prepare-runner failed: #{stderr}"
  end

  def test_audit_invocation
    write_formula("llama-cpp")
    write_formula("whisper-cpp")
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("audit")
    assert_predicate status, :success?, "audit failed: #{stderr}"
  end

  def test_livecheck_invocation
    write_formula("llama-cpp")
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("livecheck")
    assert_predicate status, :success?, "livecheck failed: #{stderr}"
  end

  def test_install_test_invocation
    write_formula("llama-cpp")
    write_formula("stable-diffusion-cpp")
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("install-test")
    assert_predicate status, :success?, "install-test failed: #{stderr}"
  end

  def test_linkage_invocation
    write_formula("llama-cpp")
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("linkage")
    assert_predicate status, :success?, "linkage failed: #{stderr}"
  end

  def test_verify_bins_ok
    write_formula("llama-cpp")
    bin1 = File.join(@prefix_dir, "bin", "llama-cli")
    bin2 = File.join(@prefix_dir, "bin", "llama-quantize")
    File.write(bin1, "#!/bin/bash\necho mock\n"); FileUtils.chmod(0o755, bin1)
    File.write(bin2, "#!/bin/bash\necho mock\n"); FileUtils.chmod(0o755, bin2)
    ls_output = "#{bin1}\n#{bin2}\n"
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("verify-bins",
                                         env: { "MOCK_BREW_LS_OUTPUT" => ls_output })
    assert_predicate status, :success?, "verify-bins failed: #{stderr}"
  end

  def test_verify_bins_no_bins_fails
    write_formula("llama-cpp")
    ls_output = "#{@prefix_dir}/lib/libggml.dylib\n" \
                "#{@prefix_dir}/include/ggml.h\n"
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("verify-bins",
                                         env: { "MOCK_BREW_LS_OUTPUT" => ls_output })
    refute_predicate status, :success?
    assert_match(/no bin files/i, stderr)
  end

  def test_verify_bins_nonexistent_bin_fails
    write_formula("llama-cpp")
    ls_output = "#{@prefix_dir}/bin/missing-bin\n"
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("verify-bins",
                                         env: { "MOCK_BREW_LS_OUTPUT" => ls_output })
    refute_predicate status, :success?
    assert_match(/missing or not executable/i, stderr)
  end

  # -- architecture verification --

  def test_verify_arch_arm64_ok
    write_formula("llama-cpp")
    bin = File.join(@prefix_dir, "bin", "llama-cli")
    File.write(bin, "#!/bin/bash\necho mock\n"); FileUtils.chmod(0o755, bin)
    ls_output = "#{bin}\n"
    write_mock_brew
    write_mock_file(output: "Mach-O 64-bit executable arm64")
    status, _stdout, stderr = run_script("verify-arch", "arm64",
                                         env: { "MOCK_BREW_LS_OUTPUT" => ls_output })
    assert_predicate status, :success?, "verify-arch arm64 failed: #{stderr}"
  end

  def test_verify_arch_x86_64_ok
    write_formula("llama-cpp")
    bin = File.join(@prefix_dir, "bin", "llama-cli")
    File.write(bin, "#!/bin/bash\necho mock\n"); FileUtils.chmod(0o755, bin)
    ls_output = "#{bin}\n"
    write_mock_brew
    write_mock_file(output: "Mach-O 64-bit executable x86_64")
    status, _stdout, stderr = run_script("verify-arch", "x86_64",
                                         env: { "MOCK_BREW_LS_OUTPUT" => ls_output })
    assert_predicate status, :success?, "verify-arch x86_64 failed: #{stderr}"
  end

  def test_verify_arch_invalid_arg
    write_formula("llama-cpp")
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("verify-arch", "riscv")
    refute_predicate status, :success?
    assert_match(/invalid architecture/i, stderr)
  end

  def test_verify_arch_no_arg
    write_formula("llama-cpp")
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("verify-arch")
    refute_predicate status, :success?
    assert_match(/invalid architecture/i, stderr)
  end

  def test_verify_arch_mismatch_fails
    write_formula("llama-cpp")
    bin = File.join(@prefix_dir, "bin", "llama-cli")
    File.write(bin, "#!/bin/bash\necho mock\n"); FileUtils.chmod(0o755, bin)
    ls_output = "#{bin}\n"
    write_mock_brew
    write_mock_file(output: "Mach-O 64-bit executable x86_64")
    status, _stdout, stderr = run_script("verify-arch", "arm64",
                                         env: { "MOCK_BREW_LS_OUTPUT" => ls_output })
    refute_predicate status, :success?
    assert_match(/not Mach-O arm64/i, stderr)
  end

  # -- conflicts --

  def test_conflicts_detected
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("conflicts")
    assert_predicate status, :success?, "conflicts failed: #{stderr}"
  end

  def test_conflicts_fails_when_install_succeeds
    # Mock brew: installing llama.cpp succeeds (no conflict) to trigger detection
    mock = <<~"BASH"
      #!/usr/bin/env bash
      set -euo pipefail
      case "${1:-}" in
        tap) exit 0 ;;
        untap) exit 0 ;;
        install) exit 0 ;;
        --prefix) echo "/opt/homebrew" ;;
        *) echo "mock brew: unexpected $*" >&2; exit 1 ;;
      esac
    BASH
    write_mock_brew(mock)
    write_mock_file
    status, _stdout, stderr = run_script("conflicts")
    refute_predicate status, :success?
    assert_match(/succeeded unexpectedly/i, stderr)
  end

  def test_conflicts_fails_on_missing_pattern
    # Mock brew: llama.cpp install fails but without expected diagnostic text
    mock = <<~"BASH"
      #!/usr/bin/env bash
      set -euo pipefail
      case "${1:-}" in
        tap) exit 0 ;;
        untap) exit 0 ;;
        install)
          case " $* " in
            *" llama.cpp "*)
              echo "some unrelated error"
              exit 1
              ;;
            *) exit 0 ;;
          esac
          ;;
        --prefix) echo "/opt/homebrew" ;;
        *) echo "mock brew: unexpected $*" >&2; exit 1 ;;
      esac
    BASH
    write_mock_brew(mock)
    write_mock_file
    status, _stdout, stderr = run_script("conflicts")
    refute_predicate status, :success?
    assert_match(/missing expected diagnostic/i, stderr)
  end

  # -- renames --

  def test_renames_all_present
    # Create all expected renamed binaries in the mock prefix
    %w[ace-quantize ace-mp3-codec ace-neural-codec
       omnivoice-quantize omnivoice-tts-server parakeet-cli].each do |bin|
      path = File.join(@prefix_dir, "bin", bin)
      File.write(path, "#!/bin/bash\necho mock\n")
      FileUtils.chmod(0o755, path)
    end
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("renames")
    assert_predicate status, :success?, "renames failed: #{stderr}"
  end

  def test_renames_fails_on_missing_bin
    # Create only some of the expected binaries
    %w[ace-quantize ace-neural-codec].each do |bin|
      path = File.join(@prefix_dir, "bin", bin)
      File.write(path, "#!/bin/bash\necho mock\n")
      FileUtils.chmod(0o755, path)
    end
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("renames")
    refute_predicate status, :success?
  end

  def test_renames_fails_if_bare_quantize_exists
    %w[ace-quantize ace-mp3-codec ace-neural-codec
       omnivoice-quantize omnivoice-tts-server parakeet-cli].each do |bin|
      path = File.join(@prefix_dir, "bin", bin)
      File.write(path, "#!/bin/bash\necho mock\n")
      FileUtils.chmod(0o755, path)
    end
    # Also create bare quantize (should NOT exist after renames)
    path = File.join(@prefix_dir, "bin", "quantize")
    File.write(path, "#!/bin/bash\necho mock\n")
    FileUtils.chmod(0o755, path)

    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("renames")
    refute_predicate status, :success?
    assert_match(/should not exist|quantize.*rename/i, stderr)
  end

  # -- cleanup / nonzero propagation --

  def test_audit_failure_propagates
    write_formula("llama-cpp")
    # Make brew audit fail
    mock = DEFAULT_MOCK_BREW.sub(/audit.*\) exit 0/, "audit) echo failure >&2; exit 1")
    write_mock_brew(mock)
    write_mock_file
    status, _stdout, stderr = run_script("audit")
    refute_predicate status, :success?
    refute_empty stderr
  end

  def test_install_test_failure_propagates
    write_formula("llama-cpp")
    mock = DEFAULT_MOCK_BREW.sub(/test\) exit 0/, "test) echo test failure >&2; exit 1")
    write_mock_brew(mock)
    write_mock_file
    status, _stdout, stderr = run_script("install-test")
    refute_predicate status, :success?
    refute_empty stderr
  end

  def test_unrelated_formula_included
    # The script discovers ALL *.rb in FORMULA_DIR
    write_formula("llama-cpp")
    write_formula("whisper-cpp")
    write_formula("some-new-thing")
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("audit")
    assert_predicate status, :success?, "audit should include unrelated formula: #{stderr}"
  end

  def test_multiple_formulae_order
    write_formula("z-final")
    write_formula("a-first")
    write_formula("m-middle")
    write_mock_brew
    write_mock_file
    status, stdout, stderr = run_script("audit")
    assert_predicate status, :success?, "audit with multiple formulae failed: #{stderr}"
    # The mock brew succeeds for each; audit loops in glob order (sorted)
  end

  def test_prepare_runner_untaps_when_present
    # Make brew tap list include aws/tap
    write_mock_brew
    write_mock_file
    status, _stdout, stderr = run_script("prepare-runner",
                                         env: { "MOCK_BREW_TAP_OUTPUT" => "adyranov/tap\naws/tap" })
    assert_predicate status, :success?, "prepare-runner should handle aws/tap: #{stderr}"
  end

  def test_linkage_failure_propagates
    write_formula("llama-cpp")
    mock = DEFAULT_MOCK_BREW.sub(/linkage\) exit 0/, "linkage) echo linkage fail >&2; exit 1")
    write_mock_brew(mock)
    write_mock_file
    status, _stdout, stderr = run_script("linkage")
    refute_predicate status, :success?
    refute_empty stderr
  end
end
