#!/usr/bin/env ruby
# frozen_string_literal: true

# Update all ggml-metal-dist formulae to a new release tag.
# Used by Renovate postUpgradeTasks; can also be run manually:
#   ruby scripts/bump_ggml_metal_dist_formulae.rb v26.6.2
require "json"
require "net/http"
require "uri"

REPO = "adyranov/ggml-metal-dist"
FORMULA_DIR = File.expand_path("../Formula", __dir__)
ARCHES = %w[arm64 x86_64].freeze

def release_assets(version)
  uri = URI("https://api.github.com/repos/#{REPO}/releases/tags/#{version}")
  request = Net::HTTP::Get.new(uri)
  request["User-Agent"] = "homebrew-tap-bump"
  request["Accept"] = "application/vnd.github+json"

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end
  raise "Release #{version} not found (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body).fetch("assets")
end

def digest_for(assets, filename)
  asset = assets.find { |entry| entry["name"] == filename }
  raise "Release asset not found: #{filename}" unless asset

  digest = asset["digest"] || asset["checksum"]
  raise "Release asset missing digest: #{filename}" if digest.nil? || digest.empty?

  digest.delete_prefix("sha256:")
end

def bump_formula(path, version, assets)
  formula = File.basename(path, ".rb")
  content = File.read(path)
  return unless content.include?("github.com/#{REPO}/releases/download/")

  ARCHES.each do |arch|
    filename = "#{formula}-#{version}-#{arch}-apple-darwin.tar.gz"
    url = "https://github.com/#{REPO}/releases/download/#{version}/#{filename}"
    sha256 = digest_for(assets, filename)

    # Replace the url and its following sha256 atomically, preserving the
    # original indentation (captured in \1) so the script is layout-agnostic.
    replaced = content.sub!(
      %r{url "https://github\.com/#{Regexp.escape(REPO)}/releases/download/[^"]+/#{Regexp.escape(formula)}-[^"]+-#{arch}-apple-darwin\.tar\.gz"\n(\s*)sha256 "[0-9a-f]{64}"},
      %(url "#{url}"\n\\1sha256 "#{sha256}"),
    )
    raise "No #{arch} url/sha256 block found in #{path}" if replaced.nil?
  end

  File.write(path, content)
end

version = ARGV.fetch(0)
raise "Version must look like v1.2.3 (got #{version})" unless version.match?(/\Av[0-9.]+(?:-[0-9A-Za-z.]+)?\z/)

assets = release_assets(version)
Dir.glob("#{FORMULA_DIR}/*.rb").sort.each { |path| bump_formula(path, version, assets) }
