#!/usr/bin/env ruby
# frozen_string_literal: true

# Update all ggml-metal-dist formulae to a new release tag.
# Called by .github/workflows/renovate-bump.yml; can also be run manually:
#   ruby scripts/bump_ggml_metal_dist_formulae.rb v26.6.2
#
# Security:
# - Works on files restored from trusted BASE_SHA (never PR-provided content).
# - Requires strictly newer vMAJOR.MINOR.PATCH format.
# - Validates release: non-draft, non-prerelease, tag_name match,
#   non-null published_at, exactly 12 tarballs plus 12 matching .sha256
#   sidecars (24 total), rejecting any unexpected asset.
# - URL/SHA extraction uses Ripper (stdlib AST) — no regex false positives.
# - Transactional write with mode preservation, rollback, and error reporting.
require "digest"
require "json"
require "net/http"
require "open-uri"
require "fileutils"
require "ripper"
require "uri"

REPO = "adyranov/ggml-metal-dist"
MANIFEST = %w[llama-cpp whisper-cpp stable-diffusion-cpp acestep-cpp crispasr omnivoice-cpp].freeze
ARCHES = %w[arm64 x86_64].freeze
VERSION_RE = /\Av(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/

# ---------------------------------------------------------------------------
# Ripper AST helpers
# ---------------------------------------------------------------------------

# Walk S-expression depth-first, collecting [:command, ...] nodes whose
# identifier is in +names+.  Returns [[name, string_arg], ...].
def walk_commands(sexp, names, result = [])
  return result unless sexp.is_a?(Array)
  if sexp[0] == :command && (id = sexp.dig(1, 1))
    result << [id.to_s, extract_str(sexp)] if names.include?(id.to_s)
  end
  sexp.each { |c| walk_commands(c, names, result) }
  result
end

# Extract static string from [:command, ..., [:args_add_block,
# [[:string_literal, [:string_content, [:@tstring_content, val]]]], false]]
def extract_str(node)
  (node.dig(2, 1, 0, 1, 1, 1) rescue nil).to_s
end

# ---------------------------------------------------------------------------
# Pure validations
# ---------------------------------------------------------------------------

module BumpUtils
  MANIFEST = ::MANIFEST
  ARCHES = ::ARCHES
  ValidationError = Class.new(RuntimeError)
  TransactionError = Class.new(RuntimeError)

  def self.validate_version(ver)
    raise ValidationError, "Bad version #{ver.inspect}" unless ver.is_a?(String) && ver.match?(VERSION_RE)
  end

  def self.parse_semver(ver) = ver.sub(/\Av/, "").split(".").map(&:to_i)

  def self.assert_newer(old_ver, new_ver)
    o = parse_semver(old_ver)
    n = parse_semver(new_ver)
    n.zip(o).each do |ni, oi|
      return if ni > oi
      raise ValidationError, "#{new_ver} not strictly newer than #{old_ver}" if ni < oi
    end
    raise ValidationError, "#{new_ver} not strictly newer than #{old_ver}"
  end

  # Parse all url/sha256 declarations from a formula source using Ripper.
  # Returns [{ version:, sha:, arch: }, ...] for declarations matching our
  # repo.  Raises on syntax error, non-static args, path/filename mismatch,
  # or invalid sha.  Ignores comments, heredocs, %q{}, etc.
  def self.parse_declarations(source, formula)
    sexp = Ripper.sexp(source)
    raise ValidationError, "Cannot parse #{formula}.rb" unless sexp

    calls = walk_commands(sexp, %w[url sha256])
    pairs = []
    i = 0
    while i < calls.size
      if calls[i][0] == "url" && i + 1 < calls.size && calls[i + 1][0] == "sha256"
        pairs << [calls[i][1], calls[i + 1][1]]
        i += 2
      else; i += 1 end
    end

    our = pairs.select { |u, _| u.include?("/#{REPO}/releases/download/") && u.include?("/#{formula}-") }

    result = []
    our.each do |url_str, sha_str|
      m = url_str.match(%r{/releases/download/(v\d+\.\d+\.\d+)/#{formula}-(v\d+\.\d+\.\d+)-(arm64|x86_64)-apple-darwin\.tar\.gz})
      raise ValidationError, "Bad URL #{url_str[0, 60]} in #{formula}.rb" unless m
      raise ValidationError, "Path/filename version mismatch in #{formula}.rb (#{m[3]})" unless m[1] == m[2]
      raise ValidationError, "Bad sha in #{formula}.rb (#{m[3]})" unless sha_str.match?(/\A[0-9a-f]{64}\z/)
      result << { version: m[1], sha: sha_str, arch: m[3] }
    end
    result
  end

  # Parse a formula and return { arch => { version:, sha: } }, ensuring
  # exactly one arm64 and one x86_64 declaration.
  def self.parse_formula(source, formula)
    decls = parse_declarations(source, formula)
    arm = decls.find { |d| d[:arch] == "arm64" }
    x64 = decls.find { |d| d[:arch] == "x86_64" }
    raise ValidationError, "Missing arm64 decl in #{formula}.rb" unless arm
    raise ValidationError, "Missing x86_64 decl in #{formula}.rb" unless x64
    raise ValidationError, "Duplicate arm64 in #{formula}.rb" if decls.count { |d| d[:arch] == "arm64" } > 1
    raise ValidationError, "Duplicate x86_64 in #{formula}.rb" if decls.count { |d| d[:arch] == "x86_64" } > 1
    raise ValidationError, "Version mismatch in #{formula}.rb" unless arm[:version] == x64[:version]
    validate_version(arm[:version])
    { "arm64" => { version: arm[:version], sha: arm[:sha] },
      "x86_64" => { version: x64[:version], sha: x64[:sha] } }
  end

  # Read formula dir, validate manifest, return { name => content }.
  def self.read_formulae(dir)
    paths = Dir.glob("#{dir}/*.rb").sort
    names = paths.map { |p| File.basename(p, ".rb") }
    missing = MANIFEST - names
    raise ValidationError, "Missing formulae: #{missing.join(', ')}" unless missing.empty?
    MANIFEST.to_h { |name| [name, File.read(File.join(dir, "#{name}.rb"))] }
  end

  # Validate all 6 base formulae share the same version.
  def self.base_version(formulae)
    vers = formulae.map { |n, c| parse_formula(c, n)["arm64"][:version] }.uniq
    raise ValidationError, "Inconsistent base versions: #{vers.join(', ')}" unless vers.size == 1
    vers.first
  end

  # Render updated formula (string substitution preserving indentation).
  def self.render(content, formula, version, arm_sha, x64_sha)
    r = content.dup
    { "arm64" => arm_sha, "x86_64" => x64_sha }.each do |arch, sha|
      pat = /^(\s*)url\s+"https:\/\/github\.com\/#{Regexp.escape(REPO)}\/releases\/download\/[^"]+\/#{Regexp.escape(formula)}-[^"]+-#{arch}-apple-darwin\.tar\.gz"\n(\s*)sha256\s+"[0-9a-f]{64}"/
      url = "https://github.com/#{REPO}/releases/download/#{version}/#{formula}-#{version}-#{arch}-apple-darwin.tar.gz"
      raise ValidationError, "BUG: no #{arch} block in #{formula}.rb" unless r.match?(pat)
      r = r.sub(pat, "\\1url \"#{url}\"\n\\2sha256 \"#{sha}\"")
    end
    r
  end

  # Safe removal helper — returns error message string or nil.
  def self.remove(path)
    return nil unless File.exist?(path)
    FileUtils.rm_rf(path)
    File.exist?(path) ? "#{path} still present" : nil
  rescue => e; "#{path}: #{e.message}"
  end

  # Transactional write: stage all temps, then rename atomically.
  # On rename failure, restores already-replaced files' bytes and modes,
  # collects ALL rollback errors, and raises TransactionError preserving
  # the original rename error plus rollback diagnostics.
  def self.write_all(dir, rendered)
    entries = {}
    rendered.each_key do |name|
      real = File.join(dir, "#{name}.rb")
      st = File.stat(real)
      entries[name] = { real: real, tmp: "#{real}.tmp", orig: File.read(real), mode: st.mode }
    end

    # Stage 1: write all temps
    written = []
    begin
      rendered.each do |name, content|
        File.write(entries[name][:tmp], content)
        File.chmod(entries[name][:mode], entries[name][:tmp])
        written << name
      end
    rescue => e
      errs = (written + [rendered.keys[written.size]].compact).uniq.filter_map { |n| remove(entries[n][:tmp]) }
      msg = "Write failed after #{written.size}/#{rendered.size}: #{e.message}"
      msg += " (cleanup: #{errs.join('; ')})" unless errs.empty?
      raise TransactionError, msg
    end

    # Stage 2: atomic rename with full rollback
    renamed = []
    begin
      entries.each { |_name, e| File.rename(e[:tmp], e[:real]); renamed << _name }
    rescue => e
      errs = []
      renamed.each do |n|
        e2 = entries[n]
        begin
          File.write(e2[:real], e2[:orig])
          File.chmod(e2[:mode], e2[:real])
        rescue => rbe
          errs << "rollback(#{n}): #{rbe.message}"
        end
      end
      entries.each_value { |e2| (r = remove(e2[:tmp]); errs << r if r) }
      msg = "Write failed after #{renamed.size}/#{entries.size}: #{e.message}"
      msg += " (#{errs.join('; ')})" unless errs.empty?
      raise TransactionError, msg
    end

    entries.each_value { |e| raise "#{e[:tmp]} still exists" if File.exist?(e[:tmp]) }
  end
end

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

module BumpNetwork
  NetworkError = Class.new(RuntimeError)

  def self.fetch_release(version, token: ENV["GITHUB_TOKEN"])
    uri = URI("https://api.github.com/repos/#{REPO}/releases/tags/#{version}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true; http.open_timeout = 10; http.read_timeout = 30
    req = Net::HTTP::Get.new(uri)
    req["Accept"] = "application/vnd.github.v3+json"
    req["Authorization"] = "Bearer #{token}" if token && !token.empty?
    case r = http.request(req)
    when Net::HTTPOK then JSON.parse(r.body)
    when Net::HTTPNotFound then raise NetworkError, "Release #{version} not found"
    when Net::HTTPForbidden, Net::HTTPUnauthorized then raise NetworkError, "API rate/unauth for #{version}"
    else raise NetworkError, "API #{r.code} for #{version}: #{r.message}"
    end
  end

  def self.sha256(url)
    d = Digest::SHA256.new
    URI.open(url, "rb") do |f|
      while (chunk = f.read(1024 * 1024))
        d.update(chunk)
      end
    end
    d.hexdigest
  rescue OpenURI::HTTPError => e; raise NetworkError, "Download failed: #{e.message}"
  end
end

# ---------------------------------------------------------------------------
# Release validation
# ---------------------------------------------------------------------------

def validate_release(release, version)
  errs = []
  errs << "Tag #{release['tag_name']} != #{version}" unless release["tag_name"] == version
  errs << "Draft" if release["draft"]
  errs << "Prerelease" if release["prerelease"]
  errs << "No published_at" if release["published_at"].to_s.empty?

  names = (release["assets"] || []).map { |a| a["name"] }
  dupes = names.tally.select { |_, c| c > 1 }
  errs << "Duplicates: #{dupes.keys.join(', ')}" unless dupes.empty?

  tarballs = names.select { |n| n.end_with?(".tar.gz") && !n.end_with?(".sha256") }.sort
  sidecars = names.select { |n| n.end_with?(".sha256") }.sort

  expected_tars = MANIFEST.product(ARCHES).map { |f, a| "#{f}-#{version}-#{a}-apple-darwin.tar.gz" }.sort
  expected_sides = expected_tars.map { |t| "#{t}.sha256" }.sort

  errs << "Expected #{expected_tars.size} tarballs, got #{tarballs.size}" unless tarballs.size == expected_tars.size
  errs << "Expected #{expected_sides.size} .sha256 sidecars, got #{sidecars.size}" unless sidecars.size == expected_sides.size
  errs << "Unexpected tarballs" unless tarballs == expected_tars
  errs << "Unexpected sidecars" unless sidecars == expected_sides

  # Comprehensive: every asset must be a known tarball or its sidecar.
  all_expected = (expected_tars + expected_sides).sort
  errs << "Unexpected assets in release" unless names.sort == all_expected

  raise errs.join("\n") unless errs.empty?
end

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

if __FILE__ == $PROGRAM_NAME
  if ARGV[0] == "--list-formulae"
    MANIFEST.each { |name| puts name }
    exit 0
  end

  if ARGV[0] == "--extract-version"
    src = (ARGV[1] && File.exist?(ARGV[1]) ? File.read(ARGV[1]) : STDIN.read)
    decls = BumpUtils.parse_declarations(src, "llama-cpp")
    arm = decls.find { |d| d[:arch] == "arm64" }
    x64 = decls.find { |d| d[:arch] == "x86_64" }
    raise "Missing arm64 canary URL" unless arm
    raise "Missing x86_64 canary URL" unless x64
    raise "arm64 != x86_64 version" unless arm[:version] == x64[:version]
    puts arm[:version]
    exit 0
  end

  version = ARGV.fetch(0) { abort "usage: #{$PROGRAM_NAME} vMAJOR.MINOR.PATCH" }
  BumpUtils.validate_version(version)

  dir = ENV.fetch("FORMULA_DIR", File.expand_path("../Formula", __dir__))
  raise "Not a dir: #{dir}" unless File.directory?(dir)

  formulae = BumpUtils.read_formulae(dir)
  base = BumpUtils.base_version(formulae)
  BumpUtils.assert_newer(base, version)

  release = BumpNetwork.fetch_release(version)
  validate_release(release, version)

  shas = {}
  MANIFEST.each do |name|
    ARCHES.each { |arch| shas[[name, arch]] = BumpNetwork.sha256("https://github.com/#{REPO}/releases/download/#{version}/#{name}-#{version}-#{arch}-apple-darwin.tar.gz") }
  end

  rendered = {}
  formulae.each { |name, content| rendered[name] = BumpUtils.render(content, name, version, shas[[name, "arm64"]], shas[[name, "x86_64"]]) }
  rendered.each { |name, content| BumpUtils.parse_formula(content, name) }

  BumpUtils.write_all(dir, rendered)
end
