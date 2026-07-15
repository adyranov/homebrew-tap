#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../scripts", __dir__)
require "minitest/autorun"
require "json"
require "tmpdir"
require "fileutils"
require_relative "../scripts/bump_ggml_metal_dist_formulae"

# Helpers for generating formula content inline
module FormulaGen
  def valid(name, ver = "v26.6.0", arm_sha: "a" * 64, x64_sha: "b" * 64)
    <<~RUBY
      class #{name.split("-").map(&:capitalize).join} < Formula
        if Hardware::CPU.arm?
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/#{ver}/#{name}-#{ver}-arm64-apple-darwin.tar.gz"
          sha256 "#{arm_sha}"
        else
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/#{ver}/#{name}-#{ver}-x86_64-apple-darwin.tar.gz"
          sha256 "#{x64_sha}"
        end
      end
    RUBY
  end

  def six_formulae(dir, ver = "v26.6.0")
    BumpUtils::MANIFEST.each { |n| File.write(File.join(dir, "#{n}.rb"), valid(n, ver)) }
  end

  def release(ver, extra: nil, missing: [], draft: false, prerelease: false, published: true)
    # 12 tarballs + 12 .sha256 sidecars = 24 assets
    tars = BumpUtils::MANIFEST.product(BumpUtils::ARCHES).map { |f, a| "#{f}-#{ver}-#{a}-apple-darwin.tar.gz" }
    assets = tars.flat_map { |t| [t, "#{t}.sha256"] }
    # Remove matching tarball+sidecar for each missing name
    missing.each { |m| assets = assets.grep_v(Regexp.new(Regexp.escape(m))) }
    assets += extra if extra
    { "tag_name" => ver, "draft" => draft, "prerelease" => prerelease,
      "published_at" => published ? "2025-01-01T00:00:00Z" : nil,
      "assets" => assets.map { |n| { "name" => n, "size" => 100 } } }
  end
end

class TestBumpUtils < Minitest::Test
  include FormulaGen

  # -- Version format --
  def test_accepts_stable_semver
    %w[v1.2.3 v0.0.1 v10.200.3000 v26.7.2].each { |v| BumpUtils.validate_version(v) }
  end

  def test_rejects_invalid_versions
    assert_raises(BumpUtils::ValidationError) { BumpUtils.validate_version("1.2.3") }
    assert_raises(BumpUtils::ValidationError) { BumpUtils.validate_version("v1.2.3-rc1") }
    assert_raises(BumpUtils::ValidationError) { BumpUtils.validate_version("v1.2") }
    assert_raises(BumpUtils::ValidationError) { BumpUtils.validate_version("") }
  end

  # -- Monotonic --
  def test_accepts_newer
    BumpUtils.assert_newer("v26.6.0", "v26.7.0")
    BumpUtils.assert_newer("v26.6.0", "v27.0.0")
  end

  def test_rejects_same_or_older
    assert_raises(BumpUtils::ValidationError) { BumpUtils.assert_newer("v26.7.0", "v26.6.0") }
    assert_raises(BumpUtils::ValidationError) { BumpUtils.assert_newer("v26.6.0", "v26.6.0") }
  end

  # -- Manifest --
  def test_manifest_accepts_six
    Dir.mktmpdir { |d| six_formulae(d); BumpUtils.read_formulae(d) }
  end

  def test_manifest_ignores_extra
    Dir.mktmpdir do |d|
      six_formulae(d)
      File.write(File.join(d, "extra.rb"), "class Extra < Formula; end\n")
      result = BumpUtils.read_formulae(d)
      assert_equal BumpUtils::MANIFEST.size, result.size
      refute_includes result.keys, "extra"
    end
  end

  def test_manifest_rejects_missing
    Dir.mktmpdir do |d|
      six_formulae(d)
      File.unlink(File.join(d, "llama-cpp.rb"))
      assert_raises(BumpUtils::ValidationError) { BumpUtils.read_formulae(d) }
    end
  end

  # -- Ripper declaration parsing (comments, heredocs, %q should be ignored) --
  def test_parses_valid_formula
    r = BumpUtils.parse_formula(valid("llama-cpp"), "llama-cpp")
    assert_equal "v26.6.0", r["arm64"][:version]
    assert_equal 64, r["arm64"][:sha].length
  end

  def test_ignores_noise_in_declarations
    source = <<~RUBY
      class Test < Formula
        # url "https://github.com/adyranov/ggml-metal-dist/releases/download/v99.9.9/test-v99.9.9-arm64-apple-darwin.tar.gz"
        # sha256 "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
        FAKE = %q(url "https://github.com/adyranov/ggml-metal-dist/releases/download/v99.9.9/test-v99.9.9-arm64-apple-darwin.tar.gz")
        EXAMPLE = <<~HEREDOC
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/v99.9.9/test-v99.9.9-arm64-apple-darwin.tar.gz"
          sha256 "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
        HEREDOC
        if Hardware::CPU.arm?
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/test-v26.6.0-arm64-apple-darwin.tar.gz"
          sha256 "#{"a" * 64}"
        else
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/test-v26.6.0-x86_64-apple-darwin.tar.gz"
          sha256 "#{"b" * 64}"
        end
      end
    RUBY
    r = BumpUtils.parse_formula(source, "test")
    assert_equal "v26.6.0", r["arm64"][:version]
    assert_equal "a" * 64, r["arm64"][:sha]
  end

  def test_rejects_url_tag_filename_mismatch
    src = <<~RUBY
      class Bad < Formula
        if Hardware::CPU.arm?
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/bad-v26.6.0-arm64-apple-darwin.tar.gz"
          sha256 "#{"a" * 64}"
        else
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/bad-v26.6.0-x86_64-apple-darwin.tar.gz"
          sha256 "#{"b" * 64}"
        end
      end
    RUBY
    assert_raises(BumpUtils::ValidationError) { BumpUtils.parse_formula(src, "bad") }
  end

  def test_rejects_missing_arch
    src = <<~RUBY
      class Bad < Formula
        if Hardware::CPU.arm?
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/bad-v26.6.0-arm64-apple-darwin.tar.gz"
          sha256 "#{"a" * 64}"
        end
      end
    RUBY
    assert_raises(BumpUtils::ValidationError) { BumpUtils.parse_formula(src, "bad") }
  end

  def test_rejects_duplicate_arch
    src = <<~RUBY
      class Bad < Formula
        if Hardware::CPU.arm?
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/bad-v26.6.0-arm64-apple-darwin.tar.gz"
          sha256 "#{"a" * 64}"
        else
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/bad-v26.6.0-arm64-apple-darwin.tar.gz"
          sha256 "#{"b" * 64}"
        end
      end
    RUBY
    assert_raises(BumpUtils::ValidationError) { BumpUtils.parse_formula(src, "bad") }
  end

  def test_rejects_inconsistent_versions
    src = <<~RUBY
      class Bad < Formula
        if Hardware::CPU.arm?
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/bad-v26.6.0-arm64-apple-darwin.tar.gz"
          sha256 "#{"a" * 64}"
        else
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.7.0/bad-v26.7.0-x86_64-apple-darwin.tar.gz"
          sha256 "#{"b" * 64}"
        end
      end
    RUBY
    assert_raises(BumpUtils::ValidationError) { BumpUtils.parse_formula(src, "bad") }
  end

  # -- Base version consistency --
  def test_base_version_ok
    Dir.mktmpdir do |d|
      six_formulae(d)
      assert_equal "v26.6.0", BumpUtils.base_version(BumpUtils.read_formulae(d))
    end
  end

  def test_base_version_rejects_mixed
    Dir.mktmpdir do |d|
      six_formulae(d)
      File.write(File.join(d, "llama-cpp.rb"), valid("llama-cpp", "v26.7.0"))
      assert_raises(BumpUtils::ValidationError) { BumpUtils.base_version(BumpUtils.read_formulae(d)) }
    end
  end

  # -- Render --
  def test_render_updates_content
    c = valid("llama-cpp")
    r = BumpUtils.render(c, "llama-cpp", "v26.7.0", "c" * 64, "d" * 64)
    assert_includes r, "llama-cpp-v26.7.0-arm64-apple-darwin.tar.gz"
    assert_includes r, "c" * 64
    refute_includes r, "v26.6.0"
  end

  def test_render_idempotent
    c = valid("llama-cpp")
    assert_equal c, BumpUtils.render(c, "llama-cpp", "v26.6.0", "a" * 64, "b" * 64)
  end

  # -- Release validation --
  def test_release_accepts_ok
    validate_release(release("v26.6.1"), "v26.6.1")
  end

  def test_release_rejects_draft
    e = assert_raises(RuntimeError) { validate_release(release("v99.0.0", draft: true), "v99.0.0") }
    assert_match(/Draft/i, e.message)
  end

  def test_release_rejects_prerelease
    e = assert_raises(RuntimeError) { validate_release(release("v26.7.0-rc1", prerelease: true), "v26.7.0-rc1") }
    assert_match(/Prerelease/i, e.message)
  end

  def test_release_rejects_missing_assets
    e = assert_raises(RuntimeError) { validate_release(release("v26.6.1", missing: ["llama-cpp-v26.6.1-arm64-apple-darwin.tar.gz"]), "v26.6.1") }
    assert_match(/Expected|Assets/i, e.message)
  end

  def test_release_rejects_unpublished
    e = assert_raises(RuntimeError) { validate_release(release("v26.8.0", published: false), "v26.8.0") }
    assert_match(/published_at/i, e.message)
  end

  def test_release_rejects_wrong_tag
    e = assert_raises(RuntimeError) { validate_release(release("v26.6.1"), "v27.0.0") }
    assert_match(/Tag/i, e.message)
  end

  def test_release_rejects_duplicate_assets
    r = release("v26.6.1")
    r["assets"] *= 2  # duplicate all
    e = assert_raises(RuntimeError) { validate_release(r, "v26.6.1") }
    assert_match(/Duplicates/i, e.message)
  end

  def test_release_rejects_unexpected_asset
    r = release("v26.6.1")
    r["assets"] << { "name" => "unexpected.txt", "size" => 100 }
    e = assert_raises(RuntimeError) { validate_release(r, "v26.6.1") }
    assert_match(/Unexpected assets/i, e.message)
  end

  # -- Transactional write --
  def test_write_success
    Dir.mktmpdir do |d|
      six_formulae(d)
      modes = BumpUtils::MANIFEST.map { |n| File.stat(File.join(d, "#{n}.rb")).mode }
      rendered = BumpUtils::MANIFEST.to_h { |n| [n, valid(n, "v26.7.0")] }
      BumpUtils.write_all(d, rendered)
      BumpUtils::MANIFEST.each_with_index do |n, i|
        assert_equal rendered[n], File.read(File.join(d, "#{n}.rb"))
        assert_equal modes[i], File.stat(File.join(d, "#{n}.rb")).mode
      end
      assert_empty Dir.glob("#{d}/*.tmp")
    end
  end

  def test_write_partial_failure
    Dir.mktmpdir do |d|
      six_formulae(d)
      orig = BumpUtils::MANIFEST.map { |n| File.read(File.join(d, "#{n}.rb")) }
      rendered = BumpUtils::MANIFEST.to_h { |n| [n, orig[BumpUtils::MANIFEST.index(n)]] }

      ow = File.method(:write)
      File.define_singleton_method(:write) do |path, content|
        raise Errno::ENOSPC, "injected" if path.to_s.end_with?("stable-diffusion-cpp.rb.tmp")
        ow.call(path, content)
      end

      begin
        e = assert_raises(BumpUtils::TransactionError) { BumpUtils.write_all(d, rendered) }
        assert_match(/injected/, e.message)
      ensure
        File.define_singleton_method(:write, ow)
      end
      BumpUtils::MANIFEST.each_with_index { |n, i| assert_equal orig[i], File.read(File.join(d, "#{n}.rb")) }
      assert_empty Dir.glob("#{d}/*.tmp")
    end
  end

  def test_write_rename_rollback
    Dir.mktmpdir do |d|
      six_formulae(d)
      orig = BumpUtils::MANIFEST.map { |n| File.read(File.join(d, "#{n}.rb")) }
      orig_modes = BumpUtils::MANIFEST.map { |n| File.stat(File.join(d, "#{n}.rb")).mode }
      rendered = BumpUtils::MANIFEST.to_h { |n| [n, valid(n, "v26.7.0")] }

      orig_rename = File.singleton_method(:rename)
      File.define_singleton_method(:rename) do |src, dst|
        raise Errno::EACCES, "injected" if dst.to_s.end_with?("acestep-cpp.rb")
        orig_rename.call(src, dst)
      end

      begin
        e = assert_raises(BumpUtils::TransactionError) { BumpUtils.write_all(d, rendered) }
        assert_match(/injected/i, e.message)
      ensure
        File.define_singleton_method(:rename, orig_rename)
      end
      BumpUtils::MANIFEST.each_with_index do |n, i|
        assert_equal orig[i], File.read(File.join(d, "#{n}.rb")), "#{n} content"
        assert_equal orig_modes[i], File.stat(File.join(d, "#{n}.rb")).mode, "#{n} mode"
      end
      assert_empty Dir.glob("#{d}/*.tmp")
    end
  end

  # -- End-to-end git restore + render + write (hostile PR content) --
  def test_git_restore_then_write
    Dir.mktmpdir do |tmpdir|
      repo = File.join(tmpdir, "repo"); Dir.mkdir(repo)
      # Use --template= to suppress macOS template copy errors
      system("git", "-C", repo, "init", "-q", "--template=")
      system("git", "-C", repo, "config", "user.email", "t@t")
      system("git", "-C", repo, "config", "user.name", "t")

      dir = File.join(repo, "Formula"); Dir.mkdir(dir)
      base = valid("llama-cpp")
      File.write(File.join(dir, "llama-cpp.rb"), base)
      other_names = %w[whisper-cpp stable-diffusion-cpp acestep-cpp crispasr omnivoice-cpp]
      other_names.each { |n| File.write(File.join(dir, "#{n}.rb"), valid(n)) }
      system("git", "-C", repo, "add", "-A")
      system("git", "-C", repo, "commit", "-q", "-m", "base")
      base_sha = `git -C #{repo} rev-parse HEAD`.strip

      File.write(File.join(dir, "llama-cpp.rb"), "system(\"rm -rf /\")\n")
      other_names.each { |n| File.write(File.join(dir, "#{n}.rb"), "MALICIOUS\n") }
      system("git", "-C", repo, "add", "-A")
      system("git", "-C", repo, "commit", "-q", "-m", "hostile")

      system("git", "-C", repo, "restore", "--source=#{base_sha}", "--worktree", "--", "Formula/")
      content = File.read(File.join(dir, "llama-cpp.rb"))
      assert_equal base, content
      refute_includes content, "rm -rf"

      # Render + write
      rendered = BumpUtils::MANIFEST.to_h { |n| [n, valid(n, "v26.7.0")] }
      rendered.each { |n, c| BumpUtils.parse_formula(c, n) }
      BumpUtils.write_all(dir, rendered)
      BumpUtils::MANIFEST.each { |n| assert_includes File.read(File.join(dir, "#{n}.rb")), "-v26.7.0-" }
      assert_empty Dir.glob("#{dir}/*.tmp")
    end
  end

  # -- extract_canary_version --
  def test_extract_canary_ok
    decls = BumpUtils.parse_declarations(valid("llama-cpp"), "llama-cpp")
    assert_equal 2, decls.size
  end

  def test_extract_canary_ignores_noise
    src = "FAKE = %q(url \"...\")\n" + valid("llama-cpp")
    decls = BumpUtils.parse_declarations(src, "llama-cpp")
    assert_equal 2, decls.size
    assert_equal "v26.6.0", decls.first[:version]
  end

  # -- Malicious content is data-only --
  def test_malicious_content_is_data
    src = valid("llama-cpp") + "\nsystem(\"rm -rf /\")\n"
    r = BumpUtils.parse_formula(src, "llama-cpp")
    assert_equal "v26.6.0", r["arm64"][:version]
  end

  # -- sha256 multi-chunk checksum via actual BumpNetwork.sha256 --
  def test_sha256_multi_chunk
    big = "A" * (2 * 1024 * 1024 + 13)
    expected = Digest::SHA256.hexdigest(big)

    # Stub URI.open to return a StringIO with multi-chunk content
    original_open = URI.method(:open)
    URI.define_singleton_method(:open) do |_url, _mode, &block|
      block.call(StringIO.new(big))
    end

    begin
      result = BumpNetwork.sha256("https://example.com/fake.tar.gz")
      assert_equal expected, result
    ensure
      URI.define_singleton_method(:open, original_open)
    end
  end

  # -- Rollback diagnostics preserved in TransactionError --
  def test_write_rename_rollback_with_diagnostics
    Dir.mktmpdir do |d|
      six_formulae(d)
      orig = BumpUtils::MANIFEST.map { |n| File.read(File.join(d, "#{n}.rb")) }
      rendered = BumpUtils::MANIFEST.to_h { |n| [n, valid(n, "v26.7.0")] }

      orig_rename = File.singleton_method(:rename)
      orig_chmod   = File.singleton_method(:chmod)
      File.define_singleton_method(:rename) do |src, dst|
        if dst.to_s.end_with?("acestep-cpp.rb")
          # Intercept chmod to fail on first file during rollback
          File.define_singleton_method(:chmod) do |mode, path|
            raise Errno::EACCES, "injected chmod failure" if path.to_s.end_with?("llama-cpp.rb")
            orig_chmod.call(mode, path)
          end
          raise Errno::EACCES, "injected rename failure"
        end
        orig_rename.call(src, dst)
      end

      begin
        e = assert_raises(BumpUtils::TransactionError) { BumpUtils.write_all(d, rendered) }
        assert_match(/injected rename failure/i, e.message)
        assert_match(/rollback.*llama-cpp/i, e.message)
      ensure
        File.define_singleton_method(:rename, orig_rename)
        File.define_singleton_method(:chmod, orig_chmod)
      end
      BumpUtils::MANIFEST.each_with_index do |n, i|
        assert_equal orig[i], File.read(File.join(d, "#{n}.rb")), "#{n} content"
      end
      assert_empty Dir.glob("#{d}/*.tmp")
    end
  end

  # -- Bad URL triggers validation error (safe slicing, not truncate) --
  def test_bad_url_diagnostic
    src = <<~RUBY
      class Bad < Formula
        if Hardware::CPU.arm?
          url "https://github.com/adyranov/ggml-metal-dist/releases/download/v26.6.0/bad-noarch-apple-darwin.tar.gz"
          sha256 "#{"a" * 64}"
        end
      end
    RUBY
    e = assert_raises(BumpUtils::ValidationError) { BumpUtils.parse_declarations(src, "bad") }
    assert_match(/Bad URL/, e.message)
  end

  # -- remove helper --
  def test_remove_file_and_dir
    Dir.mktmpdir do |d|
      f = File.join(d, "x"); File.write(f, ""); assert_nil BumpUtils.remove(f); refute_path_exists(f)
      Dir.mkdir(f); File.write(File.join(f, "y"), ""); assert_nil BumpUtils.remove(f); refute_path_exists(f)
    end
  end

  # -- extract-version CLI subprocess --
  SCRIPT = File.expand_path("../scripts/bump_ggml_metal_dist_formulae.rb", __dir__).freeze

  def test_extract_version_cli_ok
    Dir.mktmpdir do |d|
      path = File.join(d, "llama-cpp.rb")
      File.write(path, valid("llama-cpp"))
      out = `ruby #{SCRIPT} --extract-version #{path} 2>&1`
      assert_predicate $?, :success?
      assert_equal "v26.6.0\n", out
    end
  end

  def test_extract_version_cli_bad_formula
    Dir.mktmpdir do |d|
      path = File.join(d, "bad.rb")
      File.write(path, "class Bad < Formula; end\n")
      out = `ruby #{SCRIPT} --extract-version #{path} 2>&1`
      refute_predicate $?, :success?
      refute_empty out
    end
  end

  def test_extract_version_cli_from_stdin
    out = IO.popen(%W[ruby #{SCRIPT} --extract-version], "r+", err: [:child, :out]) do |io|
      io.write(valid("llama-cpp"))
      io.close_write
      io.read
    end
    assert_predicate $?, :success?
    assert_equal "v26.6.0\n", out.lines.first
  end

  # -- --list-formulae --
  def test_list_formulae_output
    out = `ruby #{SCRIPT} --list-formulae 2>&1`
    assert_predicate $?, :success?
    lines = out.split("\n").map(&:strip).reject(&:empty?)
    assert_equal BumpUtils::MANIFEST.size, lines.size
    assert_equal BumpUtils::MANIFEST.sort, lines.sort
  end

  def test_list_formulae_unique
    out = `ruby #{SCRIPT} --list-formulae 2>&1`
    lines = out.split("\n").map(&:strip).reject(&:empty?)
    assert_equal lines.uniq.size, lines.size
  end

  def test_list_formulae_matches_manifest_constant
    out = `ruby #{SCRIPT} --list-formulae 2>&1`
    lines = out.split("\n").map(&:strip).reject(&:empty?).sort
    assert_equal BumpUtils::MANIFEST.sort, lines
  end

  def test_extract_version_cli_stdin_bad
    out = IO.popen(%W[ruby #{SCRIPT} --extract-version], "r+", err: [:child, :out]) do |io|
      io.write("class Bad < Formula; end\n")
      io.close_write
      io.read
    end
    refute_predicate $?, :success?
    refute_empty out
  end
end
